package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/netbridge/nbvpn/internal/endpoint"
	"github.com/netbridge/nbvpn/internal/profile"
	"github.com/netbridge/nbvpn/internal/qr"
	"github.com/netbridge/nbvpn/internal/state"
	"github.com/netbridge/nbvpn/internal/wg"
)

const secretWarning = "WARNING: URI / QR / profile file contain the client private key — treat as secrets; do not share publicly."

// Version is set from main via -ldflags / default.
var Version = "1.0.0"

// Run is the CLI entrypoint. Returns process exit code.
func Run(args []string) int {
	if len(args) == 0 {
		// No args: common when double-clicking the .exe on Windows — print
		// Chinese usage and pause if we own the console alone (else window
		// closes instantly and looks like a crash).
		printHelpZh(os.Stdout)
		pauseIfDoubleClickConsole()
		return 0
	}
	cmd := args[0]
	rest := args[1:]
	var err error
	switch cmd {
	case "help", "-h", "--help":
		printHelpZh(os.Stdout)
		printHelp(os.Stdout)
		return 0
	case "install":
		err = cmdInstall(rest)
	case "show":
		err = cmdShow(rest)
	case "config":
		err = cmdConfig(rest)
	case "status":
		err = cmdStatus(rest)
	case "start":
		err = cmdStart()
	case "stop":
		err = cmdStop()
	case "restart":
		err = cmdRestart()
	case "peer":
		err = cmdPeer(rest)
	case "uninstall":
		err = cmdUninstall(rest)
	case "version", "--version":
		fmt.Printf("nbvpn %s\n", Version)
		return 0
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n", cmd)
		printHelpZh(os.Stderr)
		printHelp(os.Stderr)
		return 1
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return 1
	}
	return 0
}

func printHelpZh(w *os.File) {
	fmt.Fprint(w, `nbvpn — 网桥 VPN 服务端命令行（WireGuard）

用法（请在 CMD / PowerShell 中运行，不要双击 exe）：
  nbvpn <命令> [参数]

常用命令:
  version                         打印版本（验证 exe 能否启动）
  install                         安装/配置节点、首个 peer、启用服务
  show [--uri|--qr|--file|--conf|--all]
                                  显示客户端连接信息（默认 --all）
  status                          服务 / 隧道状态
  start | stop | restart          管理 WireGuard 服务
  peer add [name]                 新增客户端 peer
  peer list                       列出 peer
  peer revoke <id|name>           吊销 peer
  config set endpoint <host[:port]>
                                  设置对外 endpoint
  uninstall [--yes]               停止服务并清理数据
  help                            显示帮助

Windows Server 2012 / 2012 R2:
  推荐双击安装: NetBridge-nbvpn-Setup-win2012.exe
  含 WireGuard 0.5.3（历史官方）+ Win32 GUI（纯 Win32）
  装好后: 开始菜单 →「NetBridge nbvpn GUI」
  说明见 WINDOWS.md

`)
}

func printHelp(w *os.File) {
	fmt.Fprint(w, `nbvpn — NetBridge VPN server CLI (WireGuard)

Usage:
  nbvpn <command> [arguments]

Commands:
  install                         Install/configure node, first peer, enable service
  show [--uri|--qr|--file|--conf|--all]  Show connection info for a peer (default: --all)
  config                          Show node summary (no server private key)
  config set endpoint <host[:port]>
                                  Set public endpoint used in client profiles
  status                          Service / tunnel status
  start | stop | restart          Manage WireGuard service
  peer add [name]                 Add a client peer and show its URI/QR/file
  peer list                       List peers
  peer revoke <id|name>           Revoke a peer (old profiles stop working)
  uninstall [--yes]               Stop service and remove nbvpn data
  version                         Print version
  help                            Show this help

Environment:
  NBVPN_DATA_DIR   Override state directory
                   (Linux default /var/lib/nbvpn;
                    Windows default %ProgramData%\nbvpn;
                    fallback if unwritable)
  NBVPN_TERMINAL_QR=1  Force terminal QR on Windows default show
  NO_COLOR / NBVPN_FORCE_ANSI  Disable / force ANSI color in terminal QR

Firewall / endpoint:
  Clients need UDP listen port open on host firewall AND cloud security group
  (default 51820). See server/install/FIREWALL.md
  If public IP detect fails:  nbvpn config set endpoint <host[:port]>

Dry-run:
  On macOS, hosts without wg-quick, or Windows without WireGuard for Windows,
  install still generates keys and profiles (data dir + PNG/JSON/conf);
  start/stop/status report dry-run. Install WireGuard before a real tunnel.

Pipe tip:
  nbvpn show --uri   # URI on stdout; secret warning on stderr
  nbvpn show --qr    # terminal QR (Windows: opt-in; prefer open PNG)

`)
}

