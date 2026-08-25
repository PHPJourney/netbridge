package state

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const (
	// DefaultDataDir is the Linux default; on Windows PreferWritableDataDir uses ProgramData.
	DefaultDataDir     = "/var/lib/nbvpn"
	FallbackDataDir    = "/usr/local/var/lib/nbvpn"
	EnvDataDir         = "NBVPN_DATA_DIR"
	// EnvSplitTunnel: when "1"/"true"/"yes", new installs use VPN-subnet-only client AllowedIPs.
	EnvSplitTunnel = "NBVPN_SPLIT_TUNNEL"
	InterfaceName      = "nbvpn"
	DefaultListenPort  = 51820
	DefaultServerAddr  = "10.8.0.1/24"
	DefaultSubnetBase  = "10.8.0"
	DefaultClientStart = 2
)

// PlatformDefaultDataDirs returns primary and fallback data directories for this OS.
func PlatformDefaultDataDirs() (primary, fallback string) {
	if runtime.GOOS == "windows" {
		pd := strings.TrimSpace(os.Getenv("ProgramData"))
		if pd == "" {
			pd = `C:\ProgramData`
		}
		la := strings.TrimSpace(os.Getenv("LOCALAPPDATA"))
		if la == "" {
			home := strings.TrimSpace(os.Getenv("USERPROFILE"))
			if home == "" {
				home = `C:\Users\Public`
			}
			la = filepath.Join(home, "AppData", "Local")
		}
		return filepath.Join(pd, "nbvpn"), filepath.Join(la, "nbvpn")
	}
	return DefaultDataDir, FallbackDataDir
}

// ServerState persists node configuration (includes server private key on disk only).
type ServerState struct {
	Version      int      `json:"v"`
	Interface    string   `json:"interface"`
	ListenPort   int      `json:"listenPort"`
	PrivateKey   string   `json:"privateKey"`
	PublicKey    string   `json:"publicKey"`
	Address      string   `json:"address"`
	Endpoint     string   `json:"endpoint"`
	// EndpointV6 is an optional alternate public endpoint (IPv6 literal or host:port).
	EndpointV6 string `json:"endpointV6,omitempty"`
	// IPv6Enabled marks whether clients should prefer EndpointV6 when connecting.
	IPv6Enabled bool `json:"ipv6Enabled,omitempty"`
	DNS          []string `json:"dns"`
	AllowedIPs   []string `json:"allowedIPs"`
	NextClientIP int      `json:"nextClientIP"`
	InstalledAt  string   `json:"installedAt"`
}

// PeerRecord is a client peer (revoked peers are kept until purged on uninstall).
type PeerRecord struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	PublicKey  string `json:"publicKey"`
	PrivateKey string `json:"privateKey"`
	Address    string `json:"address"`
	CreatedAt  string `json:"createdAt"`
	Revoked    bool   `json:"revoked"`
}

// Store manages on-disk state under DataDir.
type Store struct {
	DataDir string
}

// ResolveDataDir returns NBVPN_DATA_DIR, or the platform default.
func ResolveDataDir() string {
	if v := strings.TrimSpace(os.Getenv(EnvDataDir)); v != "" {
		return v
	}
	primary, _ := PlatformDefaultDataDirs()
	return primary
}

// PreferWritableDataDir picks a writable data dir for install.
func PreferWritableDataDir() (string, error) {
	if v := strings.TrimSpace(os.Getenv(EnvDataDir)); v != "" {
		if err := os.MkdirAll(v, 0o700); err != nil {
			return "", fmt.Errorf("cannot create NBVPN_DATA_DIR %s: %w", v, err)
		}
		return v, nil
	}
	primary, fallback := PlatformDefaultDataDirs()
	if err := os.MkdirAll(primary, 0o700); err == nil {
		return primary, nil
	}
	if err := os.MkdirAll(fallback, 0o700); err != nil {
		return "", fmt.Errorf("cannot create data dir (%s or %s); set %s or run as Administrator/root: %w",
			primary, fallback, EnvDataDir, err)
	}
	return fallback, nil
}

func New(dataDir string) *Store {
	if dataDir == "" {
		dataDir = ResolveDataDir()
	}
	return &Store{DataDir: dataDir}
}

func (s *Store) serverPath() string {
	return filepath.Join(s.DataDir, "server.json")
}

func (s *Store) peersDir() string {
	return filepath.Join(s.DataDir, "peers")
}

func (s *Store) peerMetaPath(id string) string {
	return filepath.Join(s.peersDir(), id+".json")
}

func (s *Store) PeerProfilePath(id string) string {
	return filepath.Join(s.peersDir(), id+".nbvpn.json")
}

