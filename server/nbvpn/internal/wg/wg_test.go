package wg

import (
	"os"
	"strings"
	"testing"

	"github.com/netbridge/nbvpn/internal/state"
)

func TestSubnetCIDR(t *testing.T) {
	if got := SubnetCIDR("10.8.0.1/24"); got != "10.8.0.0/24" {
		t.Fatalf("got %s", got)
	}
	if got := SubnetCIDR("bad"); got != "10.8.0.0/24" {
		t.Fatalf("fallback got %s", got)
	}
}

func TestDefaultClientAllowedIPs(t *testing.T) {
	full := DefaultClientAllowedIPs("10.8.0.1/24", false)
	if len(full) != 2 || full[0] != "0.0.0.0/0" || full[1] != "::/0" {
		t.Fatalf("full tunnel: %v", full)
	}
	split := DefaultClientAllowedIPs("10.8.0.1/24", true)
	if len(split) != 1 || split[0] != "10.8.0.0/24" {
		t.Fatalf("split tunnel: %v", split)
	}
}

func TestBuildServerConfIncludesNAT(t *testing.T) {
	st := &state.ServerState{
		PrivateKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
		Address:    "10.8.0.1/24",
		ListenPort: 51820,
	}
	peers := []*state.PeerRecord{{
		ID: "1", Name: "p1", PublicKey: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
		Address: "10.8.0.2/32",
	}}
	conf := BuildServerConfLinux(st, peers)
	for _, want := range []string{
		"PostUp =",
		"PostDown =",
		"net.ipv4.ip_forward=1",
		"MASQUERADE",
		"-s 10.8.0.0/24",
		"AllowedIPs = 10.8.0.2/32",
	} {
		if !strings.Contains(conf, want) {
			t.Fatalf("conf missing %q:\n%s", want, conf)
		}
	}
	if strings.Contains(conf, "PrivateKey = AAAA") && !strings.Contains(conf, "ListenPort = 51820") {
		t.Fatal("unexpected conf shape")
	}
}

func TestBuildServerConfWindows(t *testing.T) {
	st := &state.ServerState{
		PrivateKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
		Address:    "10.8.0.1/24",
		ListenPort: 51820,
	}
	peers := []*state.PeerRecord{{
		ID: "1", Name: "p1", PublicKey: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
		Address: "10.8.0.2/32",
	}}
	conf := BuildServerConfWindows(st, peers)
	for _, want := range []string{
		"PostUp = powershell.exe",
		"Forwarding Enabled",
		"ListenPort = 51820",
		"AllowedIPs = 10.8.0.2/32",
	} {
		if !strings.Contains(conf, want) {
			t.Fatalf("windows conf missing %q:\n%s", want, conf)
		}
	}
	if strings.Contains(conf, "iptables") || strings.Contains(conf, "MASQUERADE") {
		t.Fatalf("windows conf must not use linux iptables:\n%s", conf)
	}
}

func TestIsNbvpnManagedSysctl(t *testing.T) {
	if isNbvpnManagedSysctl([]byte("# Managed by nbvpn\nnet.ipv4.ip_forward = 1\n")) {
		// ok
	} else {
		t.Fatal("expected nbvpn marker to match")
	}
	if isNbvpnManagedSysctl([]byte("net.ipv4.ip_forward = 1\n")) {
		t.Fatal("foreign sysctl must not match")
	}
}

func TestUninstallSubnet(t *testing.T) {
	dir := t.TempDir()
	store := state.New(dir)
	st := &state.ServerState{
		Version:    1,
		PrivateKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
		PublicKey:  "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
		Address:    "10.9.0.1/24",
		ListenPort: 51820,
	}
	if err := store.SaveServer(st); err != nil {
		t.Fatal(err)
	}
	if got := uninstallSubnet(store); got != "10.9.0.0/24" {
		t.Fatalf("got %s", got)
	}
	if got := uninstallSubnet(state.New("/nonexistent")); got != "10.8.0.0/24" {
		t.Fatalf("fallback got %s", got)
	}
}

func TestListUninstallTargetsIncludesDataDir(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	store := state.New(dir)
	targets := ListUninstallTargets(store)
	found := false
	for _, tg := range targets {
		if tg.Kind == "data" && tg.Path == dir && tg.Present {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected data target for %s: %+v", dir, targets)
	}
}

func TestCleanupLinuxFirewallRulesNoIptables(t *testing.T) {
	if lookPath("iptables") {
		t.Skip("iptables present — skip no-op path test")
	}
	if n := cleanupLinuxFirewallRules("10.8.0.0/24", "nbvpn"); n != 0 {
		t.Fatalf("expected 0 removed, got %d", n)
	}
}
