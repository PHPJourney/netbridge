// Package obfs deploys a wstunnel-based obfuscation layer in front of the
// WireGuard UDP listener, so the node survives networks that fingerprint and
// block bare WireGuard UDP (e.g. mainland-China GFW scenarios).
//
// Architecture:
//
//	client (wstunnel client: local UDP :ObfsClientPort -> wss://domain/pathSecret)
//	  -> Cloudflare CDN (optional, hides the node IP entirely)
//	    -> server (wstunnel server: wss://0.0.0.0:443, restrict-to 127.0.0.1:wgPort)
//	      -> WireGuard (wg-quick@nbvpn, UDP wgPort on localhost)
package obfs

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// Version is the pinned wstunnel release deployed by this module.
const Version = "v10.7.0"

const (
	// DefaultPort is the wss listener port on the server (443 blends with HTTPS).
	DefaultPort = 443
	// DefaultClientPort is the local UDP port the client-side wstunnel listens on;
	// WireGuard's Endpoint then points at 127.0.0.1:<DefaultClientPort>.
	DefaultClientPort = 51821
	// BinaryName is the installed wstunnel binary name.
	BinaryName = "wstunnel"
	// ServiceName is the systemd unit name.
	ServiceName = "wstunnel-nbvpn"
	// StateFile is the persisted obfs config inside the nbvpn data dir.
	StateFile = "obfs.json"
)

// State is the persisted obfuscation-layer configuration.
type State struct {
	Version     int    `json:"v"`
	Enabled     bool   `json:"enabled"`
	WstunnelVer string `json:"wstunnelVersion"`
	Port        int    `json:"port"`
	PathSecret  string `json:"pathSecret"`
	Domain      string `json:"domain,omitempty"`
	WGPort      int    `json:"wgPort"`
	BinDir      string `json:"binDir"`
	InstalledAt string `json:"installedAt,omitempty"`
}

// Manager operates on the obfs layer for one nbvpn data dir.
type Manager struct {
	DataDir string
	BinDir  string
}

func New(dataDir string) *Manager {
	return &Manager{
		DataDir: dataDir,
		BinDir:  "/usr/local/bin",
	}
}

func (m *Manager) statePath() string { return filepath.Join(m.DataDir, StateFile) }

// Load reads obfs.json; returns a zero State when none exists yet.
func (m *Manager) Load() (*State, error) {
	b, err := os.ReadFile(m.statePath())
	if err != nil {
		if os.IsNotExist(err) {
			return &State{}, nil
		}
		return nil, fmt.Errorf("read obfs state: %w", err)
	}
	var st State
	if err := json.Unmarshal(b, &st); err != nil {
		return nil, fmt.Errorf("parse obfs state: %w", err)
	}
	return &st, nil
}

func (m *Manager) save(st *State) error {
	b, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(m.DataDir, 0o700); err != nil {
		return err
	}
	if err := os.WriteFile(m.statePath(), append(b, '\n'), 0o600); err != nil {
		return fmt.Errorf("write obfs state: %w", err)
	}
	return nil
}

// NewPathSecret returns a random hex path secret (the WebSocket upgrade prefix
// doubles as a shared secret between client and server).
func NewPathSecret() (string, error) {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}

// assetURL returns the pinned release tarball for the current GOOS/GOARCH.
func assetURL() (string, error) {
	var platform string
	switch runtime.GOARCH {
	case "amd64":
		platform = "amd64"
	case "arm64":
		platform = "arm64"
	default:
		return "", fmt.Errorf("unsupported server arch %q (supported: amd64, arm64)", runtime.GOARCH)
	}
	return fmt.Sprintf(
		"https://github.com/erebe/wstunnel/releases/download/%s/wstunnel_%s_linux_%s.tar.gz",
		Version, strings.TrimPrefix(Version, "v"), platform), nil
}

// systemdAvailable reports whether we can manage a systemd unit.
func systemdAvailable() bool {
	if runtime.GOOS != "linux" {
		return false
	}
	if _, err := exec.LookPath("systemctl"); err != nil {
		return false
	}
	if _, err := os.Stat("/run/systemd/system"); err != nil {
		return false
	}
	return true
}

