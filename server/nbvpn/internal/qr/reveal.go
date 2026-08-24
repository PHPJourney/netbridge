package qr

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// AfterWriteResult describes optional visible copies and operator hints after writing a QR PNG.
type AfterWriteResult struct {
	VisibleCopies []string // non-hidden copies (e.g. Desktop), may be empty
	SelectCmd     string   // Windows: explorer /select,"path"
	Notes         []string // human-readable tips (zh + en)
	Opened        bool     // true if we attempted to open/reveal the file
	OpenErr       error
}

// AfterWrite copies the PNG to a few visible locations (Windows) and returns soft notes.
// It does not open an image viewer — terminal half-block QR is the primary CLI display;
// PNG is an optional on-disk supplement for camera scan / attachments.
func AfterWrite(canonicalPath string) AfterWriteResult {
	var r AfterWriteResult
	if strings.TrimSpace(canonicalPath) == "" {
		return r
	}
	abs, err := filepath.Abs(canonicalPath)
	if err == nil {
		canonicalPath = abs
	}
	r = afterWritePlatform(canonicalPath)
	return r
}

// PrintAfterWrite writes a short supplemental note after a successful PNG write.
// Prefer printing the terminal QR first; call this only as an extra tip.
func PrintAfterWrite(w io.Writer, canonicalPath string, r AfterWriteResult) {
	if w == nil {
		w = os.Stdout
	}
	fmt.Fprintf(w, "Optional QR PNG (supplement; scan terminal QR above when possible): %s\n", canonicalPath)
	for _, c := range r.VisibleCopies {
		fmt.Fprintf(w, "  also: %s\n", c)
	}
	if r.SelectCmd != "" {
		fmt.Fprintf(w, "  reveal: %s\n", r.SelectCmd)
	}
	for _, n := range r.Notes {
		fmt.Fprintln(w, n)
	}
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	defer out.Close()
	if _, err := io.Copy(out, in); err != nil {
		return err
	}
	return out.Close()
}

func peerPNGBasename(canonicalPath string) string {
	base := filepath.Base(canonicalPath)
	if base == "" || base == "." {
		return "nbvpn-peer-qr.png"
	}
	return base
}