func store() *state.Store {
	return state.New(state.ResolveDataDir())
}

func cmdInstall(args []string) error {
	_ = args
	dir, err := state.PreferWritableDataDir()
	if err != nil {
		return err
	}
	os.Setenv(state.EnvDataDir, dir)
	s := state.New(dir)

	if s.Exists() {
		fmt.Printf("nbvpn already installed at %s (repairing configs)\n", dir)
	}

	caps := wg.DetectCapabilities()
	var st *state.ServerState
	if s.Exists() {
		st, err = s.LoadServer()
		if err != nil {
			return err
		}
	} else {
		priv, pub, err := wg.GenerateKeyPair()
		if err != nil {
			return fmt.Errorf("generate server keys: %w", err)
		}
		ip := endpoint.DetectPublicIP()
		ep := ""
		if ip != "" {
			ep = fmt.Sprintf("%s:%d", ip, state.DefaultListenPort)
		}
		st = &state.ServerState{
			Version:      1,
			Interface:    state.InterfaceName,
			ListenPort:   state.DefaultListenPort,
			PrivateKey:   priv,
			PublicKey:    pub,
			Address:      state.DefaultServerAddr,
			Endpoint:     ep,
			DNS:          []string{profile.DefaultDNS1, profile.DefaultDNS2},
			AllowedIPs:   []string{"0.0.0.0/0", "::/0"},
			NextClientIP: state.DefaultClientStart,
			InstalledAt:  state.NowRFC3339(),
		}
		if err := s.SaveServer(st); err != nil {
			return err
		}
	}

	peers, err := s.ActivePeers()
	if err != nil {
		return err
	}
	if len(peers) == 0 {
		p, err := addPeer(s, st, "peer-1")
		if err != nil {
			return err
		}
		peers = []*state.PeerRecord{p}
	}

	if err := wg.WriteConfigs(s, st, mustAllPeers(s)); err != nil {
		return fmt.Errorf("write WireGuard config: %w", err)
	}

	dry, msg, err := wg.EnableService()
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: service enable: %v\n", err)
	} else if dry {
		fmt.Printf("install: dry-run mode — %s\n", msg)
	} else {
		fmt.Printf("service: %s\n", msg)
	}

	fmt.Println()
	fmt.Println("=== nbvpn install complete ===")
	fmt.Printf("data dir: %s\n", s.DataDir)
	printDataDirVerify(s)
	fmt.Printf("publicKey: %s\n", st.PublicKey)
	fmt.Printf("listenPort: %d\n", st.ListenPort)
	if st.Endpoint == "" {
		fmt.Println()
		fmt.Println("Could not detect public IP for endpoint.")
		fmt.Println("Set it with:  nbvpn config set endpoint <your-public-ip-or-dns>")
	} else {
		fmt.Printf("endpoint: %s\n", st.Endpoint)
	}
	if caps.DryRun {
		fmt.Println()
		fmt.Println("Note:", caps.Notes)
		if caps.Platform == "windows" {
			fmt.Println("IMPORTANT: Install WireGuard for Windows before a real tunnel:")
			fmt.Println("  https://www.wireguard.com/install/")
			fmt.Println("  Profiles/keys are already written; re-run install.ps1 after WireGuard is installed.")
		}
	}
	fmt.Println()
	fmt.Println("Firewall (required for clients to reach this node):")
	fmt.Printf("  • Host: allow UDP %d\n", st.ListenPort)
	fmt.Printf("  • Cloud security group / ACL: inbound UDP %d\n", st.ListenPort)
	if caps.Platform == "windows" {
		fmt.Println("  • Windows: NetBridge-nbvpn-Setup.exe or install.ps1 (firewall + IP forward; see WINDOWS.md)")
		fmt.Println("  • Data dir is under ProgramData (often hidden): explorer %ProgramData%\\nbvpn")
		fmt.Println("  • Details: server/install/windows/WINDOWS.md + server/install/FIREWALL.md")
	} else {
		fmt.Println("  • NAT: nbvpn enables ip_forward + MASQUERADE (PostUp); if ufw is on, also:")
		fmt.Println("      sudo sed -i 's/DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/' /etc/default/ufw && sudo ufw reload")
		fmt.Println("  • Details: server/install/FIREWALL.md")
	}
	fmt.Println()
	fmt.Println("Next steps:")
	if runtime.GOOS == "windows" {
		fmt.Println("  1. nbvpn show          # URI + files + PNG path (no terminal QR by default)")
		fmt.Println("     Open the .png in Explorer, or: nbvpn show --uri / nbvpn show --qr")
	} else {
		fmt.Println("  1. nbvpn show          # URI + QR + profile file (secrets!)")
	}
	fmt.Println("  2. Download a client from your NetBridge store page")
	fmt.Println("  3. Import the URI / QR PNG / .nbvpn.json, or WireGuard .conf (nbvpn show --conf)")
	fmt.Println()

	// show first active peer
	if len(peers) > 0 {
		return showPeer(s, st, peers[0], showModeAll)
	}
	return nil
}

