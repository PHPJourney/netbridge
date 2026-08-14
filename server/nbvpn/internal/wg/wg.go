package wg

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/netbridge/nbvpn/internal/state"
	"golang.zx2c4.com/wireguard/wgctrl/wgtypes"
)

const SystemWGDir = "/etc/wireguard"

// Capabilities describes what the host can do.
type Capabilities struct {
	HasWGQuick    bool
	HasSystemd    bool
	HasWG         bool
	HasWireGuard  bool // Windows: wireguard.exe (tunnel service helper)
	DryRun        bool
	Platform      string
	Notes         string
}

// DetectCapabilities probes for wg-quick / systemd / wg / wireguard tools.
func DetectCapabilities() Capabilities {
	c := Capabilities{Platform: runtime.GOOS}
	c.HasWGQuick = lookPath("wg-quick")
	c.HasWG = lookPath("wg") || lookPath("wg.exe")
	c.HasWireGuard = lookPath("wireguard") || lookPath("wireguard.exe")
	c.HasSystemd = lookPath("systemctl") && fileExists("/run/systemd/system")

	switch runtime.GOOS {
	case "windows":
		if !c.HasWireGuard && !c.HasWG {
			c.DryRun = true
			c.Notes = "WireGuard for Windows not found: install from https://www.wireguard.com/install/ then re-run; keygen/show/profile export still work"
		} else if !c.HasWireGuard {
			c.DryRun = true
			c.Notes = "wg.exe found but wireguard.exe missing: tunnel service needs WireGuard for Windows (wireguard.exe)"
		}
	case "darwin":
		if !c.HasWGQuick {
			c.DryRun = true
			c.Notes = "macOS/dev without WireGuard tools: dry-run mode (keys + profiles only)"
		}
	default:
		if !c.HasWGQuick {
			c.DryRun = true
			c.Notes = "wg-quick not found: keygen/show/profile export work; start/stop use dry-run"
		}
	}
	return c
}

