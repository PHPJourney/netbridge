package state

import (
	"os"
	"testing"
)

func TestDeletePeer(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	if err := s.EnsureDirs(); err != nil {
		t.Fatal(err)
	}
	p := &PeerRecord{
		ID:        "peer-1",
		Name:      "phone",
		PublicKey: "pub",
		Address:   "10.8.0.2/32",
		CreatedAt: NowRFC3339(),
	}
	if err := s.SavePeer(p); err != nil {
		t.Fatal(err)
	}
	if err := s.WritePeerProfileJSON(p.ID, []byte(`{}`)); err != nil {
		t.Fatal(err)
	}
	if err := s.WritePeerWGConf(p.ID, "[Interface]\n"); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(s.PeerQRPath(p.ID), []byte("png"), 0o600); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{
		s.peerMetaPath(p.ID),
		s.PeerProfilePath(p.ID),
		s.PeerWGConfPath(p.ID),
		s.PeerQRPath(p.ID),
	} {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("expected %s before delete: %v", path, err)
		}
	}
	if err := s.DeletePeer(p.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.LoadPeer(p.ID); !os.IsNotExist(err) {
		t.Fatalf("meta should be gone: %v", err)
	}
	for _, path := range []string{
		s.PeerProfilePath(p.ID),
		s.PeerWGConfPath(p.ID),
		s.PeerQRPath(p.ID),
	} {
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatalf("expected %s removed: %v", path, err)
		}
	}
	peers, err := s.ListPeers()
	if err != nil {
		t.Fatal(err)
	}
	if len(peers) != 0 {
		t.Fatalf("ListPeers after delete: got %d", len(peers))
	}
	if err := s.DeletePeer("missing"); err == nil {
		t.Fatal("expected error deleting missing peer")
	}
}

func TestDeletePeer_idempotentArtifacts(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	if err := s.EnsureDirs(); err != nil {
		t.Fatal(err)
	}
	p := &PeerRecord{ID: "x", Name: "x", Address: "10.8.0.3/32", CreatedAt: NowRFC3339()}
	if err := s.SavePeer(p); err != nil {
		t.Fatal(err)
	}
	if err := s.DeletePeer(p.ID); err != nil {
		t.Fatal(err)
	}
	// profile/conf/png were never written — should still succeed
	if err := s.DeletePeer(p.ID); err == nil {
		t.Fatal("second delete should fail: peer not found")
	}
}

func TestServerState_IPv6FieldsRoundTrip(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	st := &ServerState{
		Version:     1,
		Interface:   InterfaceName,
		ListenPort:  DefaultListenPort,
		PrivateKey:  "priv",
		PublicKey:   "pub",
		Address:     DefaultServerAddr,
		Endpoint:    "203.0.113.10:51820",
		EndpointV6:  "[2001:db8::1]:51820",
		IPv6Enabled: true,
		DNS:         []string{"1.1.1.1"},
		AllowedIPs:  []string{"0.0.0.0/0", "::/0"},
		InstalledAt: NowRFC3339(),
	}
	if err := s.SaveServer(st); err != nil {
		t.Fatal(err)
	}
	got, err := s.LoadServer()
	if err != nil {
		t.Fatal(err)
	}
	if got.Endpoint != st.Endpoint {
		t.Fatalf("endpoint: %q", got.Endpoint)
	}
	if got.EndpointV6 != st.EndpointV6 {
		t.Fatalf("endpointV6: %q", got.EndpointV6)
	}
	if !got.IPv6Enabled {
		t.Fatal("expected ipv6Enabled true")
	}
}

func TestServerState_LegacyWithoutIPv6(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	st := &ServerState{
		Version:    1,
		Interface:  InterfaceName,
		ListenPort: DefaultListenPort,
		Endpoint:   "203.0.113.10:51820",
		DNS:        []string{"1.1.1.1"},
		AllowedIPs: []string{"0.0.0.0/0"},
	}
	if err := s.SaveServer(st); err != nil {
		t.Fatal(err)
	}
	got, err := s.LoadServer()
	if err != nil {
		t.Fatal(err)
	}
	if got.EndpointV6 != "" || got.IPv6Enabled {
		t.Fatalf("legacy state should have empty IPv6: %+v", got)
	}
}