func printDataDirVerify(s *state.Store) {
	fmt.Println("--- verify data dir ---")
	check := func(label, path string) {
		if st, err := os.Stat(path); err == nil && !st.IsDir() {
			fmt.Printf("  OK  %s\n", path)
		} else if err == nil && st.IsDir() {
			fmt.Printf("  OK  %s\\ (dir)\n", path)
		} else {
			fmt.Printf("  MISSING  %s (%v)\n", path, err)
		}
	}
	check("data", s.DataDir)
	check("server.json", filepath.Join(s.DataDir, "server.json"))
	check("nbvpn.conf", s.WGConfPath())
	peersDir := filepath.Join(s.DataDir, "peers")
	check("peers", peersDir)
	entries, err := os.ReadDir(peersDir)
	if err != nil {
		fmt.Printf("  (could not list peers: %v)\n", err)
		return
	}
	n := 0
	for _, e := range entries {
		name := e.Name()
		if strings.HasSuffix(name, ".nbvpn.json") || strings.HasSuffix(name, ".png") || strings.HasSuffix(name, ".conf") {
			fmt.Printf("  OK  %s\n", filepath.Join(peersDir, name))
			n++
		}
	}
	if n == 0 {
		fmt.Println("  (no peer export files yet — unexpected after install)")
	}
	if runtime.GOOS == "windows" {
		fmt.Println("Tip: ProgramData is a hidden folder. Run:  explorer %ProgramData%\\nbvpn")
		fmt.Println("  or enable \"Hidden items\" in Explorer View options.")
	}
}

func mustAllPeers(s *state.Store) []*state.PeerRecord {
	all, err := s.ListPeers()
	if err != nil {
		return nil
	}
	return all
}

func addPeer(s *state.Store, st *state.ServerState, name string) (*state.PeerRecord, error) {
	priv, pub, err := wg.GenerateKeyPair()
	if err != nil {
		return nil, err
	}
	octet := st.NextClientIP
	if octet < 2 || octet > 254 {
		return nil, fmt.Errorf("client IP pool exhausted (nextClientIP=%d); revoke unused peers or raise subnet capacity", octet)
	}
	addr := fmt.Sprintf("%s.%d/32", state.DefaultSubnetBase, octet)
	id := state.ShortID()
	name = strings.TrimSpace(name)
	if name == "" {
		name = "peer-" + id
	}
	if err := validatePeerName(name); err != nil {
		return nil, err
	}
	if dup := findActivePeerByName(s, name); dup != nil {
		fmt.Fprintf(os.Stderr, "warning: another active peer already uses name %q (id %s); names need not be unique — prefer distinct names\n", name, dup.ID)
	}
	p := &state.PeerRecord{
		ID:         id,
		Name:       name,
		PublicKey:  pub,
		PrivateKey: priv,
		Address:    addr,
		CreatedAt:  state.NowRFC3339(),
		Revoked:    false,
	}
	st.NextClientIP = octet + 1
	if err := s.SaveServer(st); err != nil {
		return nil, err
	}
	if err := s.SavePeer(p); err != nil {
		return nil, err
	}
	prof := buildProfile(st, p)
	raw, err := json.MarshalIndent(prof, "", "  ")
	if err != nil {
		return nil, err
	}
	if err := s.WritePeerProfileJSON(p.ID, raw); err != nil {
		return nil, err
	}
	if err := wg.Sync(s, st, mustAllPeers(s)); err != nil {
		fmt.Fprintf(os.Stderr, "warning: sync wg config: %v\n", err)
	}
	return p, nil
}

