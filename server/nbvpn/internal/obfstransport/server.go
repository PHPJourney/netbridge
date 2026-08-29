package obfstransport

import (
	"crypto/tls"
	"encoding/binary"
	"errors"
	"fmt"
	"log"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

// ServerOptions configures the obfs transport server.
type ServerOptions struct {
	// ListenAddr is the TCP listen address, e.g. ":443".
	ListenAddr string
	// ListenAddrs is the multi-entry form: several listen addresses on the
	// same IP (e.g. [":443", ":8443", ":2053"]). Takes precedence over
	// ListenAddr when non-empty.
	ListenAddrs []string
	// CertFile / KeyFile are the TLS certificate paths (real CA-signed cert).
	// When empty, Cert is used instead (testing / embedded deployment).
	CertFile string
	KeyFile  string
	// Cert is an in-memory TLS certificate (used when CertFile is empty).
	Cert tls.Certificate
	// PSK authenticates clients after the TLS handshake.
	PSK PSK
	// WGTarget is the local WireGuard UDP address, e.g. "127.0.0.1:51820".
	WGTarget string
	// Logger receives diagnostics; nil logs to the standard logger.
	Logger *log.Logger
}

// Server is the obfs transport server (runs on the node). It can listen on
// multiple entry ports on the same IP (single-IP multi-entry).
type Server struct {
	opts   ServerOptions
	lns    []net.Listener
	logger *log.Logger
	active int64
}

// NewServer builds a Server; call Start to begin serving.
func NewServer(opts ServerOptions) (*Server, error) {
	if err := ValidatePSK(opts.PSK); err != nil {
		return nil, err
	}
	var cert tls.Certificate
	var err error
	if opts.CertFile != "" || opts.KeyFile != "" {
		cert, err = tls.LoadX509KeyPair(opts.CertFile, opts.KeyFile)
		if err != nil {
			return nil, err
		}
	} else if len(opts.Cert.Certificate) > 0 {
		cert = opts.Cert
	} else {
		return nil, fmt.Errorf("obfstransport: no TLS certificate (set CertFile/KeyFile or Cert)")
	}
	tlsCfg := &tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS12,
	}
	addrs := opts.ListenAddrs
	if len(addrs) == 0 && opts.ListenAddr != "" {
		addrs = []string{opts.ListenAddr}
	}
	if len(addrs) == 0 {
		return nil, fmt.Errorf("obfstransport: no listen address (set ListenAddr or ListenAddrs)")
	}
	s := &Server{opts: opts, logger: opts.Logger}
	for _, addr := range addrs {
		ln, err := tls.Listen("tcp", addr, tlsCfg)
		if err != nil {
			s.Stop()
			return nil, fmt.Errorf("listen %s: %w", addr, err)
		}
		s.lns = append(s.lns, ln)
	}
	return s, nil
}

func (s *Server) logf(format string, args ...interface{}) {
	if s.logger != nil {
		s.logger.Printf(format, args...)
	}
}

// Start serves until Stop is called.
func (s *Server) Start() error {
	var wg sync.WaitGroup
	errCh := make(chan error, len(s.lns))
	for _, ln := range s.lns {
		wg.Add(1)
		go func(ln net.Listener) {
			defer wg.Done()
			errCh <- s.acceptLoop(ln)
		}(ln)
	}
	// First error (other than a graceful close) terminates Start.
	err := <-errCh
	if errors.Is(err, net.ErrClosed) {
		err = nil
	}
	wg.Wait()
	return err
}

func (s *Server) acceptLoop(ln net.Listener) error {
	for {
		conn, err := ln.Accept()
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				return net.ErrClosed
			}
			if ne, ok := err.(net.Error); ok && ne.Timeout() {
				continue
			}
			return err
		}
		atomic.AddInt64(&s.active, 1)
		go func() {
			defer atomic.AddInt64(&s.active, -1)
			s.handleConn(conn)
		}()
	}
}

// Stop closes all listeners.
func (s *Server) Stop() error {
	var first error
	for _, ln := range s.lns {
		if err := ln.Close(); err != nil && first == nil {
			first = err
		}
	}
	return first
}

func (s *Server) handleConn(conn net.Conn) {
	defer conn.Close()
	remote := conn.RemoteAddr().String()

	// 1. TLS handshake with a timeout (probers often stall after ClientHello).
	tlsConn := conn.(*tls.Conn)
	if err := tlsConn.SetDeadline(time.Now().Add(15 * time.Second)); err != nil {
		return
	}
	if err := tlsConn.Handshake(); err != nil {
		s.logf("tls handshake %s: %v", remote, err)
		return
	}
	if err := tlsConn.SetDeadline(time.Time{}); err != nil {
		return
	}

	// 2. Issue an auth challenge (8-byte nonce).
	var nonce [8]byte
	if _, err := randRead(nonce[:]); err != nil {
		return
	}
	if err := writeFrame(tlsConn, FrameTypeChallenge, nonce[:]); err != nil {
		s.logf("challenge write %s: %v", remote, err)
		return
	}

	// 3. Read the auth frame.
	_ = tlsConn.SetReadDeadline(time.Now().Add(10 * time.Second))
	frame, err := readFrame(tlsConn)
	if err != nil {
		// Prober: no valid frame. Respond like a normal web server would.
		writeFakeHTTP(tlsConn)
		s.logf("auth read %s: %v (served fake page)", remote, err)
		return
	}
	_ = tlsConn.SetReadDeadline(time.Time{})

	if frame.Type != FrameTypeAuth || len(frame.Payload) != 8+8+32 {
		writeFakeHTTP(tlsConn)
		s.logf("auth bad frame type %d from %s", frame.Type, remote)
		return
	}
	var authNonce [8]byte
	copy(authNonce[:], frame.Payload[0:8])
	ts := int64(binary.BigEndian.Uint64(frame.Payload[8:16]))
	tag := frame.Payload[16:48]
	if authNonce != nonce || !VerifyAuth(s.opts.PSK, authNonce, ts, tag) {
		writeFakeHTTP(tlsConn)
		s.logf("auth failed from %s", remote)
		return
	}
	s.logf("session authorized: %s", remote)

	// 4. Tunnel mode: bridge TLS stream <-> WireGuard UDP.
	s.bridge(tlsConn)
}

