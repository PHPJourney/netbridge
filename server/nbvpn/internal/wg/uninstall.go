package wg

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/netbridge/nbvpn/internal/state"
)

const (
	// SysctlForwardConf is the persistent ip_forward drop-in written by EnsureIPForwarding.
	SysctlForwardConf = "/etc/sysctl.d/99-nbvpn-forward.conf"
	sysctlManagedMarker = "# Managed by nbvpn"
	linuxUnitName       = "wg-quick@nbvpn"
	windowsNatName      = "nbvpnNat"
	windowsFirewallRule = "NetBridge nbvpn UDP 51820"
)

// UninstallOpts configures nbvpn uninstall behavior.
type UninstallOpts struct {
	// KeepData preserves the data directory (keys, peers, profiles) for reinstall.
	KeepData bool
}

// UninstallTarget describes one nbvpn-managed artifact on the host.
type UninstallTarget struct {
	Kind    string // data, wg-conf, sysctl, systemd, iptables, windows-nat, windows-fw, windows-svc
	Path    string
	Present bool
	Note    string
}

// ListUninstallTargets scans the host for nbvpn-managed artifacts.
func ListUninstallTargets(store *state.Store) []UninstallTarget {
	var out []UninstallTarget
	if store != nil && store.DataDir != "" {
		_, err := os.Stat(store.DataDir)
		out = append(out, UninstallTarget{
			Kind:    "data",
			Path:    store.DataDir,
			Present: err == nil,
			Note:    "server keys, peers, profiles, data-dir nbvpn.conf",
		})
	}
	if runtime.GOOS == "windows" {
		out = append(out,
			UninstallTarget{
				Kind:    "windows-svc",
				Path:    winTunnelServiceName(),
				Present: winTunnelInstalled(),
				Note:    "WireGuard tunnel service",
			},
			UninstallTarget{
				Kind:    "windows-nat",
				Path:    windowsNatName,
				Present: windowsNetNatPresent(),
				Note:    "NetNat from install.ps1 (best-effort remove)",
			},
			UninstallTarget{
				Kind:    "windows-fw",
				Path:    windowsFirewallRule,
				Present: windowsFirewallRulePresent(),
				Note:    "inbound UDP 51820 rule from install.ps1",
			},
		)
		return out
	}
	sysConf := filepath.Join(SystemWGDir, state.InterfaceName+".conf")
	if _, err := os.Stat(sysConf); err == nil {
		out = append(out, UninstallTarget{Kind: "wg-conf", Path: sysConf, Present: true})
	} else {
		out = append(out, UninstallTarget{Kind: "wg-conf", Path: sysConf, Present: false})
	}
	if isNbvpnSysctlPresent() {
		out = append(out, UninstallTarget{
			Kind:    "sysctl",
			Path:    SysctlForwardConf,
			Present: true,
			Note:    "net.ipv4.ip_forward drop-in",
		})
	} else if _, err := os.Stat(SysctlForwardConf); err == nil {
		out = append(out, UninstallTarget{
			Kind:    "sysctl",
			Path:    SysctlForwardConf,
			Present: false,
			Note:    "exists but not nbvpn-managed — will not remove",
		})
	}
	if DetectCapabilities().HasSystemd {
		enabled := unitEnabled(linuxUnitName)
		note := "disabled"
		if enabled {
			note = "enabled — will disable"
		}
		out = append(out, UninstallTarget{
			Kind:    "systemd",
			Path:    linuxUnitName,
			Present: enabled,
			Note:    note,
		})
	}
	subnet := uninstallSubnet(store)
	out = append(out, UninstallTarget{
		Kind:    "iptables",
		Path:    fmt.Sprintf("FORWARD/NAT rules for %s via %s", subnet, state.InterfaceName),
		Present: true,
		Note:    "best-effort cleanup (PostDown + duplicate removal)",
	})
	return out
}

// Uninstall stops the tunnel and removes nbvpn-managed host artifacts.
func Uninstall(store *state.Store, opts UninstallOpts) (log []string, err error) {
	subnet := uninstallSubnet(store)

	_, stopMsg, stopErr := Stop()
	if stopMsg != "" {
		log = append(log, "stop: "+stopMsg)
	}
	if stopErr != nil {
		log = append(log, "stop warning: "+stopErr.Error())
	}

	if runtime.GOOS == "windows" {
		log = append(log, uninstallWindows()...)
	} else {
		log = append(log, uninstallLinux(subnet)...)
	}

	if store != nil && !opts.KeepData {
		if rmErr := store.RemoveAll(); rmErr != nil {
			return log, rmErr
		}
		if store.DataDir != "" {
			log = append(log, "removed data dir: "+store.DataDir)
		}
	} else if opts.KeepData && store != nil {
		log = append(log, "kept data dir: "+store.DataDir)
	}
	return log, nil
}

func uninstallSubnet(store *state.Store) string {
	if store != nil {
		if st, err := store.LoadServer(); err == nil && st.Address != "" {
			return SubnetCIDR(st.Address)
		}
	}
	return SubnetCIDR(state.DefaultServerAddr)
}