func buildProfile(st *state.ServerState, p *state.PeerRecord) *profile.NbVpnProfile {
	ep := st.Endpoint
	if ep == "" {
		ep = fmt.Sprintf("0.0.0.0:%d", st.ListenPort)
	}
	return &profile.NbVpnProfile{
		V:    1,
		Name: p.Name,
		Client: profile.ClientSection{
			PrivateKey: p.PrivateKey,
			Address:    []string{p.Address},
			DNS:        append([]string{}, st.DNS...),
			MTU:        profile.DefaultMTU,
		},
		Server: profile.ServerSection{
			PublicKey:           st.PublicKey,
			Endpoint:            ep,
			AllowedIPs:          append([]string{}, st.AllowedIPs...),
			PersistentKeepalive: profile.DefaultKA,
			PresharedKey:        nil,
		},
	}
}

type showMode int

const (
	showModeAll showMode = iota
	showModeURI
	showModeQR
	showModeFile
	showModeConf
)

func cmdShow(args []string) error {
	mode := showModeAll
	peerRef := ""
	for _, a := range args {
		switch a {
		case "--all":
			mode = showModeAll
		case "--uri":
			mode = showModeURI
		case "--qr":
			mode = showModeQR
		case "--file":
			mode = showModeFile
		case "--conf":
			mode = showModeConf
		case "-h", "--help":
			fmt.Println("Usage: nbvpn show [--uri|--qr|--file|--conf|--all] [peer-id|name]")
			return nil
		default:
			if strings.HasPrefix(a, "-") {
				return fmt.Errorf("unknown flag %s", a)
			}
			peerRef = a
		}
	}
	s := store()
	st, err := s.LoadServer()
	if err != nil {
		return err
	}
	var p *state.PeerRecord
	if peerRef == "" {
		active, err := s.ActivePeers()
		if err != nil {
			return err
		}
		if len(active) == 0 {
			return fmt.Errorf("no active peers; run: nbvpn peer add")
		}
		p = active[0]
	} else {
		p, err = s.FindPeer(peerRef)
		if err != nil {
			return err
		}
		if p.Revoked {
			return fmt.Errorf("peer %s is revoked", peerRef)
		}
	}
	return showPeer(s, st, p, mode)
}

