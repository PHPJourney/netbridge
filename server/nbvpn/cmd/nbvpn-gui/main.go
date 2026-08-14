package main

import (
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

//go:embed static/*
var staticFS embed.FS

var version = "1.0.0"

func main() {
	nbvpnPath, err := findNbvpn()
	if err != nil {
		fatalBox("nbvpn-gui", "找不到 nbvpn.exe。\n请先安装 NetBridge nbvpn（Setup），或把 nbvpn-gui.exe 与 nbvpn.exe 放在同一目录。\n\n"+err.Error())
		os.Exit(1)
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fatalBox("nbvpn-gui", "无法监听本地端口: "+err.Error())
		os.Exit(1)
	}
	addr := ln.Addr().String()
	mux := http.NewServeMux()
	api := &apiServer{nbvpn: nbvpnPath}
	mux.HandleFunc("/api/status", api.handleStatus)
	mux.HandleFunc("/api/start", api.handleStart)
	mux.HandleFunc("/api/stop", api.handleStop)
	mux.HandleFunc("/api/config", api.handleConfig)
	mux.HandleFunc("/api/uri", api.handleURI)
	mux.HandleFunc("/api/open-data", api.handleOpenData)
	mux.HandleFunc("/api/open-qr", api.handleOpenQR)
	mux.HandleFunc("/api/version", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{
			"gui":   version,
			"nbvpn": nbvpnPath,
			"goos":  runtime.GOOS,
		})
	})

	sub, err := fs.Sub(staticFS, "static")
	if err != nil {
		fatalBox("nbvpn-gui", err.Error())
		os.Exit(1)
	}
	mux.Handle("/", http.FileServer(http.FS(sub)))

	url := "http://" + addr + "/"
	go func() {
		time.Sleep(200 * time.Millisecond)
		_ = openBrowser(url)
	}()

	fmt.Printf("nbvpn-gui %s\nnbvpn: %s\nUI: %s\n(Keep this window open while using the GUI.)\n", version, nbvpnPath, url)
	if err := http.Serve(ln, mux); err != nil {
		fmt.Fprintf(os.Stderr, "server error: %v\n", err)
		os.Exit(1)
	}
}

type apiServer struct {
	nbvpn string
}

func (a *apiServer) run(args ...string) (stdout, stderr string, err error) {
	cmd := exec.Command(a.nbvpn, args...)
	var outBuf, errBuf strings.Builder
	cmd.Stdout = &outBuf
	cmd.Stderr = &errBuf
	err = cmd.Run()
	return outBuf.String(), errBuf.String(), err
}

func (a *apiServer) handleStatus(w http.ResponseWriter, r *http.Request) {
	out, errOut, err := a.run("status")
	st := parseStatus(out + "\n" + errOut)
	writeJSON(w, map[string]any{
		"ok":      err == nil,
		"state":   st,
		"raw":     strings.TrimSpace(out),
		"stderr":  strings.TrimSpace(errOut),
		"error":   errString(err),
	})
}

func (a *apiServer) handleStart(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	out, errOut, err := a.run("start")
	writeJSON(w, map[string]any{
		"ok":     err == nil,
		"output": strings.TrimSpace(out + "\n" + errOut),
		"error":  errString(err),
	})
}

func (a *apiServer) handleStop(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	out, errOut, err := a.run("stop")
	writeJSON(w, map[string]any{
		"ok":     err == nil,
		"output": strings.TrimSpace(out + "\n" + errOut),
		"error":  errString(err),
	})
}

func (a *apiServer) handleConfig(w http.ResponseWriter, r *http.Request) {
	out, errOut, err := a.run("config")
	writeJSON(w, map[string]any{
		"ok":     err == nil,
		"output": strings.TrimSpace(out),
		"stderr": strings.TrimSpace(errOut),
		"error":  errString(err),
	})
}

func (a *apiServer) handleURI(w http.ResponseWriter, r *http.Request) {
	out, errOut, err := a.run("show", "--uri")
	uri := strings.TrimSpace(out)
	writeJSON(w, map[string]any{
		"ok":     err == nil && strings.HasPrefix(uri, "nbvpn:"),
		"uri":    uri,
		"stderr": strings.TrimSpace(errOut),
		"error":  errString(err),
	})
}

