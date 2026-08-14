package qr

import (
	"fmt"
	"os"
	"runtime"
	"strings"

	qrcode "github.com/skip2/go-qrcode"
)

// Terminal uses Medium so the matrix stays narrower on 80-col SSH sessions.
// PNG uses High (Q, contract §4) for more robust camera scans of the image file.
const (
	terminalRecovery = qrcode.Medium
	pngRecovery      = qrcode.High
	pngModulePx      = -10 // pixels per module (skip2 negative size)
	// MaxTerminalCols: skip printing a terminal QR wider than this (narrow consoles / PS4).
	MaxTerminalCols = 40
)

// ANSI: force light background + dark modules so dark terminal themes do not invert the code.
const (
	ansiQR  = "\033[48;5;231m\033[38;5;16m" // white bg, near-black fg
	ansiOff = "\033[0m"
)

// FallbackHint tells operators what to use when the terminal QR may wrap or fail to scan.
const FallbackHint = "If the terminal QR does not scan (wrap/font/theme): use --file, --uri, or open the PNG beside the peer profile. Note: peer numeric id / PNG filename is NOT the QR payload — payload is always the full nbvpn:1?… URI."

// WindowsDefaultHint is printed when terminal QR is skipped on Windows (default).
const WindowsDefaultHint = "Windows: terminal QR skipped (old PowerShell may wrap / show raw ANSI). Open the QR PNG above, or paste the URI. Opt-in: nbvpn show --qr"

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
	MaxCols int // 0 = MaxTerminalCols
}

// RenderTerminal returns a half-block Unicode QR for content (full URI).
// Two QR rows pack into one terminal row (▀▄█) so modules stay roughly square on ~2:1 cells.
// Colors are forced to dark-on-light when UseANSI; encoder quiet zone is kept (DisableBorder=false).
func RenderTerminal(content string) (string, error) {
	return RenderTerminalOpts(content, RenderOptions{UseANSI: ColorEnabled(), MaxCols: MaxTerminalCols})
}

// RenderTerminalOpts encodes content with explicit options.
// Returns ErrTooWide when the bitmap exceeds MaxCols (caller should point users at PNG/URI).
func RenderTerminalOpts(content string, opts RenderOptions) (string, error) {
	q, err := qrcode.New(content, terminalRecovery)
	if err != nil {
		return "", fmt.Errorf("QR encode failed: %w", err)
	}
	q.DisableBorder = false
	bitmap := q.Bitmap()
	maxCols := opts.MaxCols
	if maxCols <= 0 {
		maxCols = MaxTerminalCols
	}
	if len(bitmap) > 0 && len(bitmap[0]) > maxCols {
		return "", &TooWideError{Cols: len(bitmap[0]), Max: maxCols}
	}
	return renderHalfBlocks(bitmap, opts.UseANSI), nil
}

// TooWideError means the terminal QR would wrap on a narrow console.
type TooWideError struct {
	Cols int
	Max  int
}

func (e *TooWideError) Error() string {
	return fmt.Sprintf("terminal QR too wide (%d cols > max %d); open the PNG or use --uri", e.Cols, e.Max)
}

// IsTooWide reports whether err is a TooWideError.
func IsTooWide(err error) bool {
	_, ok := err.(*TooWideError)
	return ok
}

// WritePNG writes a black-on-white PNG of the full URI (mode 0600; contains secrets).
func WritePNG(content, path string) error {
	png, err := qrcode.Encode(content, pngRecovery, pngModulePx)
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
	q, err := qrcode.New(content, terminalRecovery)
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