func showPeer(s *state.Store, st *state.ServerState, p *state.PeerRecord, mode showMode) error {
	prof := buildProfile(st, p)
	if err := prof.Validate(); err != nil {
		return err
	}
	uri, err := profile.EncodeURI(prof)
	if err != nil {
		return err
	}
	raw, err := json.MarshalIndent(prof, "", "  ")
	if err != nil {
		return err
	}
	path := s.PeerProfilePath(p.ID)
	if err := s.WritePeerProfileJSON(p.ID, raw); err != nil {
		return err
	}
	confBody, err := profile.ToWireGuardConf(prof)
	if err != nil {
		return err
	}
	confPath := s.PeerWGConfPath(p.ID)
	if err := s.WritePeerWGConf(p.ID, confBody); err != nil {
		return err
	}
	pngPath := s.PeerQRPath(p.ID)
	var pngWriteErr error
	var pngAnnounce qr.AfterWriteResult
	if err := qr.WritePNG(uri, pngPath); err != nil {
		pngWriteErr = err
		pngPath = ""
		fmt.Fprintf(os.Stderr, "ERROR: could not write QR PNG to %s: %v\n", s.PeerQRPath(p.ID), err)
		fmt.Fprintln(os.Stderr, "ERROR: 无法写入二维码 PNG（路径不可写或磁盘错误）。请检查权限 / NBVPN_DATA_DIR。")
	} else if mode == showModeAll || mode == showModeQR {
		// Interactive modes: copy to Desktop + reveal. Machine modes (--uri/--file) stay quiet.
		pngAnnounce = qr.AfterWrite(pngPath)
	}

	if mode == showModeAll {
		fmt.Println(secretWarning)
		fmt.Println()
		fmt.Printf("peer name: %s\n", p.Name)
		fmt.Printf("peer id:   %s  (numeric id for CLI/files only — NOT the QR payload)\n", p.ID)
		if st.Endpoint == "" {
			fmt.Fprintln(os.Stderr, "warning: endpoint not set — clients cannot reach this node until you run: nbvpn config set endpoint <host[:port]>")
		}
		fmt.Println()
		fmt.Println("--- URI ---")
		fmt.Println(uri)
		fmt.Println()
		fmt.Println("--- file ---")
		fmt.Println(path)
		fmt.Println()
		fmt.Println("--- WireGuard .conf (official WireGuard / wg-quick) ---")
		fmt.Println(confPath)
		if pngPath != "" {
			fmt.Println()
			fmt.Println("--- QR PNG (preferred on Windows / narrow consoles) ---")
			fmt.Println("(filename uses peer id; PNG pixels encode the full URI above)")
			qr.PrintAfterWrite(os.Stdout, pngPath, pngAnnounce)
		} else if pngWriteErr != nil {
			fmt.Println()
			fmt.Println("--- QR PNG FAILED ---")
			fmt.Printf("error: %v\n", pngWriteErr)
		}
		if wantTerminalQR(false) {
			fmt.Println()
			fmt.Println("--- QR (scan with NetBridge client) ---")
			fmt.Println("二维码内容 = 完整 nbvpn: URI（与上方 URI 相同，以 nbvpn:1? 开头）")
			fmt.Println("QR payload = full nbvpn: URI (same as URI section; starts with nbvpn:1?)")
			fmt.Printf("payload prefix: %s…\n", qrPayloadPrefix(uri))
			printTerminalQR(uri)
		} else if runtime.GOOS == "windows" {
			fmt.Println()
			fmt.Println(qr.WindowsDefaultHint)
		}
		return nil
	}
	// Machine-friendly modes: secret warning on stderr so stdout stays pipeable.
	fmt.Fprintln(os.Stderr, secretWarning)
	if st.Endpoint == "" {
		fmt.Fprintln(os.Stderr, "warning: endpoint not set — run: nbvpn config set endpoint <host[:port]>")
	}
	switch mode {
	case showModeURI:
		fmt.Println(uri)
	case showModeFile:
		fmt.Println(path)
		fmt.Println(confPath)
		if pngPath != "" {
			fmt.Println(pngPath)
			fmt.Fprintln(os.Stderr, "(PNG encodes full nbvpn: URI, not the numeric peer id in the filename)")
		} else if pngWriteErr != nil {
			return fmt.Errorf("QR PNG write failed: %w", pngWriteErr)
		}
	case showModeConf:
		fmt.Println(confPath)
		fmt.Fprintln(os.Stderr, "(wg-quick / official WireGuard client config; contains private key)")
	case showModeQR:
		fmt.Fprintln(os.Stderr, "二维码内容 = 完整 nbvpn: URI（以 nbvpn:1? 开头；不是 peer 数字 id）")
		fmt.Fprintf(os.Stderr, "payload prefix: %s…\n", qrPayloadPrefix(uri))
		if pngPath != "" {
			fmt.Println(pngPath)
			qr.PrintAfterWrite(os.Stderr, pngPath, pngAnnounce)
		} else if pngWriteErr != nil {
			return fmt.Errorf("QR PNG write failed: %w", pngWriteErr)
		}
		printTerminalQR(uri)
	}
	return nil
}

// wantTerminalQR: on Windows, terminal block QR is opt-in (--qr or NBVPN_TERMINAL_QR=1).
func wantTerminalQR(forceQRMode bool) bool {
	if forceQRMode {
		return true
	}
	if runtime.GOOS == "windows" {
		return os.Getenv("NBVPN_TERMINAL_QR") == "1"
	}
	return true
}

func printTerminalQR(uri string) {
	q, err := qr.RenderTerminal(uri)
	if err != nil {
		if qr.IsTooWide(err) {
			fmt.Fprintf(os.Stderr, "warning: %v\n", err)
			fmt.Fprintln(os.Stderr, "Terminal QR skipped (too dense for ~48–56 columns). Use the PNG path above / --file.")
			fmt.Println(qr.FallbackHint)
			return
		}
		fmt.Fprintf(os.Stderr, "warning: terminal QR: %v\n", err)
		fmt.Println(qr.FallbackHint)
		return
	}
	fmt.Print(q)
	fmt.Println(qr.FallbackHint)
}

