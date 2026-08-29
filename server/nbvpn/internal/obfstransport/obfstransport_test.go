package obfstransport

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"math/big"
	"net"
	"sync"
	"testing"
	"time"
)

func TestPSKAuth(t *testing.T) {
	psk, err := GeneratePSK()
	if err != nil {
		t.Fatal(err)
	}
	var nonce [8]byte
	if _, err := randRead(nonce[:]); err != nil {
		t.Fatal(err)
	}
	ts := time.Now().Unix()
	tag := authTag(psk, nonce, ts)
	if !VerifyAuth(psk, nonce, ts, tag) {
		t.Fatal("valid auth rejected")
	}
	// wrong PSK
	other, _ := GeneratePSK()
	if VerifyAuth(other, nonce, ts, tag) {
		t.Fatal("wrong PSK accepted")
	}
	// stale timestamp
	if VerifyAuth(psk, nonce, ts-3600, tag) {
		t.Fatal("stale timestamp accepted")
	}
	// tampered tag
	tag[0] ^= 0xFF
	if VerifyAuth(psk, nonce, ts, tag) {
		t.Fatal("tampered tag accepted")
	}
}

func TestFrameRoundTrip(t *testing.T) {
	var buf bytes.Buffer
	payload := []byte("wireguard-datagram-payload")
	if err := writeFrame(&buf, FrameTypeWGDatagram, payload); err != nil {
		t.Fatal(err)
	}
	// Frame is prefixed with magic and type; read back.
	got, err := readFrame(&buf)
	if err != nil {
		t.Fatal(err)
	}
	if got.Type != FrameTypeWGDatagram || !bytes.Equal(got.Payload, payload) {
		t.Fatalf("roundtrip mismatch: type=%d payload=%q", got.Type, got.Payload)
	}
}

func TestShapePaddingBounds(t *testing.T) {
	src := make([]byte, 148) // WG handshake size
	for i := 0; i < 500; i++ {
		pad := shapePadding(src)
		total := len(src) + len(pad)
		if total > 1400 {
			t.Fatalf("shaping exceeded 1400: %d", total)
		}
		if pad != nil && len(pad) == 0 {
			t.Fatal("empty non-nil padding")
		}
	}
}

// selfSignedCert generates an in-memory TLS cert for loopback testing.
func selfSignedCert(t *testing.T) (tls.Certificate, error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return tls.Certificate{}, err
	}
	tpl := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "localhost"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(24 * time.Hour),
		DNSNames:     []string{"localhost"},
	}
	der, err := x509.CreateCertificate(rand.Reader, tpl, tpl, &key.PublicKey, key)
	if err != nil {
		return tls.Certificate{}, err
	}
	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
	keyDER, err := x509.MarshalECPrivateKey(key)
	if err != nil {
		return tls.Certificate{}, err
	}
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: keyDER})
	return tls.X509KeyPair(certPEM, keyPEM)
}

