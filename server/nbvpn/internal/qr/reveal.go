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

// AfterWrite copies the PNG to a few visible locations (Windows), prints operator hints,
// and on Windows tries explorer /select (or the default image viewer).
// Linux/macOS: no GUI pop-ups; only returns soft notes.
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

// PrintAfterWrite writes a conspicuous block to w (usually stdout) after a successful PNG write.
func PrintAfterWrite(w io.Writer, canonicalPath string, r AfterWriteResult) {
	if w == nil {
		w = os.Stdout
	}
	fmt.Fprintln(w)
	fmt.Fprintln(w, "=== QR PNG written ===")
	fmt.Fprintf(w, "Wrote QR PNG: %s\n", canonicalPath)
	for _, n := range r.Notes {
		fmt.Fprintln(w, n)
	}
	if r.SelectCmd != "" {
		fmt.Fprintf(w, "Reveal in Explorer:\n  %s\n", r.SelectCmd)
	}
	for _, c := range r.VisibleCopies {
		fmt.Fprintf(w, "Also copied (non-hidden):\n  %s\n", c)
	}
	if r.OpenErr != nil {
		fmt.Fprintf(w, "(could not auto-open PNG: %v)\n", r.OpenErr)
	}
	fmt.Fprintln(w, "=== end QR PNG ===")
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