// bridge connects the authorized TLS stream with the local WireGuard socket
// and serves TCP forwarding requests (FrameTypeTCPConnect/Data/Close).
func (s *Server) bridge(conn *tls.Conn) {
	udp, err := net.Dial("udp", s.opts.WGTarget)
	if err != nil {
		s.logf("dial wg target %s: %v", s.opts.WGTarget, err)
		return
	}
	defer udp.Close()

	tcpConns := &serverTCPConns{
		conns: make(map[uint16]net.Conn),
		opts:  s.opts,
		logf:  s.logf,
	}

	var lastActive atomic.Int64
	mark := func() { lastActive.Store(time.Now().Unix()) }
	mark()

	m := &mux{
		conn: conn,
		udpSink: func(payload []byte) error {
			mark()
			_, err := udp.Write(payload)
			return err
		},
		tcpSink: tcpConns.handle,
	}
	tcpConns.mux = m

	var once sync.Once
	var done = make(chan struct{})
	closeAll := func() {
		once.Do(func() {
			close(done)
			tcpConns.closeAll()
		})
	}

	// WG -> conn
	go func() {
		defer closeAll()
		buf := make([]byte, MaxWGDatagram)
		for {
			n, err := udp.Read(buf)
			if err != nil {
				return
			}
			mark()
			if err := m.writeFrame(FrameTypeWGDatagram, buf[:n]); err != nil {
				return
			}
		}
	}()

	// Heartbeat sender (randomized 15-45s) + idle watchdog (5 min).
	go func() {
		for {
			select {
			case <-done:
				return
			case <-time.After(heartbeatInterval()):
				if err := m.writeFrame(FrameTypeHeartbeat, nil); err != nil {
					closeAll()
					return
				}
				if time.Now().Unix()-lastActive.Load() > 300 {
					s.logf("idle session timeout")
					closeAll()
					return
				}
			}
		}
	}()

	m.readLoop(closeAll)
	<-done
}

// serverTCPConns tracks server-side TCP forwarding connections.
type serverTCPConns struct {
	mu    sync.Mutex
	conns map[uint16]net.Conn
	mux   *mux
	opts  ServerOptions
	logf  func(string, ...interface{})
}

func (t *serverTCPConns) handle(ft byte, connID uint16, data []byte) error {
	switch ft {
	case FrameTypeTCPConnect:
		return t.connect(connID, string(data))
	case FrameTypeTCPData:
		return t.data(connID, data)
	case FrameTypeTCPClose:
		return t.close(connID)
	default:
		return nil
	}
}

func (t *serverTCPConns) connect(connID uint16, target string) error {
	if target == "" {
		return t.mux.writeFrame(FrameTypeTCPClose, tcpFramePayload(connID, nil))
	}
	remote, err := net.DialTimeout("tcp", target, 10*time.Second)
	if err != nil {
		t.logf("tcp dial %s: %v", target, err)
		return t.mux.writeFrame(FrameTypeTCPClose, tcpFramePayload(connID, nil))
	}
	t.mu.Lock()
	if old, exists := t.conns[connID]; exists {
		_ = old.Close()
	}
	t.conns[connID] = remote
	t.mu.Unlock()
	t.logf("tcp forward: #%d -> %s", connID, target)

	go func() {
		buf := make([]byte, 32*1024)
		for {
			n, err := remote.Read(buf)
			if n > 0 {
				if werr := t.mux.writeFrame(FrameTypeTCPData, tcpFramePayload(connID, buf[:n])); werr != nil {
					_ = remote.Close()
					return
				}
			}
			if err != nil {
				_ = t.close(connID)
				return
			}
		}
	}()
	return nil
}

func (t *serverTCPConns) data(connID uint16, data []byte) error {
	t.mu.Lock()
	c, ok := t.conns[connID]
	t.mu.Unlock()
	if !ok {
		return t.mux.writeFrame(FrameTypeTCPClose, tcpFramePayload(connID, nil))
	}
	if len(data) == 0 {
		return nil
	}
	if _, err := c.Write(data); err != nil {
		_ = t.close(connID)
	}
	return nil
}

func (t *serverTCPConns) close(connID uint16) error {
	t.mu.Lock()
	c, ok := t.conns[connID]
	if ok {
		delete(t.conns, connID)
	}
	t.mu.Unlock()
	if ok {
		_ = c.Close()
	}
	return nil
}

func (t *serverTCPConns) closeAll() {
	t.mu.Lock()
	defer t.mu.Unlock()
	for id, c := range t.conns {
		_ = c.Close()
		delete(t.conns, id)
	}
}

// writeFakeHTTP serves a plausible 404 page to unauthenticated probers.
func writeFakeHTTP(w interface{ Write([]byte) (int, error) }) {
	body := "<html><head><title>404 Not Found</title></head><body><h1>404 Not Found</h1></body></html>"
	resp := "HTTP/1.1 404 Not Found\r\nContent-Type: text/html\r\nContent-Length: " +
		itoa(len(body)) + "\r\nConnection: close\r\n\r\n" + body
	_, _ = w.Write([]byte(resp))
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [20]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}