func uninstallLinux(subnet string) []string {
	var log []string
	caps := DetectCapabilities()

	if caps.HasSystemd {
		if err := run("systemctl", "disable", linuxUnitName); err == nil {
			log = append(log, "disabled systemd unit "+linuxUnitName)
		}
	}

	// wg-quick down runs PostDown while /etc/wireguard/nbvpn.conf still exists.
	if caps.HasWGQuick && !caps.DryRun {
		if err := run("wg-quick", "down", state.InterfaceName); err == nil {
			log = append(log, "wg-quick down "+state.InterfaceName)
		}
	}

	n := cleanupLinuxFirewallRules(subnet, state.InterfaceName)
	if n > 0 {
		log = append(log, fmt.Sprintf("removed %d iptables rule(s) for %s", n, state.InterfaceName))
	}

	if removed, note := removeNbvpnSysctl(); removed {
		log = append(log, "removed "+SysctlForwardConf)
	} else if note != "" {
		log = append(log, note)
	}

	sysConf := filepath.Join(SystemWGDir, state.InterfaceName+".conf")
	if err := os.Remove(sysConf); err == nil {
		log = append(log, "removed "+sysConf)
	}
	return log
}

func uninstallWindows() []string {
	var log []string
	svc := winTunnelServiceName()
	_ = run("net", "stop", svc)
	if err := runWireGuard("/uninstalltunnelservice", state.InterfaceName); err == nil {
		log = append(log, "removed Windows tunnel service "+svc)
	}
	if removedWindowsNetNat() {
		log = append(log, "removed NetNat "+windowsNatName)
	}
	if removedWindowsFirewallRule() {
		log = append(log, "removed firewall rule: "+windowsFirewallRule)
	}
	return log
}

func isNbvpnSysctlPresent() bool {
	b, err := os.ReadFile(SysctlForwardConf)
	if err != nil {
		return false
	}
	return isNbvpnManagedSysctl(b)
}

func isNbvpnManagedSysctl(content []byte) bool {
	return strings.Contains(string(content), sysctlManagedMarker)
}

func removeNbvpnSysctl() (removed bool, note string) {
	b, err := os.ReadFile(SysctlForwardConf)
	if err != nil {
		if os.IsNotExist(err) {
			return false, ""
		}
		return false, "sysctl: " + err.Error()
	}
	if !isNbvpnManagedSysctl(b) {
		return false, SysctlForwardConf + " exists but is not nbvpn-managed — left in place"
	}
	if err := os.Remove(SysctlForwardConf); err != nil {
		return false, "remove sysctl: " + err.Error()
	}
	return true, ""
}

// cleanupLinuxFirewallRules removes PostDown-equivalent rules, including duplicates.
// Returns the number of rules successfully deleted.
func cleanupLinuxFirewallRules(subnet, iface string) int {
	if !lookPath("iptables") {
		return 0
	}
	removed := 0
	const maxPasses = 64
	for pass := 0; pass < maxPasses; pass++ {
		n := 0
		if run("iptables", "-D", "FORWARD", "-i", iface, "-j", "ACCEPT") == nil {
			n++
		}
		if run("iptables", "-D", "FORWARD", "-o", iface, "-j", "ACCEPT") == nil {
			n++
		}
		if run("iptables", "-t", "nat", "-D", "POSTROUTING", "-s", subnet, "!", "-o", iface, "-j", "MASQUERADE") == nil {
			n++
		}
		if n == 0 {
			break
		}
		removed += n
	}
	return removed
}

func windowsNetNatPresent() bool {
	if runtime.GOOS != "windows" {
		return false
	}
	err := run("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
		fmt.Sprintf(`if (Get-NetNat -Name '%s' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }`, windowsNatName))
	return err == nil
}

func removedWindowsNetNat() bool {
	if !windowsNetNatPresent() {
		return false
	}
	err := run("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
		fmt.Sprintf(`Remove-NetNat -Name '%s' -Confirm:$false -ErrorAction Stop`, windowsNatName))
	return err == nil
}

func windowsFirewallRulePresent() bool {
	if runtime.GOOS != "windows" {
		return false
	}
	err := run("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
		fmt.Sprintf(`if (Get-NetFirewallRule -DisplayName '%s' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }`, windowsFirewallRule))
	return err == nil
}

func removedWindowsFirewallRule() bool {
	if !windowsFirewallRulePresent() {
		return false
	}
	err := run("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
		fmt.Sprintf(`Remove-NetFirewallRule -DisplayName '%s' -ErrorAction Stop`, windowsFirewallRule))
	return err == nil
}

// RemoveSystemConf removes system WireGuard conf / Windows tunnel service if present.
// Deprecated: prefer Uninstall for a full clean removal.
func RemoveSystemConf() {
	if runtime.GOOS == "windows" {
		_ = run("net", "stop", winTunnelServiceName())
		_ = runWireGuard("/uninstalltunnelservice", state.InterfaceName)
		return
	}
	_ = os.Remove(filepath.Join(SystemWGDir, state.InterfaceName+".conf"))
}
