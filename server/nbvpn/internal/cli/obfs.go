package cli

import (
	"fmt"
	"os"
	"strings"

	"github.com/netbridge/nbvpn/internal/obfs"
	"github.com/netbridge/nbvpn/internal/state"
)

func cmdObfs(args []string) error {
	if len(args) == 0 {
		printObfsHelp(os.Stdout)
		return nil
	}
	sub := args[0]
	rest := args[1:]

	dir, err := state.PreferWritableDataDir()
	if err != nil {
		return err
	}
	os.Setenv(state.EnvDataDir, dir)
	m := obfs.New(dir)

	switch sub {
	case "install":
		return obfsInstall(m, rest)
	case "status":
		return obfsStatus(m)
	case "client-config", "client":
		return obfsClientConfig(m)
	case "uninstall":
		return obfsUninstall(m, rest)
	default:
		return fmt.Errorf("unknown obfs subcommand %q", sub)
	}
}

func obfsInstall(m *obfs.Manager, args []string) error {
	domain := ""
	port := 0
	wgPort := 0
	for i := 0; i < len(args); i++ {
		switch args[i] {
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
			if _, err := fmt.Sscanf(args[i], "%d", &port); err != nil {
				return fmt.Errorf("invalid --port %q", args[i])
			}
		case "--wg-port":
			if i+1 >= len(args) {
				return fmt.Errorf("--wg-port requires a value")
			}
			i++
			if _, err := fmt.Sscanf(args[i], "%d", &wgPort); err != nil {
				return fmt.Errorf("invalid --wg-port %q", args[i])
			}
		default:
			return fmt.Errorf("unknown obfs install flag %q", args[i])
		}
	}

	st, err := m.Install(domain, port, wgPort)
	if err != nil {
		return err
	}

	fmt.Println()
	fmt.Println("=== nbvpn obfs install complete ===")
	fmt.Printf("wstunnel:  %s (%s)\n", st.WstunnelVer, st.BinDir+"/wstunnel")
	fmt.Printf("listen:    wss://0.0.0.0:%d\n", st.Port)
	fmt.Printf("path:      /%s\n", st.PathSecret)
	fmt.Printf("forward:   -> 127.0.0.1:%d (WireGuard)\n", st.WGPort)
	fmt.Println()
	printCloudflareGuide(st)
	fmt.Println()
	printFirewallGuide(st)
	return nil
}

func obfsStatus(m *obfs.Manager) error {
	st, err := m.Load()
	if err != nil {
		return err
	}
	if !st.Enabled {
		fmt.Println("obfs: not installed")
		return nil
	}
	active, _ := m.Status()
	fmt.Printf("obfs: enabled (wstunnel %s)\n", st.WstunnelVer)
	fmt.Printf("service: %s (%s)\n", obfs.ServiceName, active)
	fmt.Printf("listen: wss://0.0.0.0:%d  path: /%s  -> 127.0.0.1:%d\n", st.Port, st.PathSecret, st.WGPort)
	if st.Domain != "" {
		fmt.Printf("domain: %s\n", st.Domain)
	}
	return nil
}

func obfsClientConfig(m *obfs.Manager) error {
	st, err := m.Load()
	if err != nil {
		return err
	}
	if !st.Enabled {
		return fmt.Errorf("obfs not installed — run: nbvpn obfs install")
	}
	domain := st.Domain
	if domain == "" {
		domain = "<your-domain-or-server-ip>"
	}
	fmt.Printf(`=== 客户端 obfs 接入配置 ===

1) 在本机/客户端先启动 wstunnel client（监听本地 UDP %d）：

   wstunnel client -L "udp://%d:127.0.0.1:%d" wss://%s/%s

2) WireGuard 配置里把 Endpoint 改为 127.0.0.1:%d（其余不变）。

3) 平台说明：
   - 桌面（macOS/Linux/Windows）：从 GitHub 下载 wstunnel %s 对应平台二进制，
     开机自启（launchd / systemd --user / 任务计划）。
   - Android：NetBridge 客户端将内嵌 wstunnel 数据面（进行中）；
     临时可用 Termux 跑 wstunnel_%s_android_arm64.tar.gz。
   - iOS/macOS Packet Tunnel：后续在扩展内起本地 wstunnel client。

4) 断线重连：wstunnel client 会自动重连；WireGuard PersistentKeepalive 照常。
`, obfs.DefaultClientPort, obfs.DefaultClientPort, st.WGPort, domain, st.PathSecret,
		obfs.DefaultClientPort, obfs.Version, strings.TrimPrefix(obfs.Version, "v"))
	return nil
}

func obfsUninstall(m *obfs.Manager, args []string) error {
	st, err := m.Load()
	if err != nil {
		return err
	}
	if !st.Enabled {
		fmt.Println("obfs: not installed (nothing to do)")
		return nil
	}
	yes := false
	for _, a := range args {
		if a == "--yes" || a == "-y" {
			yes = true
		}
	}
	if !yes {
		fmt.Printf("Remove wstunnel obfs layer? (service %s, binary, config) [y/N]: ", obfs.ServiceName)
		var answer string
		fmt.Scanln(&answer)
		if !strings.EqualFold(strings.TrimSpace(answer), "y") && !strings.EqualFold(strings.TrimSpace(answer), "yes") {
			fmt.Println("aborted")
			return nil
		}
	}
	if err := m.Uninstall(); err != nil {
		return err
	}
	fmt.Println("obfs: uninstalled")
	return nil
}

func printCloudflareGuide(st *obfs.State) {
	fmt.Println(`Cloudflare 前置（隐藏服务器 IP，强烈推荐）：
  1. DNS 添加 A 记录：vpn.<你的域名> -> <服务器公网 IP>，开启橙云（Proxied）
  2. SSL/TLS 模式选择 Full（源站为 wstunnel 自签证书，勿用 Full(strict)）
  3. 客户端连接地址：wss://vpn.<你的域名>/<path>（流量走 Cloudflare 边缘）
  4. 不想用 Cloudflare 时：wss://<服务器公网 IP>:<port>/<path>（IP 直接暴露）`)
}

func printFirewallGuide(st *obfs.State) {
	fmt.Printf(`防火墙（服务器）：
  • 需放行 TCP %d（wstunnel wss）
  • 原 WireGuard UDP %d 无需对公网开放（仅本机回环，更安全）
`, st.Port, st.WGPort)
}

func printObfsHelp(w *os.File) {
	fmt.Fprint(w, `nbvpn obfs — wstunnel 混淆层（WireGuard over WebSocket/HTTPS，抗 UDP 封锁）

用法:
  nbvpn obfs install [--domain <d>] [--port <443>] [--wg-port <51820>]
                          下载 wstunnel、部署 systemd 服务并启用
  nbvpn obfs status       查看状态
  nbvpn obfs client-config  输出客户端接入配置（本地端口 + Endpoint 修改）
  nbvpn obfs uninstall [--yes]  停止并移除

说明:
  - 服务端监听 wss://0.0.0.0:443（伪装成 HTTPS），转发到本机 WireGuard UDP
  - WebSocket 升级路径为随机 secret，作为客户端认证
  - 配合 Cloudflare 橙云可完全隐藏服务器 IP（见 install 输出指引）
`)
}
