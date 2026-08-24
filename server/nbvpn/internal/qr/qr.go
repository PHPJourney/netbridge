package qr

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"

	qrcode "github.com/skip2/go-qrcode"
	"golang.org/x/term"
)

// Terminal half-block QR: size to the current console (COLUMNS / term.GetSize),
// so SSH and narrow Windows terminals can show a scannable code without wrapping.
// PNG remains an optional on-disk copy (High recovery, ~320px) — not a substitute
// for printing the terminal QR on stdout.
const (
	terminalRecoveryPreferred = qrcode.Medium
	terminalRecoveryCompact   = qrcode.Low
	pngRecovery               = qrcode.High
	pngSizePx                 = 320 // absolute PNG side (quiet zone included)
	// DefaultMaxTerminalCols when COLUMNS / TTY size cannot be detected.
	// Typical nbvpn: URI matrices are ~73–89 modules after compact ECC.
	DefaultMaxTerminalCols = 120
	// Absolute bounds for --qr-size / DetectedCols.
	MinTerminalCols    = 21 // QR version-1 side
	MaxTerminalColsCap = 256
)

// MaxTerminalCols is the historical default clamp name; Prefer EffectiveMaxCols(0).
const MaxTerminalCols = DefaultMaxTerminalCols

// ANSI: force light background + dark modules so dark terminal themes do not invert the code.
const (
	ansiQR  = "\033[48;5;231m\033[38;5;16m" // white bg, near-black fg
	ansiOff = "\033[0m"
)

// FallbackHint tells operators what to use when the terminal QR may wrap or is too dense.
const FallbackHint = "If the terminal QR wraps or will not scan: widen the terminal, set COLUMNS / --qr-size, or use the optional PNG / --uri / --file. Peer numeric id / PNG filename is NOT the QR payload — payload is always the full nbvpn:1?… URI."

// ColorEnabled reports whether ANSI color escapes should be emitted.
// Disabled on Windows unless FORCE_COLOR=1 or NBVPN_FORCE_ANSI=1; always off if NO_COLOR is set.
func ColorEnabled() bool {
	if os.Getenv("NO_COLOR") != "" {
		return false
	}
	if os.Getenv("FORCE_COLOR") != "" || os.Getenv("NBVPN_FORCE_ANSI") == "1" {
		return true
	}
	if runtime.GOOS == "windows" {
		// Classic PowerShell / conhost on Server 2012 do not render VT sequences.
		return false
	}
	return true
}

// RenderOptions controls terminal QR rendering.
type RenderOptions struct {
	UseANSI bool
	MaxCols int // 0 = EffectiveMaxCols(0)
}

// DetectTerminalCols returns the current terminal width, or 0 if unknown.
// Order: COLUMNS env, then term.GetSize(stdout), then stderr.
func DetectTerminalCols() int {
	if c := strings.TrimSpace(os.Getenv("COLUMNS")); c != "" {
		if n, err := strconv.Atoi(c); err == nil && n > 0 {
			return n
		}
	}
	for _, f := range []*os.File{os.Stdout, os.Stderr} {
		if f == nil {
			continue
		}
		w, _, err := term.GetSize(int(f.Fd()))
		if err == nil && w > 0 {
			return w
		}
	}
	return 0
}

// ClampMaxCols normalizes an explicit --qr-size into a sane band.
func ClampMaxCols(n int) int {
	if n <= 0 {
		return EffectiveMaxCols(0)
	}
	if n < MinTerminalCols {
		return MinTerminalCols
	}
	if n > MaxTerminalColsCap {
		return MaxTerminalColsCap
	}
	return n
}

// EffectiveMaxCols picks the module-width budget for terminal rendering.
// override > 0 wins (already clamped by callers via ClampMaxCols when from flags).
// Otherwise: detected terminal width (minus 1 col margin), else DefaultMaxTerminalCols.
func EffectiveMaxCols(override int) int {
	if override > 0 {
		return ClampMaxCols(override)
	}
	if d := DetectTerminalCols(); d > 0 {
		max := d - 1
		if max < MinTerminalCols {
			max = d
		}
		return ClampMaxCols(max)
	}
	return DefaultMaxTerminalCols
}

