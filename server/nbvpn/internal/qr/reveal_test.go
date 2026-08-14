package qr

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestAfterWrite_nonWindowsQuiet(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("windows has side effects; covered by manual / CI smoke")
	}
	dir := t.TempDir()
	path := filepath.Join(dir, "123.png")
	if err := os.WriteFile(path, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	r := AfterWrite(path)
	if r.Opened {
		t.Fatal("should not auto-open on non-windows")
	}
	if len(r.VisibleCopies) != 0 {
		t.Fatalf("unexpected copies: %v", r.VisibleCopies)
	}
	var b strings.Builder
	PrintAfterWrite(&b, path, r)
	out := b.String()
	if !strings.Contains(out, "Wrote QR PNG:") {
		t.Fatalf("missing wrote line: %s", out)
	}
	if !strings.Contains(out, path) {
		t.Fatalf("missing path: %s", out)
	}
}