// TestEndToEndBridge runs a full client<->server cycle over loopback with a
// fake WireGuard UDP endpoint that echoes datagrams.
func TestEndToEndBridge(t *testing.T) {
	psk, err := GeneratePSK()
	if err != nil {
		t.Fatal(err)
	}

	// Fake WG endpoint: UDP echo on an ephemeral port.
	wgAddr, err := net.ResolveUDPAddr("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	wgUDP, err := net.ListenUDP("udp", wgAddr)
	if err != nil {
		t.Fatal(err)
	}
	defer wgUDP.Close()
	go func() {
		buf := make([]byte, 2048)
		for {
			n, src, err := wgUDP.ReadFromUDP(buf)
			if err != nil {
				return
			}
			_, _ = wgUDP.WriteToUDP(buf[:n], src)
		}
	}()

	// Server on ephemeral TCP port with an in-memory cert.
	cert, err := selfSignedCert(t)
	if err != nil {
		t.Fatal(err)
	}
	server, err := NewServer(ServerOptions{
		ListenAddr: "127.0.0.1:0",
		Cert:       cert,
		PSK:        psk,
		WGTarget:   wgUDP.LocalAddr().String(),
	})
	if err != nil {
		t.Fatal(err)
	}
	go server.Start()
	defer server.Stop()
	lnAddr := server.lns[0].Addr().String()

	// Client with a local UDP port.
	clientUDP, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	localPort := clientUDP.LocalAddr().(*net.UDPAddr).Port
	clientUDP.Close()

	client, err := NewClient(ClientOptions{
		ServerAddr:         lnAddr,
		LocalUDP:           localAddr(localPort),
		PSK:                psk,
		InsecureSkipVerify: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	go func() {
		_ = client.Run()
	}()
	defer client.Stop()

	// Give the session a moment to establish, then send a WG datagram through.
	time.Sleep(500 * time.Millisecond)
	sendUDP, err := net.Dial("udp", localAddr(localPort))
	if err != nil {
		t.Fatal(err)
	}
	defer sendUDP.Close()
	_ = sendUDP.SetDeadline(time.Now().Add(5 * time.Second))

	// The echo comes back to the local UDP listener; read it.
	recvUDP, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 0})
	if err != nil {
		t.Fatal(err)
	}
	defer recvUDP.Close()
	// NOTE: client sends echo to the source addr of the WG datagram; use recvUDP as source.
	payload := []byte("nbvpn-e2e-datagram")
	if _, err := recvUDP.WriteToUDP(payload, &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: localPort}); err != nil {
		t.Fatal(err)
	}
	buf := make([]byte, 2048)
	_ = recvUDP.SetDeadline(time.Now().Add(5 * time.Second))
	n, _, err := recvUDP.ReadFromUDP(buf)
	if err != nil {
		t.Fatalf("no echo received: %v", err)
	}
	if !bytes.Equal(buf[:n], payload) {
		t.Fatalf("echo mismatch: got %q want %q", buf[:n], payload)
	}
}

func localAddr(port int) string {
	return net.JoinHostPort("127.0.0.1", itoa(port))
}