// RenderTerminal returns a half-block Unicode QR for content (full URI),
// sized to the current terminal (or DefaultMaxTerminalCols).
func RenderTerminal(content string) (string, error) {
	return RenderTerminalOpts(content, RenderOptions{UseANSI: ColorEnabled(), MaxCols: EffectiveMaxCols(0)})
}

// RenderTerminalOpts encodes content with explicit options.
// Returns TooWideError when the bitmap cannot fit MaxCols even after compact recovery
// (caller should still print optional PNG path / --uri).
func RenderTerminalOpts(content string, opts RenderOptions) (string, error) {
	maxCols := opts.MaxCols
	if maxCols <= 0 {
		maxCols = EffectiveMaxCols(0)
	}

	attempts := []struct {
		level  qrcode.RecoveryLevel
		border bool
	}{
		{terminalRecoveryPreferred, false}, // quiet zone
		{terminalRecoveryPreferred, true},  // drop encoder quiet zone
		{terminalRecoveryCompact, false},
		{terminalRecoveryCompact, true},
	}

	var lastCols int
	for _, a := range attempts {
		q, err := qrcode.New(content, a.level)
		if err != nil {
			return "", fmt.Errorf("QR encode failed: %w", err)
		}
		q.DisableBorder = a.border
		bitmap := q.Bitmap()
		if len(bitmap) == 0 {
			continue
		}
		lastCols = len(bitmap[0])
		if lastCols <= maxCols {
			return renderHalfBlocks(bitmap, opts.UseANSI), nil
		}
	}
	return "", &TooWideError{Cols: lastCols, Max: maxCols}
}

// TooWideError means the terminal QR would wrap on a narrow console.
type TooWideError struct {
	Cols int
	Max  int
}

func (e *TooWideError) Error() string {
	return fmt.Sprintf("terminal QR too wide (%d cols > max %d); widen terminal, pass --qr-size, or use optional PNG / --uri", e.Cols, e.Max)
}

// IsTooWide reports whether err is a TooWideError.
func IsTooWide(err error) bool {
	_, ok := err.(*TooWideError)
	return ok
}

// WritePNG writes a black-on-white PNG of the full URI (mode 0600; contains secrets).
// Side length is pngSizePx (~320); Desktop copies use the same file bytes.
func WritePNG(content, path string) error {
	png, err := qrcode.Encode(content, pngRecovery, pngSizePx)
	if err != nil {
		return fmt.Errorf("QR PNG encode failed: %w", err)
	}
	if err := os.WriteFile(path, png, 0o600); err != nil {
		return fmt.Errorf("QR PNG write failed: %w", err)
	}
	return nil
}

// ModuleSize returns the terminal bitmap side length (including quiet zone) for tests.
func ModuleSize(content string) (int, error) {
	q, err := qrcode.New(content, terminalRecoveryPreferred)
	if err != nil {
		return 0, err
	}
	q.DisableBorder = false
	b := q.Bitmap()
	if len(b) == 0 {
		return 0, fmt.Errorf("empty QR bitmap")
	}
	return len(b), nil
}

func renderHalfBlocks(bitmap [][]bool, useANSI bool) string {
	h := len(bitmap)
	if h == 0 {
		return ""
	}
	w := len(bitmap[0])
	var b strings.Builder

	// One extra quiet-zone row (white) above/below the encoder border.
	writePadRow(&b, w, useANSI)

	for y := 0; y < h; y += 2 {
		if useANSI {
			b.WriteString(ansiQR)
		}
		for x := 0; x < w; x++ {
			top := bitmap[y][x]
			bottom := false
			if y+1 < h {
				bottom = bitmap[y+1][x]
			}
			// true = dark module; filled block against forced light bg.
			switch {
			case top && bottom:
				b.WriteRune('█')
			case top && !bottom:
				b.WriteRune('▀')
			case !top && bottom:
				b.WriteRune('▄')
			default:
				b.WriteByte(' ')
			}
		}
		if useANSI {
			b.WriteString(ansiOff)
		}
		b.WriteByte('\n')
	}

	writePadRow(&b, w, useANSI)
	return b.String()
}

func writePadRow(b *strings.Builder, w int, useANSI bool) {
	if useANSI {
		b.WriteString(ansiQR)
	}
	b.WriteString(strings.Repeat(" ", w))
	if useANSI {
		b.WriteString(ansiOff)
	}
	b.WriteByte('\n')
}
