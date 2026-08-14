package wg

import (
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
