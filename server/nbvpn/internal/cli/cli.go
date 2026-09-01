package cli

import (
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
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
	case "obfs":
		err = cmdObfs(rest)
	case "obfs2":
		err = cmdObfs2(rest)
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
  install [--split-tunnel]        安装/配置节点、首个 peer、启用服务
                                  （或 NBVPN_SPLIT_TUNNEL=1：客户端仅路由 VPN 网段）
  show [--uri|--qr|--file|--conf|--all] [--qr-size N]
                                  显示客户端连接信息（默认 --all；终端字符二维码）
  status                          服务 / 隧道状态
  start | stop | restart          管理 WireGuard 服务
  peer add [name]                 新增客户端 peer
  peer list                       列出 peer
  peer revoke <id|name>           吊销 peer（保留记录，立即失效凭证）
  peer delete <id|name> [--yes]   永久删除 peer（从列表移除）
  obfs install [--domain <d>] [--port <443>]
                                  部署 wstunnel 混淆层（第三方方案）
  obfs2 install --domain <d> --cert <pem> --key <pem> [--port 443]
                                  部署自研传输层（WireGuard over 伪装 HTTPS）
  obfs2 serve | client            自研传输层服务端/桌面客户端模式
  config set endpoint <host[:port]>
                                  设置对外 endpoint（主地址，通常 IPv4）
  config set endpoint-v6 <[ipv6]|host[:port]>
                                  设置 IPv6 endpoint（写入 profile 可选字段）
  config set ipv6 on|off          标记 IPv6 启用状态（客户端连接时优先用 endpoint-v6）
  uninstall [--yes] [--keep-data] 完全卸载（默认删除全部 nbvpn 产物；--keep-data 保留数据目录）
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
  install [--split-tunnel]        Install/configure node, first peer, enable service
                                  (or NBVPN_SPLIT_TUNNEL=1: client routes VPN subnet only)
  show [--uri|--qr|--file|--conf|--all] [--qr-size N]
                                  Show connection info (default --all; terminal QR)
  config                          Show node summary (no server private key)
  config set endpoint <host[:port]>
                                  Set primary public endpoint used in client profiles
  config set endpoint-v6 <[ipv6]|host[:port]>
                                  Set optional IPv6 endpoint (written into profiles)
  config set ipv6 on|off          Mark IPv6 enabled (clients prefer endpoint-v6 when on)
  status                          Service / tunnel status
  start | stop | restart          Manage WireGuard service
  peer add [name]                 Add a client peer and show its URI/QR/file
  peer list                       List peers
  peer revoke <id|name>           Revoke a peer (disable creds; keep audit record)
  peer delete <id|name> [--yes]   Permanently delete a peer (remove from list)
  uninstall [--yes] [--keep-data] Full uninstall (removes all nbvpn artifacts; --keep-data keeps profiles)
  version                         Print version
  help                            Show this help

Environment:
  NBVPN_DATA_DIR        Override state directory
                        (Linux default /var/lib/nbvpn;
                         Windows default %ProgramData%\nbvpn;
                         fallback if unwritable)
  NBVPN_SPLIT_TUNNEL=1  New installs: client AllowedIPs = VPN subnet only (not 0.0.0.0/0)
  NO_COLOR / NBVPN_FORCE_ANSI  Disable / force ANSI color in terminal QR
  COLUMNS            Hint terminal width for QR sizing (else TTY probe)
  NBVPN_NO_TERMINAL_QR=1  Skip terminal QR (optional PNG / --uri only)

Firewall / endpoint:
  Clients need UDP listen port open on host firewall AND cloud security group
  (default 51820), including IPv6 if using endpoint-v6. See server/install/FIREWALL.md
  If public IP detect fails:  nbvpn config set endpoint <host[:port]>
  Dual-stack / second IP: set primary with endpoint; optional IPv6 with endpoint-v6 + ipv6 on
  (second IPv4: switch primary via config set endpoint — WireGuard uses one Endpoint at a time)

Dry-run:
  On macOS, hosts without wg-quick, or Windows without WireGuard for Windows,
  install still generates keys and profiles (data dir + PNG/JSON/conf);
  start/stop/status report dry-run. Install WireGuard before a real tunnel.

Pipe tip:
  nbvpn show --uri   # URI on stdout; secret warning on stderr
  nbvpn show --qr    # terminal half-block QR (+ optional PNG path tip)
  nbvpn show --qr-size 80   # cap terminal QR module width (columns)

`)
}

func store() *state.Store {
	return state.New(state.ResolveDataDir())
}

func cmdInstall(args []string) error {
	splitTunnel := wg.SplitTunnelFromEnv()
	for _, a := range args {
		if a == "--split-tunnel" {
			splitTunnel = true
		}
	}
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
			ep, _ = endpoint.NormalizeEndpoint(ip, state.DefaultListenPort)
		}
		epV6 := ""
		if ip6 := endpoint.DetectPublicIPv6(); ip6 != "" {
			epV6, _ = endpoint.NormalizeEndpoint(ip6, state.DefaultListenPort)
		}
		st = &state.ServerState{
			Version:      1,
			Interface:    state.InterfaceName,
			ListenPort:   state.DefaultListenPort,
			PrivateKey:   priv,
			PublicKey:    pub,
			Address:      state.DefaultServerAddr,
			Endpoint:     ep,
			EndpointV6:   epV6,
			IPv6Enabled:  false, // operator enables via: nbvpn config set ipv6 on
			DNS:          []string{profile.DefaultDNS1, profile.DefaultDNS2},
			AllowedIPs:   wg.DefaultClientAllowedIPs(state.DefaultServerAddr, splitTunnel),
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
	fmt.Printf("client allowedIPs: %s\n", strings.Join(st.AllowedIPs, ", "))
	if splitTunnel {
		fmt.Println("split-tunnel: client profiles route VPN subnet only (not public internet via VPN)")
		fmt.Println("  For full-tunnel clients: reinstall without --split-tunnel / NBVPN_SPLIT_TUNNEL, or edit server.json allowedIPs")
	}
	if st.Endpoint == "" {
		fmt.Println()
		fmt.Println("Could not detect public IP for endpoint.")
		fmt.Println("Set it with:  nbvpn config set endpoint <your-public-ip-or-dns>")
	} else {
		fmt.Printf("endpoint: %s\n", st.Endpoint)
	}
	if st.EndpointV6 != "" {
		fmt.Printf("endpointV6: %s (detected; ipv6Enabled=off — enable with: nbvpn config set ipv6 on)\n", st.EndpointV6)
	} else {
		fmt.Println("endpointV6: (not detected — optional: nbvpn config set endpoint-v6 <[ipv6]>)")
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
	fmt.Println("  1. nbvpn show          # URI + terminal QR + files (secrets!)")
	fmt.Println("     Optional: nbvpn show --qr-size 80   # fit narrow SSH; PNG is supplemental")
	fmt.Println("  2. Download a client from your NetBridge store page")
	fmt.Println("  3. Import the URI / scan terminal QR / .nbvpn.json, or WireGuard .conf (nbvpn show --conf)")
	fmt.Println()

	// show first active peer
	if len(peers) > 0 {
		return showPeer(s, st, peers[0], showModeAll, 0)
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
	srv := profile.ServerSection{
		PublicKey:           st.PublicKey,
		Endpoint:            ep,
		AllowedIPs:          append([]string{}, st.AllowedIPs...),
		PersistentKeepalive: profile.DefaultKA,
		PresharedKey:        nil,
	}
	if v6 := strings.TrimSpace(st.EndpointV6); v6 != "" {
		srv.EndpointV6 = v6
		srv.IPv6Enabled = st.IPv6Enabled
	}
	prof := &profile.NbVpnProfile{
		V:    1,
		Name: p.Name,
		Client: profile.ClientSection{
			PrivateKey: p.PrivateKey,
			Address:    []string{p.Address},
			DNS:        append([]string{}, st.DNS...),
			MTU:        profile.DefaultMTU,
		},
		Server: srv,
	}
	prof.Obfs = loadObfsForProfile()
	return prof
}

// loadObfsForProfile reads obfs2.json (state dir resolved via NBVPN_DATA_DIR)
// and, when enabled, attaches the transport parameters to client profiles.
func loadObfsForProfile() *profile.ObfsSection {
	dir := state.ResolveDataDir()
	b, err := os.ReadFile(filepath.Join(dir, "obfs2.json"))
	if err != nil {
		return nil
	}
	var ob obfs2State
	if err := json.Unmarshal(b, &ob); err != nil || !ob.Enabled {
		return nil
	}
	ports := ob.entryPorts()
	entries := make([]string, 0, len(ports))
	for _, p := range ports {
		entries = append(entries, fmt.Sprintf("%s:%d", ob.Domain, p))
	}
	ch := ob.Channels
	if ch <= 0 {
		ch = 4
	}
	// Self-signed certs (issuer == subject) cannot be verified against the
	// system trust store — clients must skip verification.
	insecure := ob.Insecure || certIsSelfSigned(ob.CertFile)
	return &profile.ObfsSection{
		Type:     "obfs2",
		PSK:      ob.PSKHex,
		Entries:  entries,
		LocalUDP: ob.ClientPort,
		Insecure: insecure,
		Channels: ch,
	}
}

// certIsSelfSigned reports whether the PEM cert at path (if readable) is
// its own issuer — the common case for self-hosted obfs2 deployments.
func certIsSelfSigned(path string) bool {
	if path == "" {
		return false
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	block, _ := pem.Decode(b)
	if block == nil {
		return false
	}
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return false
	}
	return cert.RawIssuer != nil && string(cert.RawIssuer) == string(cert.RawSubject)
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
	qrSize := 0 // 0 = auto (COLUMNS / TTY / default)
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "--all":
			mode = showModeAll
		case a == "--uri":
			mode = showModeURI
		case a == "--qr":
			mode = showModeQR
		case a == "--file":
			mode = showModeFile
		case a == "--conf":
			mode = showModeConf
		case a == "--qr-size":
			if i+1 >= len(args) {
				return fmt.Errorf("--qr-size requires an integer (terminal columns)")
			}
			i++
			n, err := strconv.Atoi(args[i])
			if err != nil || n <= 0 {
				return fmt.Errorf("invalid --qr-size %q", args[i])
			}
			qrSize = qr.ClampMaxCols(n)
		case strings.HasPrefix(a, "--qr-size="):
			n, err := strconv.Atoi(strings.TrimPrefix(a, "--qr-size="))
			if err != nil || n <= 0 {
				return fmt.Errorf("invalid --qr-size %q", a)
			}
			qrSize = qr.ClampMaxCols(n)
		case a == "-h", a == "--help":
			fmt.Println("Usage: nbvpn show [--uri|--qr|--file|--conf|--all] [--qr-size N] [peer-id|name]")
			fmt.Println("  Terminal half-block QR is always printed for --all / --qr (unless NBVPN_NO_TERMINAL_QR=1).")
			fmt.Println("  Optional PNG beside the peer profile is supplemental, not a substitute.")
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
	return showPeer(s, st, p, mode, qrSize)
}

func showPeer(s *state.Store, st *state.ServerState, p *state.PeerRecord, mode showMode, qrSize int) error {
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
		// Interactive modes: optional Desktop copies; no auto-open image viewer.
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
		if prof.Obfs != nil && prof.Obfs.Type == "obfs2" {
			fmt.Printf("obfs2:     enabled (%d entries, local UDP %d) — profile routes through the disguised transport\n",
				len(prof.Obfs.Entries), prof.Obfs.LocalUDP)
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
		fmt.Println()
		fmt.Println("--- QR (scan with NetBridge client; terminal half-block) ---")
		fmt.Println("二维码内容 = 完整 nbvpn: URI（与上方 URI 相同，以 nbvpn:1? 开头）")
		fmt.Println("QR payload = full nbvpn: URI (same as URI section; starts with nbvpn:1?)")
		fmt.Printf("payload prefix: %s…\n", qrPayloadPrefix(uri))
		printTerminalQR(uri, qrSize)
		if pngPath != "" {
			fmt.Println()
			qr.PrintAfterWrite(os.Stdout, pngPath, pngAnnounce)
		} else if pngWriteErr != nil {
			fmt.Println()
			fmt.Printf("Optional QR PNG failed: %v\n", pngWriteErr)
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
		printTerminalQR(uri, qrSize)
		if pngPath != "" {
			qr.PrintAfterWrite(os.Stderr, pngPath, pngAnnounce)
		} else if pngWriteErr != nil {
			fmt.Fprintf(os.Stderr, "Optional QR PNG failed: %v\n", pngWriteErr)
		}
	}
	return nil
}

// wantTerminalQR: always true unless operator opts out (NBVPN_NO_TERMINAL_QR=1).
func wantTerminalQR() bool {
	v := strings.TrimSpace(os.Getenv("NBVPN_NO_TERMINAL_QR"))
	return v != "1" && !strings.EqualFold(v, "true")
}

func printTerminalQR(uri string, qrSize int) {
	if !wantTerminalQR() {
		fmt.Fprintln(os.Stderr, "Terminal QR skipped (NBVPN_NO_TERMINAL_QR=1). Use --uri / optional PNG / --file.")
		return
	}
	maxCols := qr.EffectiveMaxCols(qrSize)
	q, err := qr.RenderTerminalOpts(uri, qr.RenderOptions{UseANSI: qr.ColorEnabled(), MaxCols: maxCols})
	if err != nil {
		if qr.IsTooWide(err) {
			fmt.Fprintf(os.Stderr, "warning: %v\n", err)
			fmt.Fprintf(os.Stderr, "Terminal QR skipped (needs ≤%d cols; try wider SSH or --qr-size). Optional PNG / --uri still available.\n", maxCols)
			fmt.Println(qr.FallbackHint)
			return
		}
		fmt.Fprintf(os.Stderr, "warning: terminal QR: %v\n", err)
		fmt.Println(qr.FallbackHint)
		return
	}
	fmt.Printf("(terminal QR width budget: %d cols; COLUMNS/TTY/--qr-size)\n", maxCols)
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
	fmt.Printf("  endpointV6:  %s\n", emptyDashV6(st.EndpointV6))
	fmt.Printf("  ipv6Enabled: %s\n", boolOnOff(st.IPv6Enabled))
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

func emptyDashV6(s string) string {
	if s == "" {
		return "(not set — run: nbvpn config set endpoint-v6 <[ipv6]|host[:port]>)"
	}
	return s
}

func boolOnOff(v bool) string {
	if v {
		return "on"
	}
	return "off"
}

func cmdConfigSet(args []string) error {
	if len(args) < 2 {
		return fmt.Errorf("usage: nbvpn config set endpoint|endpoint-v6|ipv6 <value>")
	}
	key := args[0]
	raw := args[1]
	s := store()
	st, err := s.LoadServer()
	if err != nil {
		return err
	}
	switch key {
	case "endpoint":
		ep, err := endpoint.NormalizeEndpoint(raw, st.ListenPort)
		if err != nil {
			return err
		}
		st.Endpoint = ep
		if err := s.SaveServer(st); err != nil {
			return err
		}
		if err := refreshActivePeerProfiles(s, st); err != nil {
			return err
		}
		fmt.Printf("endpoint set to %s\n", ep)
	case "endpoint-v6":
		ep, err := endpoint.NormalizeEndpoint(raw, st.ListenPort)
		if err != nil {
			return err
		}
		st.EndpointV6 = ep
		st.IPv6Enabled = true
		if err := s.SaveServer(st); err != nil {
			return err
		}
		if err := refreshActivePeerProfiles(s, st); err != nil {
			return err
		}
		fmt.Printf("endpoint-v6 set to %s (ipv6Enabled=on)\n", ep)
	case "ipv6":
		on, err := parseOnOff(raw)
		if err != nil {
			return err
		}
		if on && strings.TrimSpace(st.EndpointV6) == "" {
			return fmt.Errorf("cannot enable ipv6: endpoint-v6 is not set; run: nbvpn config set endpoint-v6 <[ipv6]|host[:port]>")
		}
		st.IPv6Enabled = on
		if err := s.SaveServer(st); err != nil {
			return err
		}
		if err := refreshActivePeerProfiles(s, st); err != nil {
			return err
		}
		fmt.Printf("ipv6Enabled set to %s\n", boolOnOff(on))
	default:
		return fmt.Errorf("usage: nbvpn config set endpoint|endpoint-v6|ipv6 <value>")
	}
	fmt.Println("Re-run nbvpn show to export updated profiles.")
	return nil
}

func parseOnOff(raw string) (bool, error) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "on", "1", "true", "yes", "enable", "enabled":
		return true, nil
	case "off", "0", "false", "no", "disable", "disabled":
		return false, nil
	default:
		return false, fmt.Errorf("usage: nbvpn config set ipv6 on|off")
	}
}

func refreshActivePeerProfiles(s *state.Store, st *state.ServerState) error {
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
		conf, err := profile.ToWireGuardConf(prof)
		if err != nil {
			return err
		}
		if err := s.WritePeerWGConf(p.ID, conf); err != nil {
			return err
		}
	}
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
		return fmt.Errorf("usage: nbvpn peer <add|list|revoke|delete> ...")
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
	case "delete":
		if len(args) < 2 {
			return fmt.Errorf("usage: nbvpn peer delete <id|name> [--yes]")
		}
		yes := false
		idOrName := args[1]
		for _, a := range args[2:] {
			if a == "--yes" || a == "-y" {
				yes = true
			}
		}
		return cmdPeerDelete(idOrName, yes)
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
	return showPeer(s, st, p, showModeAll, 0)
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
	if st.EndpointV6 != "" {
		fmt.Printf("  |  endpointV6 %s (ipv6 %s)", st.EndpointV6, boolOnOff(st.IPv6Enabled))
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

func cmdPeerDelete(idOrName string, yes bool) error {
	s := store()
	st, err := s.LoadServer()
	if err != nil {
		return err
	}
	p, err := s.FindPeer(idOrName)
	if err != nil {
		return err
	}
	fmt.Printf("This will permanently delete peer %s (%s) and all export files.\n", p.Name, p.ID)
	fmt.Println("The peer will be removed from WireGuard. Its VPN IP will NOT be reused.")
	if !yes {
		fmt.Print("Type 'yes' to confirm: ")
		var line string
		_, _ = fmt.Scanln(&line)
		if strings.TrimSpace(line) != "yes" {
			fmt.Println("aborted")
			return nil
		}
	}
	if err := s.DeletePeer(p.ID); err != nil {
		return err
	}
	if err := wg.Sync(s, st, mustAllPeers(s)); err != nil {
		fmt.Fprintf(os.Stderr, "warning: sync wg config: %v\n", err)
	}
	fmt.Printf("deleted peer %s (%s)\n", p.Name, p.ID)
	return nil
}

func cmdUninstall(args []string) error {
	yes := false
	keepData := false
	for _, a := range args {
		switch a {
		case "--yes", "-y":
			yes = true
		case "--keep-data":
			keepData = true
		case "-h", "--help":
			printUninstallHelp()
			return nil
		default:
			return fmt.Errorf("unknown uninstall flag %q (try: nbvpn uninstall --help)", a)
		}
	}
	s := store()
	targets := wg.ListUninstallTargets(s)

	fmt.Println("nbvpn 将执行完全卸载 / nbvpn full uninstall")
	fmt.Println()
	if keepData {
		fmt.Println("模式: --keep-data（保留数据目录，便于重装；仍停止服务并清理系统配置）")
		fmt.Println("Mode: --keep-data (preserve data dir for reinstall; still stops service and removes system config)")
	} else {
		fmt.Println("模式: 完全清理（默认；删除密钥、peer、配置与系统产物）")
		fmt.Println("Mode: full clean (default; deletes keys, peers, configs, and system artifacts)")
	}
	fmt.Println()
	fmt.Println("将处理以下 nbvpn 管理项 / Artifacts:")
	for _, t := range targets {
		if keepData && t.Kind == "data" {
			fmt.Printf("  (skip) %s — kept for reinstall\n", t.Path)
			continue
		}
		mark := " "
		if t.Present {
			mark = "*"
		}
		line := fmt.Sprintf("  %s %s", mark, t.Path)
		if t.Note != "" {
			line += " — " + t.Note
		}
		fmt.Println(line)
	}
	fmt.Println("  * = present on this host")
	fmt.Println()
	if !yes {
		fmt.Print("Type 'yes' to confirm / 输入 yes 确认: ")
		var line string
		_, _ = fmt.Scanln(&line)
		if strings.TrimSpace(line) != "yes" {
			fmt.Println("aborted / 已取消")
			return nil
		}
	}
	log, err := wg.Uninstall(s, wg.UninstallOpts{KeepData: keepData})
	for _, line := range log {
		fmt.Println(line)
	}
	if err != nil {
		return err
	}
	fmt.Println("uninstalled / 卸载完成")
	return nil
}

func printUninstallHelp() {
	fmt.Println(`Usage: nbvpn uninstall [--yes] [--keep-data]

完全卸载 nbvpn 服务端管理的所有产物（默认行为）。
Full uninstall of all nbvpn-managed artifacts (default).

  --yes, -y       Skip interactive confirmation
  --keep-data     Keep the data directory (keys/peers/profiles) for reinstall;
                  still stops the tunnel and removes system WireGuard config,
                  systemd unit enablement, sysctl drop-in, and iptables rules.

默认删除 / Removed by default (Linux):
  • wg-quick@nbvpn service (stop + disable)
  • /etc/wireguard/nbvpn.conf
  • /var/lib/nbvpn (or NBVPN_DATA_DIR) — unless --keep-data
  • /etc/sysctl.d/99-nbvpn-forward.conf (only if nbvpn-managed)
  • iptables FORWARD/NAT rules for the tunnel (best-effort, incl. duplicates)

Windows also removes:
  • WireGuardTunnel$nbvpn service
  • NetNat "nbvpnNat" and firewall rule from install.ps1 (best-effort)

Examples:
  sudo nbvpn uninstall              # preview + confirm
  sudo nbvpn uninstall --yes        # full clean uninstall
  sudo nbvpn uninstall --yes --keep-data   # reinstall later without re-keying`)
}