// TestTCPForwardEndToEnd verifies the TCP port-forwarding path: a TCP echo
// server on the node side is reachable through a local client listener.
func TestTCPForwardEndToEnd(t *testing.T) {
	psk, err := GeneratePSK()
	if err != nil {
		t.Fatal(err)
	}

	// TCP echo server (node side).
	echo, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer echo.Close()
	go func() {
		for {
			c, err := echo.Accept()
			if err != nil {
				return
			}
			go func(c net.Conn) {
				defer c.Close()
				buf := make([]byte, 4096)
				for {
					n, err := c.Read(buf)
					if n > 0 {
						_, _ = c.Write(buf[:n])
					}
					if err != nil {
						return
					}
				}
			}(c)
		}
	}()

	// Transport server (no WG traffic in this test; dummy WG target).
	cert, err := selfSignedCert(t)
	if err != nil {
		t.Fatal(err)
	}
	server, err := NewServer(ServerOptions{
		ListenAddr: "127.0.0.1:0",
		Cert:       cert,
		PSK:        psk,
		WGTarget:   "127.0.0.1:1", // unused in this test
	})
	if err != nil {
		t.Fatal(err)
	}
	go server.Start()
	defer server.Stop()
	serverAddr := server.lns[0].Addr().String()

	// Reserve a free local port for the client forward listener.
	reserve, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	localPort := reserve.Addr().(*net.TCPAddr).Port
	reserve.Close()

	client, err := NewClient(ClientOptions{
		ServerAddr:         serverAddr,
		Forwards:           []ForwardRule{{LocalAddr: localAddr(localPort), RemoteAddr: echo.Addr().String()}},
		PSK:                psk,
		InsecureSkipVerify: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	go client.Run()
	defer client.Stop()

	// Wait for the listener to come up, then connect and verify the echo.
	var conn net.Conn
	for i := 0; i < 50; i++ {
		conn, err = net.DialTimeout("tcp", localAddr(localPort), 500*time.Millisecond)
		if err == nil {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if conn == nil {
		t.Fatalf("local forward listener never came up: %v", err)
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(10 * time.Second))

	payload := []byte("tcp-forward-e2e-test-payload")
	if _, err := conn.Write(payload); err != nil {
		t.Fatal(err)
	}
	buf := make([]byte, 256)
	n, err := conn.Read(buf)
	if err != nil {
		t.Fatalf("tcp echo read: %v", err)
	}
	if string(buf[:n]) != string(payload) {
		t.Fatalf("tcp echo mismatch: got %q want %q", buf[:n], payload)
	}
}

// TestMultiChannelWGEcho verifies WG datagrams flow correctly across 4
// parallel tunnels (round-robin dispatch).
func TestMultiChannelWGEcho(t *testing.T) {
	psk, err := GeneratePSK()
	if err != nil {
		t.Fatal(err)
	}
	wgUDP, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	defer wgUDP.Close()
	go func() {
		buf := make([]byte, 2048)
		for {
			n, src, err := wgUDP.ReadFromUDP(buf)
			if err != nil {
				return
			}
			_, _ = wgUDP.WriteToUDP(buf[:n], src)
		}
	}()

	cert, err := selfSignedCert(t)
	if err != nil {
		t.Fatal(err)
	}
	server, err := NewServer(ServerOptions{
		ListenAddr: "127.0.0.1:0",
		Cert:       cert,
		PSK:        psk,
		WGTarget:   wgUDP.LocalAddr().String(),
	})
	if err != nil {
		t.Fatal(err)
	}
	go server.Start()
	defer server.Stop()

	client, err := NewClient(ClientOptions{
		ServerAddr:         server.lns[0].Addr().String(),
		LocalUDP:           localAddr(51833),
		Channels:           4,
		PSK:                psk,
		InsecureSkipVerify: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	go client.Run()
	defer client.Stop()

	// Wait for tunnels to come up, then pump 20 datagrams through.
	time.Sleep(800 * time.Millisecond)
	recv, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 0})
	if err != nil {
		t.Fatal(err)
	}
	defer recv.Close()
	_ = recv.SetDeadline(time.Now().Add(15 * time.Second))
	dst := &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 51833}
	for i := 0; i < 20; i++ {
		payload := []byte(fmt.Sprintf("multi-channel-datagram-%02d", i))
		if _, err := recv.WriteToUDP(payload, dst); err != nil {
			t.Fatal(err)
		}
	}
	got := make(map[string]bool)
	buf := make([]byte, 2048)
	for i := 0; i < 20; i++ {
		n, _, err := recv.ReadFromUDP(buf)
		if err != nil {
			t.Fatalf("echo %d: %v", i, err)
		}
		got[string(buf[:n])] = true
	}
	for i := 0; i < 20; i++ {
		key := fmt.Sprintf("multi-channel-datagram-%02d", i)
		if !got[key] {
			t.Fatalf("missing echo for %q (got %d/%d)", key, len(got), 20)
		}
	}
}

// TestChannelFailover verifies traffic survives the loss of one tunnel and
// that the pool rebuilds it.
func TestChannelFailover(t *testing.T) {
	psk, err := GeneratePSK()
	if err != nil {
		t.Fatal(err)
	}
	wgUDP, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	defer wgUDP.Close()
	go func() {
		buf := make([]byte, 2048)
		for {
			n, src, err := wgUDP.ReadFromUDP(buf)
			if err != nil {
				return
			}
			_, _ = wgUDP.WriteToUDP(buf[:n], src)
		}
	}()

	cert, err := selfSignedCert(t)
	if err != nil {
		t.Fatal(err)
	}
	server, err := NewServer(ServerOptions{
		ListenAddr: "127.0.0.1:0",
		Cert:       cert,
		PSK:        psk,
		WGTarget:   wgUDP.LocalAddr().String(),
	})
	if err != nil {
		t.Fatal(err)
	}
	go server.Start()
	defer server.Stop()

	// Wrap the server listener to capture accepted conns so we can kill one.
	killLn := &killListener{Listener: server.lns[0]}
	server.lns[0] = killLn

	client, err := NewClient(ClientOptions{
		ServerAddr:         killLn.Addr().String(),
		LocalUDP:           localAddr(51834),
		Channels:           2,
		PSK:                psk,
		InsecureSkipVerify: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	go client.Run()
	defer client.Stop()

	// Wait for 2 tunnels, then kill one.
	time.Sleep(800 * time.Millisecond)
	killLn.mu.Lock()
	n := len(killLn.conns)
	var victim net.Conn
	if n >= 1 {
		victim = killLn.conns[0]
	}
	killLn.mu.Unlock()
	if victim == nil {
		t.Fatal("no tunnel established")
	}
	_ = victim.Close()
	time.Sleep(500 * time.Millisecond) // let the client notice + rebuild

	recv, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 0})
	if err != nil {
		t.Fatal(err)
	}
	defer recv.Close()
	_ = recv.SetDeadline(time.Now().Add(15 * time.Second))
	dst := &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 51834}
	for i := 0; i < 10; i++ {
		payload := []byte(fmt.Sprintf("failover-datagram-%02d", i))
		if _, err := recv.WriteToUDP(payload, dst); err != nil {
			t.Fatal(err)
		}
	}
	got := make(map[string]bool)
	buf := make([]byte, 2048)
	for i := 0; i < 10; i++ {
		n, _, err := recv.ReadFromUDP(buf)
		if err != nil {
			t.Fatalf("echo %d after failover: %v", i, err)
		}
		got[string(buf[:n])] = true
	}
	for i := 0; i < 10; i++ {
		key := fmt.Sprintf("failover-datagram-%02d", i)
		if !got[key] {
			t.Fatalf("missing echo for %q after failover", key)
		}
	}
}

// killListener records accepted connections so a test can kill them.
type killListener struct {
	net.Listener
	mu    sync.Mutex
	conns []net.Conn
}

func (k *killListener) Accept() (net.Conn, error) {
	c, err := k.Listener.Accept()
	if err != nil {
		return nil, err
	}
	k.mu.Lock()
	k.conns = append(k.conns, c)
	k.mu.Unlock()
	return c, nil
}

// TestSingleIPMultiEntry verifies multi-entry on one IP: the server listens
// on several ports, the client pool spans them, and killing one port's
// listener shifts traffic to the surviving entries.
func TestSingleIPMultiEntry(t *testing.T) {
	psk, err := GeneratePSK()
	if err != nil {
		t.Fatal(err)
	}
	wgUDP, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	defer wgUDP.Close()
	go func() {
		buf := make([]byte, 2048)
		for {
			n, src, err := wgUDP.ReadFromUDP(buf)
			if err != nil {
				return
			}
			_, _ = wgUDP.WriteToUDP(buf[:n], src)
		}
	}()

	cert, err := selfSignedCert(t)
	if err != nil {
		t.Fatal(err)
	}
	// Two entries on one IP.
	server, err := NewServer(ServerOptions{
		ListenAddrs: []string{"127.0.0.1:0", "127.0.0.1:0"},
		Cert:        cert,
		PSK:         psk,
		WGTarget:    wgUDP.LocalAddr().String(),
	})
	if err != nil {
		t.Fatal(err)
	}
	go server.Start()
	defer server.Stop()
	entryA := server.lns[0].Addr().String()
	entryB := server.lns[1].Addr().String()

	client, err := NewClient(ClientOptions{
		ServerAddrs:       []string{entryA, entryB},
		LocalUDP:          localAddr(51835),
		Channels:          2,
		PSK:                psk,
		InsecureSkipVerify: true,
	})
	if err != nil {
		t.Fatal(err)
	}
	go client.Run()
	defer client.Stop()

	recv, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 0})
	if err != nil {
		t.Fatal(err)
	}
	defer recv.Close()
	_ = recv.SetDeadline(time.Now().Add(15 * time.Second))
	dst := &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 51835}

	sendAndExpect := func(tag string, n int) {
		t.Helper()
		for i := 0; i < n; i++ {
			payload := []byte(fmt.Sprintf("%s-%02d", tag, i))
			if _, err := recv.WriteToUDP(payload, dst); err != nil {
				t.Fatal(err)
			}
		}
		got := make(map[string]bool)
		buf := make([]byte, 2048)
		for i := 0; i < n; i++ {
			rn, _, err := recv.ReadFromUDP(buf)
			if err != nil {
				t.Fatalf("%s echo %d: %v", tag, i, err)
			}
			got[string(buf[:rn])] = true
		}
		for i := 0; i < n; i++ {
			key := fmt.Sprintf("%s-%02d", tag, i)
			if !got[key] {
				t.Fatalf("%s: missing echo %q", tag, key)
			}
		}
	}

	time.Sleep(500 * time.Millisecond) // tunnels up
	sendAndExpect("before-kill", 5)

	// Kill one entry port.
	_ = server.lns[0].Close()
	time.Sleep(1 * time.Second) // client notices + rebuilds on surviving entry

	sendAndExpect("after-kill", 5)
}