func lookPath(bin string) bool {
	_, err := exec.LookPath(bin)
	return err == nil
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

// GenerateKeyPair returns WireGuard private/public keys (base64).
func GenerateKeyPair() (priv, pub string, err error) {
	k, err := wgtypes.GeneratePrivateKey()
	if err != nil {
		return "", "", err
	}
	return k.String(), k.PublicKey().String(), nil
}

// SubnetCIDR returns the network CIDR for a host address (e.g. 10.8.0.1/24 → 10.8.0.0/24).
func SubnetCIDR(addr string) string {
	_, ipnet, err := net.ParseCIDR(strings.TrimSpace(addr))
	if err != nil || ipnet == nil {
		return "10.8.0.0/24"
	}
	return ipnet.String()
}

// BuildServerConf writes a wg-quick / wireguard-windows style server config.
func BuildServerConf(st *state.ServerState, peers []*state.PeerRecord) string {
	if runtime.GOOS == "windows" {
		return BuildServerConfWindows(st, peers)
	}
	return BuildServerConfLinux(st, peers)
}

// BuildServerConfLinux includes PostUp/PostDown for IP forwarding + MASQUERADE.
func BuildServerConfLinux(st *state.ServerState, peers []*state.PeerRecord) string {
	subnet := SubnetCIDR(st.Address)
	var b strings.Builder
	b.WriteString("# Managed by nbvpn — do not edit by hand\n")
	b.WriteString("[Interface]\n")
	b.WriteString(fmt.Sprintf("PrivateKey = %s\n", st.PrivateKey))
	b.WriteString(fmt.Sprintf("Address = %s\n", st.Address))
	b.WriteString(fmt.Sprintf("ListenPort = %d\n", st.ListenPort))
	// %i = wg interface name. MASQUERADE all client subnet traffic leaving non-wg NICs.
	b.WriteString(fmt.Sprintf(
		"PostUp = sysctl -q -w net.ipv4.ip_forward=1; iptables -A FORWARD -i %%i -j ACCEPT; iptables -A FORWARD -o %%i -j ACCEPT; iptables -t nat -A POSTROUTING -s %s ! -o %%i -j MASQUERADE\n",
		subnet,
	))
	b.WriteString(fmt.Sprintf(
		"PostDown = iptables -D FORWARD -i %%i -j ACCEPT; iptables -D FORWARD -o %%i -j ACCEPT; iptables -t nat -D POSTROUTING -s %s ! -o %%i -j MASQUERADE\n",
		subnet,
	))
	b.WriteString("\n")
	writePeers(&b, peers)
	return b.String()
}

// BuildServerConfWindows uses netsh / PowerShell equivalents (no iptables).
// Full client internet (NAT) is best completed by install.ps1 (New-NetNat / RRAS);
// PostUp reinforces IPv4 forwarding on the tunnel interface.
func BuildServerConfWindows(st *state.ServerState, peers []*state.PeerRecord) string {
	var b strings.Builder
	b.WriteString("# Managed by nbvpn — do not edit by hand\n")
	b.WriteString("# Windows: install WireGuard for Windows; prefer: wireguard.exe /installtunnelservice <this conf>\n")
	b.WriteString("# NAT for client internet: run server/install/windows/install.ps1 (New-NetNat) or enable RRAS\n")
	b.WriteString("[Interface]\n")
	b.WriteString(fmt.Sprintf("PrivateKey = %s\n", st.PrivateKey))
	b.WriteString(fmt.Sprintf("Address = %s\n", st.Address))
	b.WriteString(fmt.Sprintf("ListenPort = %d\n", st.ListenPort))
	// Interface alias matches tunnel name (conf basename without .conf).
	b.WriteString("PostUp = powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"try { Set-NetIPInterface -InterfaceAlias 'nbvpn' -AddressFamily IPv4 -Forwarding Enabled -ErrorAction Stop } catch { netsh interface ipv4 set interface interface=nbvpn forwarding=enabled }\"\n")
	b.WriteString("\n")
	writePeers(&b, peers)
	return b.String()
}

func writePeers(b *strings.Builder, peers []*state.PeerRecord) {
	for _, p := range peers {
		if p.Revoked {
			continue
		}
		b.WriteString(fmt.Sprintf("# peer %s (%s)\n", p.Name, p.ID))
		b.WriteString("[Peer]\n")
		b.WriteString(fmt.Sprintf("PublicKey = %s\n", p.PublicKey))
		b.WriteString(fmt.Sprintf("AllowedIPs = %s\n", p.Address))
		b.WriteString("\n")
	}
}

// EnsureIPForwarding writes a persistent sysctl drop-in and enables forwarding now (Linux).
func EnsureIPForwarding() {
	if runtime.GOOS == "windows" {
		EnsureIPForwardingWindows()
		return
	}
	_ = os.MkdirAll("/etc/sysctl.d", 0o755)
	body := "# Managed by nbvpn — required for VPN client internet access\nnet.ipv4.ip_forward = 1\n"
	_ = os.WriteFile("/etc/sysctl.d/99-nbvpn-forward.conf", []byte(body), 0o644)
	_ = run("sysctl", "-q", "-w", "net.ipv4.ip_forward=1")
}

// EnsureIPForwardingWindows enables IPv4 forwarding via netsh (best-effort).
func EnsureIPForwardingWindows() {
	_ = run("netsh", "interface", "ipv4", "set", "global", "forwarding=enabled")
	// Also try PowerShell Set-NetIPInterface on all IPv4 interfaces (ignore errors).
	_ = run("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
		`Get-NetIPInterface -AddressFamily IPv4 | Set-NetIPInterface -Forwarding Enabled -ErrorAction SilentlyContinue`)
}

// WriteConfigs writes data-dir conf and optionally system WireGuard conf.
func WriteConfigs(store *state.Store, st *state.ServerState, peers []*state.PeerRecord) error {
	if err := store.EnsureDirs(); err != nil {
		return err
	}
	body := BuildServerConf(st, peers)
	if err := os.WriteFile(store.WGConfPath(), []byte(body), 0o600); err != nil {
		return err
	}
	caps := DetectCapabilities()
	if runtime.GOOS == "windows" {
		if !caps.DryRun {
			EnsureIPForwardingWindows()
		}
		return nil
	}
	if caps.HasWGQuick && !caps.DryRun {
		EnsureIPForwarding()
		if err := os.MkdirAll(SystemWGDir, 0o755); err == nil {
			dst := filepath.Join(SystemWGDir, "nbvpn.conf")
			_ = os.WriteFile(dst, []byte(body), 0o600)
		}
	}
	return nil
}

// Sync applies config: rewrite files and reload interface when possible.
func Sync(store *state.Store, st *state.ServerState, peers []*state.PeerRecord) error {
	if err := WriteConfigs(store, st, peers); err != nil {
		return err
	}
	caps := DetectCapabilities()
	if caps.DryRun {
		return nil
	}
	if runtime.GOOS == "windows" {
		return syncWindows(store)
	}
	if !caps.HasWGQuick {
		return nil
	}
	// Prefer systemd restart if unit exists; else wg-quick strip+up
	if caps.HasSystemd && unitEnabled("wg-quick@nbvpn") {
		return run("systemctl", "restart", "wg-quick@nbvpn")
	}
	if interfaceUp("nbvpn") {
		// Reload live interface after peer/config changes (down+up is portable).
		_ = run("wg-quick", "down", "nbvpn")
		return run("wg-quick", "up", "nbvpn")
	}
	return nil
}

func syncWindows(store *state.Store) error {
	conf := store.WGConfPath()
	if !fileExists(conf) {
		return fmt.Errorf("missing %s; run install first", conf)
	}
	// Reinstall tunnel service so peer changes apply (wireguard-windows has no wg-quick strip).
	if winTunnelInstalled() {
		_ = runWireGuard("/uninstalltunnelservice", state.InterfaceName)
	}
	if err := runWireGuard("/installtunnelservice", conf); err != nil {
		return err
	}
	return nil
}

func unitEnabled(name string) bool {
	cmd := exec.Command("systemctl", "is-enabled", name)
	return cmd.Run() == nil
}

func interfaceUp(name string) bool {
	cmd := exec.Command(wgBin(), "show", name)
	return cmd.Run() == nil
}

func wgBin() string {
	if lookPath("wg.exe") {
		return "wg.exe"
	}
	return "wg"
}

func wireguardBin() string {
	if lookPath("wireguard.exe") {
		return "wireguard.exe"
	}
	return "wireguard"
}

func runWireGuard(args ...string) error {
	return run(wireguardBin(), args...)
}

func winTunnelServiceName() string {
	return "WireGuardTunnel$" + state.InterfaceName
}

func winTunnelInstalled() bool {
	cmd := exec.Command("sc.exe", "query", winTunnelServiceName())
	return cmd.Run() == nil
}

// EnableService enables and starts the WireGuard tunnel.
func EnableService() (dryRun bool, msg string, err error) {
	caps := DetectCapabilities()
	if caps.DryRun {
		return true, caps.Notes, nil
	}
	if runtime.GOOS == "windows" {
		return enableServiceWindows()
	}
	if !caps.HasWGQuick {
		return true, caps.Notes, nil
	}
	sysConf := filepath.Join(SystemWGDir, "nbvpn.conf")
	if !fileExists(sysConf) {
		return false, "", fmt.Errorf("missing %s; run install first", sysConf)
	}
	EnsureIPForwarding()
	if caps.HasSystemd {
		if err := run("systemctl", "enable", "--now", "wg-quick@nbvpn"); err != nil {
			// fallback to wg-quick
			if err2 := run("wg-quick", "up", "nbvpn"); err2 != nil {
				return false, "", fmt.Errorf("enable service failed: %v; wg-quick up: %v", err, err2)
			}
			return false, "started via wg-quick up nbvpn", nil
		}
		return false, "enabled systemd unit wg-quick@nbvpn", nil
	}
	if err := run("wg-quick", "up", "nbvpn"); err != nil {
		return false, "", err
	}
	return false, "started via wg-quick up nbvpn", nil
}

func enableServiceWindows() (dryRun bool, msg string, err error) {
	store := state.New(state.ResolveDataDir())
	conf := store.WGConfPath()
	if !fileExists(conf) {
		return false, "", fmt.Errorf("missing %s; run install first", conf)
	}
	EnsureIPForwardingWindows()
	if winTunnelInstalled() {
		_ = runWireGuard("/uninstalltunnelservice", state.InterfaceName)
	}
	if err := runWireGuard("/installtunnelservice", conf); err != nil {
		return false, "", fmt.Errorf("wireguard /installtunnelservice: %w (run elevated; install WireGuard for Windows)", err)
	}
	return false, "installed Windows service " + winTunnelServiceName(), nil
}

func Start() (dryRun bool, msg string, err error) {
	caps := DetectCapabilities()
	if caps.DryRun {
		return true, "dry-run: would start tunnel (" + caps.Notes + ")", nil
	}
	if runtime.GOOS == "windows" {
		if !winTunnelInstalled() {
			return EnableService()
		}
		if err := run("net", "start", winTunnelServiceName()); err != nil {
			// already running is ok-ish
			if interfaceUp(state.InterfaceName) {
				return false, "already running", nil
			}
			return false, "", actionable(err, "start")
		}
		return false, "started", nil
	}
	if !caps.HasWGQuick {
		return true, "dry-run: would start wg-quick@nbvpn (" + caps.Notes + ")", nil
	}
	if caps.HasSystemd {
		if err := run("systemctl", "start", "wg-quick@nbvpn"); err != nil {
			return false, "", actionable(err, "start")
		}
		return false, "started", nil
	}
	if err := run("wg-quick", "up", "nbvpn"); err != nil {
		return false, "", actionable(err, "start")
	}
	return false, "started", nil
}

func Stop() (dryRun bool, msg string, err error) {
	caps := DetectCapabilities()
	if caps.DryRun {
		return true, "dry-run: would stop tunnel (" + caps.Notes + ")", nil
	}
	if runtime.GOOS == "windows" {
		_ = run("net", "stop", winTunnelServiceName())
		_ = runWireGuard("/uninstalltunnelservice", state.InterfaceName)
		return false, "stopped", nil
	}
	if !caps.HasWGQuick {
		return true, "dry-run: would stop wg-quick@nbvpn (" + caps.Notes + ")", nil
	}
	if caps.HasSystemd {
		_ = run("systemctl", "stop", "wg-quick@nbvpn")
	}
	_ = run("wg-quick", "down", "nbvpn")
	return false, "stopped", nil
}

func Restart() (dryRun bool, msg string, err error) {
	if _, _, err := Stop(); err != nil {
		// continue
	}
	return Start()
}

// StatusText returns a human-readable status summary (no private keys).
func StatusText(st *state.ServerState) string {
	caps := DetectCapabilities()
	var b strings.Builder
	b.WriteString(fmt.Sprintf("platform: %s\n", caps.Platform))
	if caps.DryRun {
		b.WriteString("mode: dry-run (" + caps.Notes + ")\n")
		b.WriteString("service: not running (WireGuard tools unavailable)\n")
		return b.String()
	}
	running := false
	if runtime.GOOS == "windows" {
		cmd := exec.Command("sc.exe", "query", winTunnelServiceName())
		out, err := cmd.CombinedOutput()
		if err == nil {
			line := strings.ToLower(string(out))
			if strings.Contains(line, "running") {
				running = true
				b.WriteString(fmt.Sprintf("service: %s (RUNNING)\n", winTunnelServiceName()))
			} else {
				b.WriteString(fmt.Sprintf("service: %s (installed, not running)\n", winTunnelServiceName()))
			}
		} else {
			b.WriteString(fmt.Sprintf("service: %s (not installed)\n", winTunnelServiceName()))
		}
	} else if caps.HasSystemd {
		cmd := exec.Command("systemctl", "is-active", "wg-quick@nbvpn")
		out, _ := cmd.Output()
		running = strings.TrimSpace(string(out)) == "active"
		b.WriteString(fmt.Sprintf("systemd: %s\n", strings.TrimSpace(string(out))))
	}
	if caps.HasWG {
		cmd := exec.Command(wgBin(), "show", state.InterfaceName)
		out, err := cmd.CombinedOutput()
		if err == nil {
			running = true
			b.WriteString("interface: nbvpn (up)\n")
			// filter lines that might contain private keys (wg show does not print private by default)
			b.WriteString(string(out))
		} else {
			b.WriteString("interface: nbvpn (down)\n")
		}
	}
	if !running {
		b.WriteString("service: inactive\n")
	} else {
		b.WriteString("service: active\n")
	}
	if st != nil {
		b.WriteString(fmt.Sprintf("listenPort: %d\n", st.ListenPort))
		b.WriteString(fmt.Sprintf("endpoint: %s\n", st.Endpoint))
		b.WriteString(fmt.Sprintf("publicKey: %s\n", st.PublicKey))
	}
	return b.String()
}

func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s %s: %v (%s)", name, strings.Join(args, " "), err, strings.TrimSpace(string(out)))
	}
	return nil
}

func actionable(err error, op string) error {
	msg := err.Error()
	lower := strings.ToLower(msg)
	switch {
	case strings.Contains(lower, "permission") || strings.Contains(lower, "operation not permitted") || strings.Contains(lower, "access is denied"):
		return fmt.Errorf("%s failed: need elevated privileges (Administrator / sudo). detail: %w", op, err)
	case strings.Contains(lower, "address already in use") || strings.Contains(lower, "busy"):
		return fmt.Errorf("%s failed: port or interface may be in use. detail: %w", op, err)
	case strings.Contains(lower, "protocol not supported") || strings.Contains(lower, "modprobe"):
		return fmt.Errorf("%s failed: WireGuard kernel module may be unavailable. detail: %w", op, err)
	default:
		return fmt.Errorf("%s failed: %w", op, err)
	}
}

// RemoveSystemConf removes system WireGuard conf / Windows tunnel service if present.
func RemoveSystemConf() {
	if runtime.GOOS == "windows" {
		_ = run("net", "stop", winTunnelServiceName())
		_ = runWireGuard("/uninstalltunnelservice", state.InterfaceName)
		return
	}
	_ = os.Remove(filepath.Join(SystemWGDir, "nbvpn.conf"))
}