// PeerQRPath is an optional PNG of the full nbvpn: URI (same payload as terminal QR).
func (s *Store) PeerQRPath(id string) string {
	return filepath.Join(s.peersDir(), id+".png")
}

// PeerWGConfPath is a wg-quick / official WireGuard client .conf for this peer.
func (s *Store) PeerWGConfPath(id string) string {
	return filepath.Join(s.peersDir(), id+".conf")
}

func (s *Store) WGConfPath() string {
	return filepath.Join(s.DataDir, "nbvpn.conf")
}

func (s *Store) EnsureDirs() error {
	if err := os.MkdirAll(s.DataDir, 0o700); err != nil {
		return err
	}
	return os.MkdirAll(s.peersDir(), 0o700)
}

func (s *Store) Exists() bool {
	_, err := os.Stat(s.serverPath())
	return err == nil
}

func (s *Store) SaveServer(st *ServerState) error {
	if err := s.EnsureDirs(); err != nil {
		return err
	}
	b, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.serverPath(), b, 0o600)
}

func (s *Store) LoadServer() (*ServerState, error) {
	b, err := os.ReadFile(s.serverPath())
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("nbvpn is not installed (missing %s); run: nbvpn install", s.serverPath())
		}
		return nil, err
	}
	var st ServerState
	if err := json.Unmarshal(b, &st); err != nil {
		return nil, fmt.Errorf("corrupt server.json: %w", err)
	}
	return &st, nil
}

func (s *Store) SavePeer(p *PeerRecord) error {
	if err := s.EnsureDirs(); err != nil {
		return err
	}
	b, err := json.MarshalIndent(p, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.peerMetaPath(p.ID), b, 0o600)
}

func (s *Store) LoadPeer(id string) (*PeerRecord, error) {
	b, err := os.ReadFile(s.peerMetaPath(id))
	if err != nil {
		return nil, err
	}
	var p PeerRecord
	if err := json.Unmarshal(b, &p); err != nil {
		return nil, err
	}
	return &p, nil
}

func (s *Store) ListPeers() ([]*PeerRecord, error) {
	entries, err := os.ReadDir(s.peersDir())
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var out []*PeerRecord
	for _, e := range entries {
		name := e.Name()
		if !strings.HasSuffix(name, ".json") || strings.HasSuffix(name, ".nbvpn.json") {
			continue
		}
		p, err := s.LoadPeer(strings.TrimSuffix(name, ".json"))
		if err != nil {
			continue
		}
		out = append(out, p)
	}
	return out, nil
}

func (s *Store) FindPeer(idOrName string) (*PeerRecord, error) {
	peers, err := s.ListPeers()
	if err != nil {
		return nil, err
	}
	for _, p := range peers {
		if p.ID == idOrName || p.Name == idOrName {
			return p, nil
		}
	}
	return nil, fmt.Errorf("peer not found: %s", idOrName)
}

func (s *Store) ActivePeers() ([]*PeerRecord, error) {
	all, err := s.ListPeers()
	if err != nil {
		return nil, err
	}
	var out []*PeerRecord
	for _, p := range all {
		if !p.Revoked {
			out = append(out, p)
		}
	}
	return out, nil
}

func (s *Store) WritePeerProfileJSON(id string, data []byte) error {
	if err := s.EnsureDirs(); err != nil {
		return err
	}
	return os.WriteFile(s.PeerProfilePath(id), data, 0o600)
}

func (s *Store) WritePeerWGConf(id string, conf string) error {
	if err := s.EnsureDirs(); err != nil {
		return err
	}
	return os.WriteFile(s.PeerWGConfPath(id), []byte(conf), 0o600)
}

// DeletePeer removes peer metadata and all export artifacts (profile, WG conf, QR).
// The peer's VPN address is not recycled into NextClientIP (same as revoke).
func (s *Store) DeletePeer(id string) error {
	if _, err := s.LoadPeer(id); err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("peer not found: %s", id)
		}
		return err
	}
	var firstErr error
	for _, p := range []string{
		s.peerMetaPath(id),
		s.PeerProfilePath(id),
		s.PeerWGConfPath(id),
		s.PeerQRPath(id),
	} {
		if err := os.Remove(p); err != nil && !os.IsNotExist(err) && firstErr == nil {
			firstErr = err
		}
	}
	return firstErr
}

func (s *Store) RemoveAll() error {
	return os.RemoveAll(s.DataDir)
}

func NowRFC3339() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func ShortID() string {
	return fmt.Sprintf("%d", time.Now().UnixNano()%1_000_000_000_000)
}