func (a *apiServer) handleOpenData(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	dir := dataDir()
	err := revealPath(dir)
	writeJSON(w, map[string]any{"ok": err == nil, "path": dir, "error": errString(err)})
}

func (a *apiServer) handleOpenQR(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	out, errOut, err := a.run("show", "--file")
	if err != nil {
		writeJSON(w, map[string]any{"ok": false, "error": errString(err), "stderr": strings.TrimSpace(errOut)})
		return
	}
	png := ""
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasSuffix(strings.ToLower(line), ".png") {
			png = line
		}
	}
	if png == "" {
		writeJSON(w, map[string]any{"ok": false, "error": "no PNG path in nbvpn show --file", "raw": out})
		return
	}
	openErr := openFile(png)
	writeJSON(w, map[string]any{"ok": openErr == nil, "path": png, "error": errString(openErr)})
}

func parseStatus(raw string) string {
	low := strings.ToLower(raw)
	switch {
	case strings.Contains(low, "running"):
		return "running"
	case strings.Contains(low, "dry-run"):
		return "unknown"
	case strings.Contains(low, "not installed"), strings.Contains(low, "not running"), strings.Contains(low, "stopped"):
		return "stopped"
	default:
		if strings.TrimSpace(raw) == "" {
			return "unknown"
		}
		return "unknown"
	}
}

func dataDir() string {
	if v := strings.TrimSpace(os.Getenv("NBVPN_DATA_DIR")); v != "" {
		return v
	}
	if runtime.GOOS == "windows" {
		pd := strings.TrimSpace(os.Getenv("ProgramData"))
		if pd == "" {
			pd = `C:\ProgramData`
		}
		return filepath.Join(pd, "nbvpn")
	}
	return "/var/lib/nbvpn"
}

func findNbvpn() (string, error) {
	if v := strings.TrimSpace(os.Getenv("NBVPN_BIN")); v != "" {
		if st, err := os.Stat(v); err == nil && !st.IsDir() {
			return v, nil
		}
		return "", fmt.Errorf("NBVPN_BIN not found: %s", v)
	}
	self, err := os.Executable()
	if err == nil {
		dir := filepath.Dir(self)
		name := "nbvpn"
		if runtime.GOOS == "windows" {
			name = "nbvpn.exe"
		}
		cand := filepath.Join(dir, name)
		if st, err := os.Stat(cand); err == nil && !st.IsDir() {
			return cand, nil
		}
	}
	path, err := exec.LookPath("nbvpn")
	if err != nil {
		return "", fmt.Errorf("nbvpn not on PATH and not beside nbvpn-gui")
	}
	return path, nil
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	_ = enc.Encode(v)
}

func errString(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

func openBrowser(url string) error {
	switch runtime.GOOS {
	case "windows":
		return exec.Command("cmd", "/c", "start", "", url).Start()
	case "darwin":
		return exec.Command("open", url).Start()
	default:
		return exec.Command("xdg-open", url).Start()
	}
}

func revealPath(path string) error {
	if runtime.GOOS == "windows" {
		return exec.Command("explorer", path).Start()
	}
	if runtime.GOOS == "darwin" {
		return exec.Command("open", path).Start()
	}
	return exec.Command("xdg-open", path).Start()
}

func openFile(path string) error {
	if runtime.GOOS == "windows" {
		// Highlight in Explorer + open with default viewer
		_ = exec.Command("explorer", "/select,"+path).Start()
		return exec.Command("cmd", "/c", "start", "", path).Start()
	}
	if runtime.GOOS == "darwin" {
		return exec.Command("open", path).Start()
	}
	return exec.Command("xdg-open", path).Start()
}

func fatalBox(title, msg string) {
	fmt.Fprintf(os.Stderr, "%s: %s\n", title, msg)
	if runtime.GOOS == "windows" {
		// Avoid needing extra deps: PowerShell MessageBox
		ps := fmt.Sprintf(`Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show(%s, %s) | Out-Null`,
			psQuote(msg), psQuote(title))
		_ = exec.Command("powershell", "-NoProfile", "-Command", ps).Run()
	}
}

func psQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}