func qrPayloadPrefix(uri string) string {
	const n = 24
	if len(uri) <= n {
		return uri
	}
	return uri[:n]
}

func cmdConfig(args []string) error {
	if len(args) >= 1 && args[0] == "set" {
		return cmdConfigSet(args[1:])
	}
	s := store()
	st, err := s.LoadServer()
	if err != nil {
		return err
	}
	active, _ := s.ActivePeers()
	all, _ := s.ListPeers()
	fmt.Println("nbvpn node summary")
	fmt.Printf("  dataDir:     %s\n", s.DataDir)
	fmt.Printf("  interface:   %s\n", st.Interface)
	fmt.Printf("  listenPort:  %d\n", st.ListenPort)
	fmt.Printf("  address:     %s\n", st.Address)
	fmt.Printf("  publicKey:   %s\n", st.PublicKey)
	fmt.Printf("  endpoint:    %s\n", emptyDash(st.Endpoint))
	fmt.Printf("  dns:         %s\n", strings.Join(st.DNS, ", "))
	fmt.Printf("  allowedIPs:  %s\n", strings.Join(st.AllowedIPs, ", "))
	fmt.Printf("  peers:       %d active / %d total\n", len(active), len(all))
	fmt.Printf("  installedAt: %s\n", st.InstalledAt)
	fmt.Println("  (server private key is not shown)")
	return nil
}

func emptyDash(s string) string {
	if s == "" {
		return "(not set — run: nbvpn config set endpoint <host[:port]>)"
	}
	return s
}

func cmdConfigSet(args []string) error {
	if len(args) < 2 || args[0] != "endpoint" {
		return fmt.Errorf("usage: nbvpn config set endpoint <host[:port]>")
	}
	raw := args[1]
	s := store()
	st, err := s.LoadServer()
	if err != nil {
		return err
	}
	ep, err := endpoint.NormalizeEndpoint(raw, st.ListenPort)
	if err != nil {
		return err
	}
	st.Endpoint = ep
	if err := s.SaveServer(st); err != nil {
		return err
	}
	// refresh peer profile JSON files with new endpoint
	peers, err := s.ListPeers()
	if err != nil {
		return err
	}
	for _, p := range peers {
		if p.Revoked {
			continue
		}
		prof := buildProfile(st, p)
		raw, err := json.MarshalIndent(prof, "", "  ")
		if err != nil {
			return err
		}
		if err := s.WritePeerProfileJSON(p.ID, raw); err != nil {
			return err
		}
		uri, err := profile.EncodeURI(prof)
		if err != nil {
			return err
		}
		if err := qr.WritePNG(uri, s.PeerQRPath(p.ID)); err != nil {
			fmt.Fprintf(os.Stderr, "warning: QR PNG for %s: %v\n", p.ID, err)
		}
	}
	fmt.Printf("endpoint set to %s\n", ep)
	fmt.Println("Re-run nbvpn show to export updated profiles.")
	return nil
}

func cmdStatus(args []string) error {
	_ = args
	s := store()
	st, err := s.LoadServer()
	if err != nil {
		// still print capabilities
		fmt.Print(wg.StatusText(nil))
		return err
	}
	fmt.Print(wg.StatusText(st))
	return nil
}

func cmdStart() error {
	if _, err := store().LoadServer(); err != nil {
		return err
	}
	dry, msg, err := wg.Start()
	if err != nil {
		return err
	}
	if dry {
		fmt.Println(msg)
	} else {
		fmt.Println(msg)
	}
	return nil
}

func cmdStop() error {
	dry, msg, err := wg.Stop()
	if err != nil {
		return err
	}
	_ = dry
	fmt.Println(msg)
	return nil
}

func cmdRestart() error {
	if _, err := store().LoadServer(); err != nil {
		return err
	}
	dry, msg, err := wg.Restart()
	if err != nil {
		return err
	}
	_ = dry
	fmt.Println(msg)
	return nil
}

