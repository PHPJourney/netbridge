package cli

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/netbridge/nbvpn/internal/obfstransport"
	"github.com/netbridge/nbvpn/internal/state"
)

// obfs2State is persisted under the nbvpn data dir (obfs2.json).
type obfs2State struct {
	Version    int    `json:"v"`
	Enabled    bool   `json:"enabled"`
	PSKHex     string `json:"psk"`
	Domain     string `json:"domain"`
	Port       int    `json:"port"`
	// Ports is the multi-entry form: several listen ports on the same IP.
	Ports      []int  `json:"ports,omitempty"`
	CertFile   string `json:"certFile"`
	KeyFile    string `json:"keyFile"`
	WGPort     int    `json:"wgPort"`
	ClientPort int    `json:"clientPort"`
	Channels   int    `json:"channels,omitempty"`
	Insecure   bool   `json:"insecure,omitempty"`
	Installed  string `json:"installedAt,omitempty"`
}

// entryPorts returns the configured entry ports (Ports when set, else Port).
func (st *obfs2State) entryPorts() []int {
	if len(st.Ports) > 0 {
		return st.Ports
	}
	if st.Port > 0 {
		return []int{st.Port}
	}
	return []int{443}
}

func cmdObfs2(args []string) error {
	if len(args) == 0 {
		printObfs2Help(os.Stdout)
		return nil
	}
	dir, err := state.PreferWritableDataDir()
	if err != nil {
		return err
	}
	os.Setenv(state.EnvDataDir, dir)

	switch args[0] {
	case "install":
		return obfs2Install(dir, args[1:])
	case "serve":
		return obfs2Serve(dir)
	case "client":
		return obfs2Client(dir, args[1:])
	case "status":
		return obfs2Status(dir)
	case "client-config":
		return obfs2ClientConfig(dir)
	case "uninstall":
		return obfs2Uninstall(dir, args[1:])
	default:
		return fmt.Errorf("unknown obfs2 subcommand %q", args[0])
	}
}

func obfs2Load(dir string) (*obfs2State, error) {
	b, err := os.ReadFile(filepath.Join(dir, "obfs2.json"))
	if err != nil {
		return nil, fmt.Errorf("obfs2 not installed (run 'nbvpn obfs2 install'): %w", err)
	}
	st := &obfs2State{}
	if err := json.Unmarshal(b, st); err != nil {
		return nil, fmt.Errorf("parse obfs2.json: %w", err)
	}
	return st, nil
}

func obfs2Save(dir string, st *obfs2State) error {
	b, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "obfs2.json"), append(b, '\n'), 0o600)
}

func obfs2Install(dir string, args []string) error {
	domain := ""
	port := 443
	var ports []int
	certFile := ""
	keyFile := ""
	insecure := false
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--insecure":
			insecure = true
		case "--domain":
			if i+1 >= len(args) {
				return fmt.Errorf("--domain requires a value")
			}
			i++
			domain = args[i]
		case "--port":
			if i+1 >= len(args) {
				return fmt.Errorf("--port requires a value")
			}
			i++
			fmt.Sscanf(args[i], "%d", &port)
		case "--ports":
			if i+1 >= len(args) {
				return fmt.Errorf("--ports requires a value (comma-separated, e.g. 443,8443,2053)")
			}
			i++
			for _, part := range strings.Split(args[i], ",") {
				var p int
				if _, err := fmt.Sscanf(strings.TrimSpace(part), "%d", &p); err != nil {
					return fmt.Errorf("invalid --ports value %q", args[i])
				}
				ports = append(ports, p)
			}
		case "--cert":
			if i+1 >= len(args) {
				return fmt.Errorf("--cert requires a value")
			}
			i++
			certFile = args[i]
		case "--key":
			if i+1 >= len(args) {
				return fmt.Errorf("--key requires a value")
			}
			i++
			keyFile = args[i]
		default:
			return fmt.Errorf("unknown obfs2 install flag %q", args[i])
		}
	}
	if domain == "" {
		return fmt.Errorf("--domain is required (the TLS SNI / cert domain, e.g. vpn.example.com)")
	}
	if certFile == "" || keyFile == "" {
		return fmt.Errorf("--cert and --key are required (real CA-signed cert for %s; issue via acme.sh/certbot)", domain)
	}

	existing, err := os.ReadFile(filepath.Join(dir, "obfs2.json"))
	if err == nil && len(existing) > 0 {
		return fmt.Errorf("obfs2 already installed (status: 'nbvpn obfs2 status'; reinstall after uninstall)")
	}

	psk, err := obfstransport.GeneratePSK()
	if err != nil {
		return err
	}
	st := &obfs2State{
		Version:    1,
		Enabled:    true,
		PSKHex:     hex.EncodeToString(psk),
		Domain:     domain,
		Port:       port,
		Ports:      ports,
		CertFile:   certFile,
		KeyFile:    keyFile,
		WGPort:     51820,
		ClientPort: obfstransport.DefaultClientPort,
		Channels:   4,
		Insecure:   insecure,
		Installed:  time.Now().UTC().Format(time.RFC3339),
	}
	if err := obfs2Save(dir, st); err != nil {
		return err
	}

	fmt.Println("=== nbvpn obfs2 (self-developed transport) install complete ===")
	fmt.Printf("domain:   %s\n", domain)
	ep := st.entryPorts()
	fmt.Printf("entries:  %s (TLS, looks like HTTPS)\n", entryList(domain, ep))
	fmt.Printf("forward:  -> 127.0.0.1:%d (WireGuard)\n", st.WGPort)
	fmt.Println()
	fmt.Println("systemd 服务（服务端常驻）：")
	fmt.Printf(`cat > /etc/systemd/system/nbvpn-obfs2.service <<'EOF'
[Unit]
Description=NetBridge obfs2 transport server
After=network-online.target wg-quick@nbvpn.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/nbvpn obfs2 serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now nbvpn-obfs2
`)
	fmt.Println()
	fmt.Println("证书续期后重启服务：systemctl restart nbvpn-obfs2")
	fmt.Println()
	fmt.Println("客户端配置：nbvpn obfs2 client-config")
	return nil
}

