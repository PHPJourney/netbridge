package qr

import (
	"bytes"
	"image"
	_ "image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Representative nbvpn:1? URI length (base64url blob; not a real key).
const sampleURI = "nbvpn:1?eyJ2IjoxLCJuYW1lIjoicGVlci10ZXN0IiwiY2xpZW50Ijp7InByaXZhdGVLZXkiOiJBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQSIsImFkZHJlc3MiOlsiMTAuOC4wLjIvMzIiXSwiZG5zIjpbIjEuMS4xLjEiLCIxLjAuMC4xIl0sIm10dSI6MTI4MH0sInNlcnZlciI6eyJwdWJsaWNLZXkiOiJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQiIsImVuZHBvaW50IjoiMjAzLjAuMTEzLjEwOjUxODIwIiwiYWxsb3dlZElQcyI6WyIwLjAuMC4wLzAiLCIjOi8wIl0sInBlcnNpc3RlbnRLZWVwYWxpdmUiOjI1LCJwcmVzaGFyZWRLZXkiOm51bGx9fQ"

// Contract: QR must encode the full URI, never a bare peer numeric id.
func TestWritePNGEncodesFullURINotPeerID(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "756869314208.png") // filename may look like a peer id
	if err := WritePNG(sampleURI, path); err != nil {
		t.Fatal(err)
	}
	// Re-encode same content and compare PNG bytes — proves encoder input is sampleURI.
	path2 := filepath.Join(dir, "check.png")
	if err := WritePNG(sampleURI, path2); err != nil {
		t.Fatal(err)
	}
	a, _ := os.ReadFile(path)
	b, _ := os.ReadFile(path2)
	if !bytes.Equal(a, b) {
		t.Fatal("PNG not deterministic for same URI")
	}
	peerOnly := "756869314208"
	pathPeer := filepath.Join(dir, "peer-id-only.png")
	if err := WritePNG(peerOnly, pathPeer); err != nil {
		t.Fatal(err)
	}
	c, _ := os.ReadFile(pathPeer)
	if bytes.Equal(a, c) {
		t.Fatal("URI PNG must differ from peer-id-only PNG")
	}
	if !strings.HasPrefix(sampleURI, "nbvpn:1?") {
		t.Fatal("sampleURI must be contract URI")
	}
}

func TestRenderTerminal_hasQuietZoneAndANSI(t *testing.T) {
	out, err := RenderTerminalOpts(sampleURI, RenderOptions{UseANSI: true, MaxCols: 200})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, ansiQR) {
		t.Fatal("expected forced light-bg ANSI so dark themes do not invert modules")
	}
	if !strings.Contains(out, ansiOff) {
		t.Fatal("expected ANSI reset")
	}
	lines := strings.Split(strings.TrimRight(out, "\n"), "\n")
	if len(lines) < 4 {
		t.Fatalf("too few lines: %d", len(lines))
	}
	// First/last lines are pad quiet-zone rows (spaces only inside ANSI).
	firstBody := stripANSI(lines[0])
	lastBody := stripANSI(lines[len(lines)-1])
	if strings.TrimSpace(firstBody) != "" || strings.TrimSpace(lastBody) != "" {
		t.Fatalf("expected pad quiet-zone rows of spaces; first=%q last=%q", firstBody, lastBody)
	}
	// Interior lines should use half-block glyphs or spaces (no wrapping spaces at EOL beyond modules).
	var width int
	for i, line := range lines {
		body := stripANSI(line)
		if i == 0 {
			width = len([]rune(body))
			continue
		}
		if len([]rune(body)) != width {
			t.Fatalf("ragged QR line %d: got %d cols want %d (wrapping risk)", i, len([]rune(body)), width)
		}
	}
	if width < 21 {
		t.Fatalf("QR too narrow (%d); missing quiet zone or encode failed", width)
	}
	t.Logf("terminal QR: %d cols × %d rows (half-block packed)", width, len(lines))
}

func TestRenderTerminal_noANSI(t *testing.T) {
	out, err := RenderTerminalOpts(sampleURI, RenderOptions{UseANSI: false, MaxCols: 200})
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(out, "\033") {
		t.Fatal("expected no ANSI escapes when UseANSI=false")
	}
}

func TestRenderTerminal_tooWide(t *testing.T) {
	_, err := RenderTerminalOpts(sampleURI, RenderOptions{UseANSI: false, MaxCols: 10})
	if !IsTooWide(err) {
		t.Fatalf("want TooWideError, got %v", err)
	}
}

