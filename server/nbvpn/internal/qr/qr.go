package qr

import (
	"fmt"
	"os"
	"strings"

	qrcode "github.com/skip2/go-qrcode"
)

// Terminal uses Medium so the matrix stays narrower on 80-col SSH sessions.
// PNG uses High (Q, contract §4) for more robust camera scans of the image file.
const (
	terminalRecovery = qrcode.Medium
	pngRecovery      = qrcode.High
	pngModulePx      = -10 // pixels per module (skip2 negative size)
)

// ANSI: force light background + dark modules so dark terminal themes do not invert the code.
const (
	ansiQR  = "\033[48;5;231m\033[38;5;16m" // white bg, near-black fg
	ansiOff = "\033[0m"
)

// FallbackHint tells operators what to use when the terminal QR may wrap or fail to scan.
const FallbackHint = "If the terminal QR does not scan (wrap/font/theme): use --file, --uri, or open the PNG beside the peer profile. Note: peer numeric id / PNG filename is NOT the QR payload — payload is always the full nbvpn:1?… URI."

// RenderTerminal returns a half-block Unicode QR for content (full URI).
// Two QR rows pack into one terminal row (▀▄█) so modules stay roughly square on ~2:1 cells.
// Colors are forced to dark-on-light; encoder quiet zone is kept (DisableBorder=false).
func RenderTerminal(content string) (string, error) {
	q, err := qrcode.New(content, terminalRecovery)
	if err != nil {
		return "", fmt.Errorf("QR encode failed: %w", err)
	}
	q.DisableBorder = false
	return renderHalfBlocks(q.Bitmap()), nil
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

func renderHalfBlocks(bitmap [][]bool) string {
	h := len(bitmap)
	if h == 0 {
		return ""
	}
	w := len(bitmap[0])
	var b strings.Builder

	// One extra quiet-zone row (white) above/below the encoder border.
	writePadRow(&b, w)

	for y := 0; y < h; y += 2 {
		b.WriteString(ansiQR)
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
		b.WriteString(ansiOff)
		b.WriteByte('\n')
	}

	writePadRow(&b, w)
	return b.String()
}

func writePadRow(b *strings.Builder, w int) {
	b.WriteString(ansiQR)
	b.WriteString(strings.Repeat(" ", w))
	b.WriteString(ansiOff)
	b.WriteByte('\n')
}