func obfs2Serve(dir string) error {
	st, err := obfs2Load(dir)
	if err != nil {
		return err
	}
	psk, err := hex.DecodeString(st.PSKHex)
	if err != nil {
		return fmt.Errorf("decode PSK: %w", err)
	}
	eps := st.entryPorts()
	addrs := make([]string, 0, len(eps))
	for _, p := range eps {
		addrs = append(addrs, fmt.Sprintf(":%d", p))
	}
	server, err := obfstransport.NewServer(obfstransport.ServerOptions{
		ListenAddrs: addrs,
		CertFile:    st.CertFile,
		KeyFile:     st.KeyFile,
		PSK:         psk,
		WGTarget:    fmt.Sprintf("127.0.0.1:%d", st.WGPort),
	})
	if err != nil {
		return err
	}
	fmt.Printf("obfs2 server entries %s (domain %s) -> WireGuard %d\n", entryList("", eps), st.Domain, st.WGPort)

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sig
		_ = server.Stop()
	}()
	return server.Start()
}

func obfs2Client(dir string, args []string) error {
	st, err := obfs2Load(dir)
	if err != nil {
		return err
	}
	psk, err := hex.DecodeString(st.PSKHex)
	if err != nil {
		return fmt.Errorf("decode PSK: %w", err)
	}
	eps := st.entryPorts()
	serverAddrs := make([]string, 0, len(eps))
	for _, p := range eps {
		serverAddrs = append(serverAddrs, fmt.Sprintf("%s:%d", st.Domain, p))
	}
	localUDP := fmt.Sprintf("127.0.0.1:%d", st.ClientPort)
	insecure := false
	channels := 4
	var forwards []obfstransport.ForwardRule
	for _, a := range args {
		if a == "--insecure" {
			insecure = true
			continue
		}
		if len(a) > 10 && a[:10] == "--channels" {
			parts := strings.SplitN(a, "=", 2)
			if len(parts) == 2 {
				fmt.Sscanf(parts[1], "%d", &channels)
			}
			continue
		}
		if len(a) > 8 && a[:8] == "--local=" {
			localUDP = a[8:]
			continue
		}
		if len(a) > 9 && a[:9] == "--server=" {
			// explicit entry list overrides the state-derived pool
			serverAddrs = strings.Split(a[9:], ",")
			continue
		}
		// -L tcp://LOCAL:REMOTE  or  -L LOCAL:REMOTE (tcp shorthand)
		spec := a
		if len(a) > 3 && a[:3] == "-L " {
			spec = a[3:]
		} else if len(a) > 2 && a[:2] == "-L" {
			spec = a[2:]
		}
		spec = strings.TrimSpace(spec)
		if spec == "" {
			continue
		}
		if strings.HasPrefix(spec, "tcp://") {
			spec = strings.TrimPrefix(spec, "tcp://")
		} else if strings.Contains(spec, "://") {
			return fmt.Errorf("unsupported forward scheme in %q (v1 supports tcp:// only)", a)
		}
		parts := strings.SplitN(spec, ":", 2)
		if len(parts) != 2 {
			return fmt.Errorf("invalid forward spec %q (want tcp://LOCAL:REMOTE)", a)
		}
		forwards = append(forwards, obfstransport.ForwardRule{
			LocalAddr:  "127.0.0.1:" + parts[0],
			RemoteAddr: parts[1],
		})
	}
	client, err := obfstransport.NewClient(obfstransport.ClientOptions{
		ServerAddrs:        serverAddrs,
		LocalUDP:           localUDP,
		Forwards:           forwards,
		Channels:           channels,
		PSK:                psk,
		InsecureSkipVerify: insecure,
	})
	if err != nil {
		return err
	}
	fmt.Printf("obfs2 client: UDP %s (WireGuard Endpoint 请指向 %s)\n", localUDP, localUDP)
	fmt.Printf("entries: %s\n", strings.Join(serverAddrs, ", "))
	for _, fw := range forwards {
		fmt.Printf("  tcp forward: 127.0.0.1:%s -> %s\n", strings.TrimPrefix(fw.LocalAddr, "127.0.0.1:"), fw.RemoteAddr)
	}
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sig
		client.Stop()
	}()
	return client.Run()
}