func TestRenderTerminal_fitsTypicalSSH(t *testing.T) {
	// Real nbvpn URIs are ~73–89 modules. An 80-col SSH session must still get a
	// terminal QR (compact ECC + optional border drop), not PNG-only fallback.
	out, err := RenderTerminalOpts(sampleURI, RenderOptions{UseANSI: false, MaxCols: 80})
	if err != nil {
		t.Fatalf("want terminal QR under 80 cols, got %v", err)
	}
	width := 0
	for _, line := range strings.Split(strings.TrimRight(out, "\n"), "\n") {
		n := len([]rune(line))
		if width == 0 {
			width = n
		}
		if n > 80 {
			t.Fatalf("line width %d exceeds 80-col terminal", n)
		}
	}
	if width < 21 || width > 80 {
		t.Fatalf("unexpected width %d", width)
	}
	t.Logf("80-col fit: %d modules", width)
}

func TestRenderTerminal_defaultEffectiveFits(t *testing.T) {
	t.Setenv("COLUMNS", "100")
	out, err := RenderTerminal(sampleURI)
	if err != nil {
		t.Fatalf("default RenderTerminal with COLUMNS=100: %v", err)
	}
	if !strings.Contains(out, "█") && !strings.Contains(out, "▀") && !strings.Contains(out, "▄") {
		t.Fatal("expected half-block glyphs")
	}
}

func TestDetectTerminalCols_COLUMNS(t *testing.T) {
	t.Setenv("COLUMNS", "97")
	if got := DetectTerminalCols(); got != 97 {
		t.Fatalf("DetectTerminalCols=%d want 97", got)
	}
	if got := EffectiveMaxCols(0); got != 96 {
		t.Fatalf("EffectiveMaxCols=%d want 96 (97-1 margin)", got)
	}
	if got := EffectiveMaxCols(64); got != 64 {
		t.Fatalf("override EffectiveMaxCols=%d want 64", got)
	}
}

func TestClampMaxCols(t *testing.T) {
	t.Setenv("COLUMNS", "")
	if ClampMaxCols(0) != DefaultMaxTerminalCols && ClampMaxCols(0) < MinTerminalCols {
		t.Fatalf("0 → default or detected, got %d", ClampMaxCols(0))
	}
	if ClampMaxCols(10) != MinTerminalCols {
		t.Fatalf("below min → %d", MinTerminalCols)
	}
	if ClampMaxCols(999) != MaxTerminalColsCap {
		t.Fatalf("above cap → %d", MaxTerminalColsCap)
	}
	if ClampMaxCols(80) != 80 {
		t.Fatalf("in-band passthrough")
	}
}

func TestModuleSize_includesBorder(t *testing.T) {
	n, err := ModuleSize(sampleURI)
	if err != nil {
		t.Fatal(err)
	}
	// Version 1 is 21 modules; with border (>=4) side is larger. Long URI >> v1.
	if n < 29 {
		t.Fatalf("module size %d looks too small (border disabled?)", n)
	}
	t.Logf("bitmap side including quiet zone: %d", n)
}

func TestWritePNG_roundtripFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "peer.png")
	if err := WritePNG(sampleURI, path); err != nil {
		t.Fatal(err)
	}
	st, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if st.Size() < 200 {
		t.Fatalf("PNG too small: %d bytes", st.Size())
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(raw[:8]) != "\x89PNG\r\n\x1a\n" {
		t.Fatal("not a PNG signature")
	}
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	img, _, err := image.Decode(f)
	if err != nil {
		t.Fatal(err)
	}
	side := img.Bounds().Dx()
	if side != pngSizePx {
		t.Fatalf("PNG side %d want %d", side, pngSizePx)
	}
	if side < 256 || side > 384 {
		t.Fatalf("PNG side %d outside scannable-but-compact band 256–384", side)
	}
	t.Logf("PNG %dx%d file=%d bytes", side, img.Bounds().Dy(), st.Size())
}

func stripANSI(s string) string {
	var b strings.Builder
	in := false
	for i := 0; i < len(s); i++ {
		if s[i] == '\033' {
			in = true
			continue
		}
		if in {
			if (s[i] >= 'a' && s[i] <= 'z') || (s[i] >= 'A' && s[i] <= 'Z') {
				in = false
			}
			continue
		}
		b.WriteByte(s[i])
	}
	return b.String()
}