// unit renders the systemd unit content for the given state.
func unit(st *State) string {
	pathArg := ""
	if st.PathSecret != "" {
		pathArg = fmt.Sprintf(` -r "/%s"`, st.PathSecret)
	}
	return fmt.Sprintf(`[Unit]
Description=wstunnel obfuscation layer for NetBridge nbvpn
Documentation=https://github.com/erebe/wstunnel
After=network-online.target wg-quick@nbvpn.service
Wants=network-online.target
Requires=wg-quick@nbvpn.service

[Service]
Type=simple
ExecStart=%s/wstunnel server wss://0.0.0.0:%d --restrict-to "127.0.0.1:%d"%s
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log

[Install]
WantedBy=multi-user.target
`, st.BinDir, st.Port, st.WGPort, pathArg)
}

// Install downloads wstunnel and deploys the systemd service.
// domain is optional (for Cloudflare instructions only); wgPort is the local
// WireGuard UDP port the server forwards to.
func (m *Manager) Install(domain string, port, wgPort int) (*State, error) {
	if !systemdAvailable() {
		return nil, fmt.Errorf("wstunnel auto-deploy requires Linux + systemd (detected %s/%s)", runtime.GOOS, runtime.GOARCH)
	}
	if port <= 0 {
		port = DefaultPort
	}
	if wgPort <= 0 {
		wgPort = 51820
	}
	existing, err := m.Load()
	if err != nil {
		return nil, err
	}
	if existing.Enabled {
		return nil, fmt.Errorf("obfs already enabled (run 'nbvpn obfs status'); uninstall first to re-install")
	}

	url, err := assetURL()
	if err != nil {
		return nil, err
	}
	secret, err := NewPathSecret()
	if err != nil {
		return nil, err
	}

	bin := filepath.Join(m.BinDir, BinaryName)
	// Download + extract wstunnel.
	tmp, err := os.MkdirTemp("", "nbvpn-wstunnel-*")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(tmp)
	tgz := filepath.Join(tmp, "wstunnel.tar.gz")
	fmt.Printf("downloading %s ...\n", url)
	if err := download(url, tgz); err != nil {
		return nil, fmt.Errorf("download wstunnel: %w", err)
	}
	if err := extractTGZ(tgz, tmp); err != nil {
		return nil, fmt.Errorf("extract wstunnel: %w", err)
	}
	src := filepath.Join(tmp, "wstunnel")
	if _, err := os.Stat(src); err != nil {
		return nil, fmt.Errorf("wstunnel binary not found in archive: %w", err)
	}
	if err := copyFile(src, bin, 0o755); err != nil {
		return nil, fmt.Errorf("install wstunnel to %s: %w", bin, err)
	}

	st := &State{
		Version:     1,
		Enabled:     true,
		WstunnelVer: Version,
		Port:        port,
		PathSecret:  secret,
		Domain:      domain,
		WGPort:      wgPort,
		BinDir:      m.BinDir,
		InstalledAt: time.Now().UTC().Format(time.RFC3339),
	}

	unitPath := filepath.Join("/etc/systemd/system", ServiceName+".service")
	if err := os.WriteFile(unitPath, []byte(unit(st)), 0o644); err != nil {
		return nil, fmt.Errorf("write systemd unit: %w", err)
	}

	if out, err := exec.Command("systemctl", "daemon-reload").CombinedOutput(); err != nil {
		return nil, fmt.Errorf("systemctl daemon-reload: %v (%s)", err, strings.TrimSpace(string(out)))
	}
	if out, err := exec.Command("systemctl", "enable", "--now", ServiceName).CombinedOutput(); err != nil {
		return nil, fmt.Errorf("systemctl enable --now %s: %v (%s)", ServiceName, err, strings.TrimSpace(string(out)))
	}

	if err := m.save(st); err != nil {
		return nil, err
	}
	return st, nil
}

// Uninstall stops and removes the wstunnel service and binary.
func (m *Manager) Uninstall() error {
	if systemdAvailable() {
		_ = exec.Command("systemctl", "disable", "--now", ServiceName).Run()
		_ = os.Remove(filepath.Join("/etc/systemd/system", ServiceName+".service"))
		_ = exec.Command("systemctl", "daemon-reload").Run()
	}
	_ = os.Remove(filepath.Join(m.BinDir, BinaryName))
	_ = os.Remove(m.statePath())
	return nil
}

// Status returns the running state of the systemd service.
func (m *Manager) Status() (string, error) {
	if !systemdAvailable() {
		return "systemd not available", nil
	}
	out, err := exec.Command("systemctl", "is-active", ServiceName).CombinedOutput()
	return strings.TrimSpace(string(out)), err
}
