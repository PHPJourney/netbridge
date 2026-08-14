package profile_test

import (
	"encoding/base64"
	"strings"
	"testing"

	"github.com/netbridge/nbvpn/internal/profile"
	"golang.zx2c4.com/wireguard/wgctrl/wgtypes"
)

func sampleProfile(t *testing.T) *profile.NbVpnProfile {
	t.Helper()
	ck, err := wgtypes.GeneratePrivateKey()
	if err != nil {
		t.Fatal(err)
	}
	sk, err := wgtypes.GeneratePrivateKey()
	if err != nil {
		t.Fatal(err)
	}
	return &profile.NbVpnProfile{
		V:    1,
		Name: "test-peer",
		Client: profile.ClientSection{
			PrivateKey: ck.String(),
			Address:    []string{"10.8.0.2/32"},
			DNS:        []string{"1.1.1.1", "1.0.0.1"},
			MTU:        1280,
		},
		Server: profile.ServerSection{
			PublicKey:           sk.PublicKey().String(),
			Endpoint:            "203.0.113.10:51820",
			AllowedIPs:          []string{"0.0.0.0/0", "::/0"},
			PersistentKeepalive: 25,
			PresharedKey:        nil,
		},
	}
}

func TestURIRoundTrip(t *testing.T) {
	p := sampleProfile(t)
	uri, err := profile.EncodeURI(p)
	if err != nil {
		t.Fatalf("EncodeURI: %v", err)
	}
	if !strings.HasPrefix(uri, "nbvpn:1?") {
		t.Fatalf("unexpected URI prefix: %s", uri[:min(20, len(uri))])
	}
	// no padding in base64url
	payload := strings.TrimPrefix(uri, "nbvpn:1?")
	if strings.ContainsAny(payload, "+/=") {
		t.Fatalf("payload should be base64url without padding, got special chars")
	}
	got, err := profile.DecodeURI(uri)
	if err != nil {
		t.Fatalf("DecodeURI: %v", err)
	}
	if got.V != p.V || got.Name != p.Name {
		t.Fatalf("v/name mismatch: %+v vs %+v", got, p)
	}
	if got.Client.PrivateKey != p.Client.PrivateKey {
		t.Fatal("client private key mismatch")
	}
	if got.Server.PublicKey != p.Server.PublicKey {
		t.Fatal("server public key mismatch")
	}
	if got.Server.Endpoint != p.Server.Endpoint {
		t.Fatalf("endpoint mismatch: %q vs %q", got.Server.Endpoint, p.Server.Endpoint)
	}
	if len(got.Client.Address) != 1 || got.Client.Address[0] != p.Client.Address[0] {
		t.Fatalf("address mismatch: %v", got.Client.Address)
	}
	if len(got.Server.AllowedIPs) != 2 {
		t.Fatalf("allowedIPs: %v", got.Server.AllowedIPs)
	}
}

func TestDecodeRejectsBadScheme(t *testing.T) {
	_, err := profile.DecodeURI("wireguard:1?abc")
	if err == nil || !strings.Contains(err.Error(), "E_URI_SCHEME") {
		t.Fatalf("expected E_URI_SCHEME, got %v", err)
	}
}

func TestDecodeRejectsBadVersion(t *testing.T) {
	_, err := profile.DecodeURI("nbvpn:99?abc")
	if err == nil || !strings.Contains(err.Error(), "E_URI_VERSION") {
		t.Fatalf("expected E_URI_VERSION, got %v", err)
	}
}

func TestValidateRejectsMissingPort(t *testing.T) {
	p := sampleProfile(t)
	p.Server.Endpoint = "203.0.113.10"
	if err := p.Validate(); err == nil {
		t.Fatal("expected endpoint without port to fail")
	}
}

func TestValidateRejectsBadKey(t *testing.T) {
	p := sampleProfile(t)
	p.Client.PrivateKey = base64.StdEncoding.EncodeToString([]byte("short"))
	if err := p.Validate(); err == nil {
		t.Fatal("expected bad key to fail")
	}
}

func TestToWireGuardConf(t *testing.T) {
	p := sampleProfile(t)
	conf, err := profile.ToWireGuardConf(p)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"[Interface]", "[Peer]", "PrivateKey =", "Endpoint ="} {
		if !strings.Contains(conf, want) {
			t.Fatalf("conf missing %q:\n%s", want, conf)
		}
	}
	if strings.Contains(conf, "server private") {
		t.Fatal("should not contain server private key wording")
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