func cmdPeer(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: nbvpn peer <add|list|revoke> ...")
	}
	switch args[0] {
	case "add":
		name := ""
		if len(args) > 1 {
			name = args[1]
		}
		return cmdPeerAdd(name)
	case "list":
		return cmdPeerList()
	case "revoke":
		if len(args) < 2 {
			return fmt.Errorf("usage: nbvpn peer revoke <id|name>")
		}
		return cmdPeerRevoke(args[1])
	default:
		return fmt.Errorf("unknown peer subcommand %q", args[0])
	}
}

func cmdPeerAdd(name string) error {
	s := store()
	st, err := s.LoadServer()
	if err != nil {
		return err
	}
	p, err := addPeer(s, st, name)
	if err != nil {
		return err
	}
	fmt.Printf("added peer %s (%s)\n\n", p.Name, p.ID)
	return showPeer(s, st, p, showModeAll)
}

func cmdPeerList() error {
	s := store()
	st, err := s.LoadServer()
	if err != nil {
		return err
	}
	peers, err := s.ListPeers()
	if err != nil {
		return err
	}
	if len(peers) == 0 {
		fmt.Println("(no peers — run: nbvpn peer add)")
		return nil
	}
	fmt.Printf("%-16s %-20s %-18s %-10s %s\n", "ID", "NAME", "ADDRESS", "STATUS", "CREATED")
	active := 0
	for _, p := range peers {
		status := "active"
		if p.Revoked {
			status = "revoked"
		} else {
			active++
		}
		created := p.CreatedAt
		if len(created) > 10 {
			created = created[:10]
		}
		fmt.Printf("%-16s %-20s %-18s %-10s %s\n", p.ID, p.Name, p.Address, status, created)
	}
	fmt.Printf("\n%d active / %d total", active, len(peers))
	if st.Endpoint == "" {
		fmt.Print("  |  endpoint NOT SET — nbvpn config set endpoint <host[:port]>")
	} else {
		fmt.Printf("  |  endpoint %s", st.Endpoint)
	}
	fmt.Println()
	fmt.Println("Tip: nbvpn show <name|id>   # re-export URI/QR/file for one peer")
	return nil
}

func validatePeerName(name string) error {
	if len(name) > 64 {
		return fmt.Errorf("peer name too long (max 64)")
	}
	if strings.ContainsAny(name, "/\\\n\r\t") {
		return fmt.Errorf("peer name must not contain path separators or control characters")
	}
	return nil
}

func findActivePeerByName(s *state.Store, name string) *state.PeerRecord {
	peers, err := s.ActivePeers()
	if err != nil {
		return nil
	}
	for _, p := range peers {
		if p.Name == name {
			return p
		}
	}
	return nil
}

func cmdPeerRevoke(idOrName string) error {
	s := store()
	st, err := s.LoadServer()
	if err != nil {
		return err
	}
	p, err := s.FindPeer(idOrName)
	if err != nil {
		return err
	}
	if p.Revoked {
		fmt.Printf("peer %s already revoked\n", p.Name)
		return nil
	}
	p.Revoked = true
	if err := s.SavePeer(p); err != nil {
		return err
	}
	// remove exportable profile + QR PNG so old file paths are gone
	_ = os.Remove(s.PeerProfilePath(p.ID))
	_ = os.Remove(s.PeerWGConfPath(p.ID))
	_ = os.Remove(s.PeerQRPath(p.ID))
	if err := wg.Sync(s, st, mustAllPeers(s)); err != nil {
		fmt.Fprintf(os.Stderr, "warning: sync wg config: %v\n", err)
	}
	fmt.Printf("revoked peer %s (%s); old URI/QR/file can no longer connect\n", p.Name, p.ID)
	return nil
}

func cmdUninstall(args []string) error {
	yes := false
	for _, a := range args {
		if a == "--yes" || a == "-y" {
			yes = true
		}
	}
	s := store()
	fmt.Println("This will stop the VPN service and delete nbvpn data under:")
	fmt.Println(" ", s.DataDir)
	fmt.Println("WireGuard system config /etc/wireguard/nbvpn.conf will also be removed if present.")
	if !yes {
		fmt.Print("Type 'yes' to confirm: ")
		var line string
		_, _ = fmt.Scanln(&line)
		if strings.TrimSpace(line) != "yes" {
			fmt.Println("aborted")
			return nil
		}
	}
	_, _, _ = wg.Stop()
	wg.RemoveSystemConf()
	if err := s.RemoveAll(); err != nil {
		return err
	}
	fmt.Println("uninstalled")
	return nil
}