func obfs2Status(dir string) error {
	st, err := obfs2Load(dir)
	if err != nil {
		return err
	}
	fmt.Printf("obfs2: enabled\n")
	fmt.Printf("entries:  %s\n", entryList(st.Domain, st.entryPorts()))
	fmt.Printf("cert:     %s / %s\n", st.CertFile, st.KeyFile)
	fmt.Printf("forward:  -> 127.0.0.1:%d\n", st.WGPort)
	fmt.Printf("clientPort: %d\n", st.ClientPort)
	fmt.Printf("installedAt: %s\n", st.Installed)
	return nil
}

func obfs2ClientConfig(dir string) error {
	st, err := obfs2Load(dir)
	if err != nil {
		return err
	}
	fmt.Printf(`=== 客户端接入配置（obfs2 自研传输层） ===

1) 桌面端（macOS/Linux）启动本地桥（自动重连）：

   nbvpn obfs2 client

2) WireGuard 配置修改：Endpoint = 127.0.0.1:%d（其余不变）。

3) Android/iOS：NetBridge 客户端将内嵌 obfs2 client（P4，进行中）。

PSK: %s
`, st.ClientPort, st.PSKHex)
	return nil
}

func obfs2Uninstall(dir string, args []string) error {
	_ = os.Remove(filepath.Join(dir, "obfs2.json"))
	fmt.Println("obfs2: state removed (also run: systemctl disable --now nbvpn-obfs2)")
	return nil
}

func printObfs2Help(w *os.File) {
	fmt.Fprint(w, `nbvpn obfs2 — 自研传输层（WireGuard over 伪装 HTTPS，抗 DPI）

用法:
  nbvpn obfs2 install --domain <d> --cert <pem> --key <pem> [--port 443] [--ports 443,8443,2053]
                          安装自研传输层（生成 PSK + state + systemd 指引；
                          --ports 在单 IP 上开多个入口端口，客户端随机轮换）
  nbvpn obfs2 serve       服务端常驻模式（多入口端口监听，systemd 跑这个）
  nbvpn obfs2 client [-L tcp://本地端口:远端地址]... [--channels=4] [--server=h:p,...]
                          客户端模式（UDP 桥 + TCP 端口转发，多通道 × 多入口随机，自动重连）
                          例：nbvpn obfs2 client -L tcp://33890:127.0.0.1:3389
  nbvpn obfs2 status      查看状态
  nbvpn obfs2 client-config  客户端接入配置
  nbvpn obfs2 uninstall   移除状态

说明:
  - TLS 1.3 + 真证书（--cert/--key，Let's Encrypt 签发），握手合法像普通 HTTPS
  - 认证先行（PSK + HMAC 挑战应答），未认证连接返回伪装 404 页面
  - WG 数据报帧层填充整形，对 WireGuard 透明
  - 多入口：单 IP 多端口，客户端随机选入口，单端口被封自动切换
  - 设计文档: docs/OBFS-TRANSPORT.md
`)
}

// entryList renders an entry list: with a domain, "domain:p1, domain:p2";
// without, ":p1, :p2".
func entryList(domain string, ports []int) string {
	parts := make([]string, 0, len(ports))
	for _, p := range ports {
		if domain != "" {
			parts = append(parts, fmt.Sprintf("%s:%d", domain, p))
		} else {
			parts = append(parts, fmt.Sprintf(":%d", p))
		}
	}
	return strings.Join(parts, ", ")
}
