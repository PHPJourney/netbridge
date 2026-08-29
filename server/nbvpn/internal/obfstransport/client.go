package obfstransport

import (
	"crypto/tls"
	"encoding/binary"
	"fmt"
	"log"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

// ForwardRule maps a local listen address to a remote target (as seen from
// the server side), e.g. tcp://127.0.0.1:33890 -> 127.0.0.1:3389.
type ForwardRule struct {
	// LocalAddr is the client-side listen address ("host:port").
	LocalAddr string
	// RemoteAddr is the server-side target ("host:port").
	RemoteAddr string
}

// ClientOptions configures the obfs transport client.
type ClientOptions struct {
	// ServerAddr is the remote host:port, e.g. "vpn.example.com:443".
	ServerAddr string
	// LocalUDP is the local UDP listen address, e.g. "127.0.0.1:51822".
	// WireGuard's Endpoint must point here. Empty disables the UDP bridge.
	LocalUDP string
	// Forwards lists TCP port-forwarding rules (local -> remote).
	Forwards []ForwardRule
	// Channels is the number of parallel TLS tunnels (default 4). More
	// channels aggregate bandwidth, survive single-connection resets and
	// make the traffic pattern resemble a browser's parallel connections.
	Channels int
	// ServerAddrs is the entry pool: multiple server host:port addresses.
	// Each tunnel picks a random entry; a dead entry is avoided on rebuild,
	// so losing one IP (endpoint blocking) only shifts traffic elsewhere.
	// Backward compatible: ServerAddr sets a single-entry pool.
	ServerAddrs []string
	// PSK authenticates to the server.
	PSK PSK
	// InsecureSkipVerify allows self-signed certs (local testing only).
	InsecureSkipVerify bool
	// Logger receives diagnostics; nil logs to the standard logger.
	Logger *log.Logger
}

// Client bridges local UDP/TCP sockets with N parallel obfs TLS tunnels.
type Client struct {
	opts    ClientOptions
	logger  *log.Logger
	stopped atomic.Bool
}

// NewClient builds a Client; call Run to start.
func NewClient(opts ClientOptions) (*Client, error) {
	if err := ValidatePSK(opts.PSK); err != nil {
		return nil, err
	}
	if opts.LocalUDP == "" && len(opts.Forwards) == 0 {
		return nil, fmt.Errorf("obfstransport: nothing to bridge (set LocalUDP or Forwards)")
	}
	if opts.Channels <= 0 {
		opts.Channels = 4
	}
	// Normalize entry pool: ServerAddr is the legacy single-entry form.
	if len(opts.ServerAddrs) == 0 {
		if opts.ServerAddr == "" {
			return nil, fmt.Errorf("obfstransport: no server address (set ServerAddrs)")
		}
		opts.ServerAddrs = []string{opts.ServerAddr}
	}
	return &Client{opts: opts, logger: opts.Logger}, nil
}

func (c *Client) logf(format string, args ...interface{}) {
	if c.logger != nil {
		c.logger.Printf(format, args...)
	}
}

// Stop terminates the client loop.
func (c *Client) Stop() { c.stopped.Store(true) }

// Run maintains Channels parallel tunnels and bridges local traffic over
// them until Stop.
func (c *Client) Run() error {
	// Shared local resources (survive individual tunnel reconnects).
	var udp *net.UDPConn
	if c.opts.LocalUDP != "" {
		udpAddr, err := net.ResolveUDPAddr("udp", c.opts.LocalUDP)
		if err != nil {
			return err
		}
		udp, err = net.ListenUDP("udp", udpAddr)
		if err != nil {
			return err
		}
		defer udp.Close()
	}
	listeners := make([]net.Listener, 0, len(c.opts.Forwards))
	for _, fw := range c.opts.Forwards {
		ln, err := net.Listen("tcp", fw.LocalAddr)
		if err != nil {
			return err
		}
		listeners = append(listeners, ln)
	}
	defer func() {
		for _, ln := range listeners {
			_ = ln.Close()
		}
	}()

	pool := newChannelPool(c.logf)
	tcp := newClientTCPConns(c.logf)
	entries := newEntryPool(c.opts.ServerAddrs)

	// Inbound sinks shared by all tunnels.
	pool.udpSink = func(payload []byte) error {
		if udp != nil {
			if dst, ok := pool.peer.Load().(*net.UDPAddr); ok {
				_, err := udp.WriteToUDP(payload, dst)
				return err
			}
		}
		return nil
	}
	pool.tcpSink = func(ft byte, connID uint16, data []byte, m *mux) error {
		return tcp.handleTCP(ft, connID, data, m)
	}

	// Tunnel maintainer: Channels independent dial-auth-bridge loops.
	for i := 0; i < c.opts.Channels; i++ {
		go c.tunnelLoop(pool, entries)
	}

	// UDP -> tunnels (round-robin across live channels).
	if udp != nil {
		go func() {
			buf := make([]byte, MaxWGDatagram)
			for {
				n, src, err := udp.ReadFromUDP(buf)
				if err != nil {
					return
				}
				pool.storePeer(src)
				if err := pool.writeWG(buf[:n]); err != nil {
					c.logf("wg write: %v", err)
				}
			}
		}()
	}

	// TCP listeners -> tunnels (each local conn binds one channel).
	for i, ln := range listeners {
		rule := c.opts.Forwards[i]
		go c.acceptLoop(ln, rule, pool, tcp)
	}

	// Park until stopped.
	for !c.stopped.Load() {
		time.Sleep(200 * time.Millisecond)
	}
	pool.closeAll()
	return nil
}

// tunnelLoop keeps one tunnel alive: dial, auth, bridge, reconnect.
// Each (re)establishment picks a random entry from the pool.
func (c *Client) tunnelLoop(pool *channelPool, entries *entryPool) {
	backoff := time.Second
	for !c.stopped.Load() {
		entry := entries.pick()
		m, err := c.dialAndAuth(entry, pool)
		if err != nil {
			entries.markFailure(entry)
			if c.stopped.Load() {
				return
			}
			c.logf("tunnel via %s: %v (retry in %v)", entry, err, backoff)
			time.Sleep(backoff)
			if backoff < 60*time.Second {
				backoff *= 2
			}
			continue
		}
		entries.markSuccess(entry)
		backoff = time.Second
		pool.add(m)
		m.readLoop(func() { pool.remove(m) })
		if c.stopped.Load() {
			return
		}
		c.logf("tunnel via %s lost (reconnecting)", entry)
	}
}

// dialAndAuth establishes and authenticates one TLS tunnel, returning a mux.
func (c *Client) dialAndAuth(entry string, pool *channelPool) (*mux, error) {
	tlsCfg := &tls.Config{
		ServerName:         hostOf(entry),
		MinVersion:         tls.VersionTLS12,
		InsecureSkipVerify: c.opts.InsecureSkipVerify,
	}
	conn, err := tls.Dial("tcp", entry, tlsCfg)
	if err != nil {
		return nil, err
	}
	fail := func(err error) (*mux, error) {
		_ = conn.Close()
		return nil, err
	}
	_ = conn.SetDeadline(time.Now().Add(15 * time.Second))
	if err := conn.Handshake(); err != nil {
		return fail(err)
	}
	challenge, err := readFrame(conn)
	if err != nil {
		return fail(err)
	}
	if challenge.Type != FrameTypeChallenge || len(challenge.Payload) != 8 {
		return fail(ErrBadFrameLength)
	}
	var nonce [8]byte
	copy(nonce[:], challenge.Payload)
	ts := time.Now().Unix()
	auth := make([]byte, 8+8+32)
	copy(auth[0:8], nonce[:])
	binary.BigEndian.PutUint64(auth[8:16], uint64(ts))
	copy(auth[16:48], authTag(c.opts.PSK, nonce, ts))
	if err := writeFrame(conn, FrameTypeAuth, auth); err != nil {
		return fail(err)
	}
	_ = conn.SetDeadline(time.Time{})
	m := &mux{conn: conn}
	// Bind sinks with per-mux closures (tcpSink needs its own mux to reply).
	m.udpSink = func(payload []byte) error { return pool.udpSink(payload) }
	m.tcpSink = func(ft byte, connID uint16, data []byte) error {
		return pool.tcpSink(ft, connID, data, m)
	}
	return m, nil
}

// acceptLoop accepts local TCP connections and forwards them over the pool.
func (c *Client) acceptLoop(ln net.Listener, rule ForwardRule, pool *channelPool, tcp *clientTCPConns) {
	for {
		local, err := ln.Accept()
		if err != nil {
			return
		}
		// Wait (up to 10s) for at least one live tunnel before accepting
		// traffic; tunnels establish asynchronously after startup.
		var ch *channel
		for i := 0; i < 100 && ch == nil; i++ {
			ch = pool.pick()
			if ch == nil {
				time.Sleep(100 * time.Millisecond)
			}
		}
		if ch == nil {
			c.logf("tcp forward rejected (no live tunnel): %s", rule.RemoteAddr)
			_ = local.Close()
			continue
		}
		connID := tcp.allocID()
		tcp.register(connID, local, ch)
		c.logf("tcp forward: #%d %s -> %s", connID, local.RemoteAddr(), rule.RemoteAddr)
		if err := ch.mux.writeFrame(FrameTypeTCPConnect, tcpFramePayload(connID, []byte(rule.RemoteAddr))); err != nil {
			tcp.unregister(connID)
			_ = local.Close()
			continue
		}
		go func(connID uint16, local net.Conn, ch *channel) {
			buf := make([]byte, 32*1024)
			for {
				n, err := local.Read(buf)
				if n > 0 {
					if werr := ch.mux.writeFrame(FrameTypeTCPData, tcpFramePayload(connID, buf[:n])); werr != nil {
						tcp.unregister(connID)
						return
					}
				}
				if err != nil {
					_ = ch.mux.writeFrame(FrameTypeTCPClose, tcpFramePayload(connID, nil))
					tcp.unregister(connID)
					return
				}
			}
		}(connID, local, ch)
	}
}

// entryPool is the multi-entry server pool. Each tunnel picks a random
// entry; recently-failed entries are deprioritized so a blocked IP does not
// attract reconnection attempts.
type entryPool struct {
	mu       sync.Mutex
	entries  []string
	failAt   map[string]time.Time
}

func newEntryPool(addrs []string) *entryPool {
	return &entryPool{
		entries: addrs,
		failAt:  make(map[string]time.Time),
	}
}

const entryCooldown = 30 * time.Second

// pick returns a random entry, avoiding recently-failed ones when possible.
func (e *entryPool) pick() string {
	e.mu.Lock()
	defer e.mu.Unlock()
	if len(e.entries) == 0 {
		return ""
	}
	now := time.Now()
	// First pass: prefer entries not in cooldown.
	healthy := make([]string, 0, len(e.entries))
	for _, a := range e.entries {
		if t, ok := e.failAt[a]; !ok || now.Sub(t) > entryCooldown {
			healthy = append(healthy, a)
		}
	}
	if len(healthy) > 0 {
		return healthy[randInt(len(healthy))]
	}
	// All in cooldown: pick any (forced retry).
	return e.entries[randInt(len(e.entries))]
}

func (e *entryPool) markFailure(addr string) {
	e.mu.Lock()
	e.failAt[addr] = time.Now()
	e.mu.Unlock()
}

func (e *entryPool) markSuccess(addr string) {
	e.mu.Lock()
	delete(e.failAt, addr)
	e.mu.Unlock()
}

func randInt(n int) int {
	var b [8]byte
	_, _ = randRead(b[:])
	return int(binary.BigEndian.Uint64(b[:]) % uint64(n))
}

// channelPool tracks live tunnels and dispatches outbound traffic.
type channelPool struct {
	mu       sync.Mutex
	channels []*channel
	rr       uint64
	peer     atomic.Value // *net.UDPAddr of last WG sender
	logf     func(string, ...interface{})
	// udpSink delivers inbound WG frames to the local UDP socket.
	udpSink func(payload []byte) error
	// tcpSink handles inbound TCP frames (bound per-mux by the caller).
	tcpSink func(ft byte, connID uint16, data []byte, m *mux) error
}

type channel struct {
	mux *mux
}

func newChannelPool(logf func(string, ...interface{})) *channelPool {
	return &channelPool{logf: logf}
}

func (p *channelPool) add(m *mux) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.channels = append(p.channels, &channel{mux: m})
	if p.logf != nil {
		p.logf("tunnel up (total %d)", len(p.channels))
	}
}

func (p *channelPool) remove(m *mux) {
	p.mu.Lock()
	defer p.mu.Unlock()
	for i, ch := range p.channels {
		if ch.mux == m {
			p.channels = append(p.channels[:i], p.channels[i+1:]...)
			break
		}
	}
}

func (p *channelPool) pick() *channel {
	p.mu.Lock()
	defer p.mu.Unlock()
	if len(p.channels) == 0 {
		return nil
	}
	p.rr++
	return p.channels[p.rr%uint64(len(p.channels))]
}

func (p *channelPool) storePeer(src *net.UDPAddr) { p.peer.Store(src) }

// writeWG sends a WG datagram over a round-robin channel.
func (p *channelPool) writeWG(payload []byte) error {
	ch := p.pick()
	if ch == nil {
		return fmt.Errorf("no live tunnel")
	}
	return ch.mux.writeFrame(FrameTypeWGDatagram, payload)
}

func (p *channelPool) closeAll() {
	p.mu.Lock()
	chans := append([]*channel(nil), p.channels...)
	p.channels = nil
	p.mu.Unlock()
	for _, ch := range chans {
		_ = ch.mux.conn.Close()
	}
}

// clientTCPConns tracks client-side TCP forwarding connections.
type clientTCPConns struct {
	mu     sync.Mutex
	conns  map[uint16]net.Conn
	nextID uint16
	logf   func(string, ...interface{})
}

func newClientTCPConns(logf func(string, ...interface{})) *clientTCPConns {
	return &clientTCPConns{
		conns:  make(map[uint16]net.Conn),
		nextID: uint16(time.Now().UnixNano() & 0xFFFF),
		logf:   logf,
	}
}

func (t *clientTCPConns) allocID() uint16 {
	t.mu.Lock()
	defer t.mu.Unlock()
	for {
		t.nextID++
		if t.nextID == 0 {
			t.nextID = 1
		}
		if _, exists := t.conns[t.nextID]; !exists {
			return t.nextID
		}
	}
}

func (t *clientTCPConns) register(id uint16, c net.Conn, ch *channel) {
	t.mu.Lock()
	t.conns[id] = c
	t.mu.Unlock()
}

func (t *clientTCPConns) unregister(id uint16) {
	t.mu.Lock()
	c, ok := t.conns[id]
	if ok {
		delete(t.conns, id)
	}
	t.mu.Unlock()
	if ok {
		_ = c.Close()
	}
}

// handleTCP processes TCP frames arriving from a tunnel.
func (t *clientTCPConns) handleTCP(ft byte, connID uint16, data []byte, m *mux) error {
	switch ft {
	case FrameTypeTCPData:
		t.mu.Lock()
		c, ok := t.conns[connID]
		t.mu.Unlock()
		if !ok {
			return m.writeFrame(FrameTypeTCPClose, tcpFramePayload(connID, nil))
		}
		if len(data) > 0 {
			if _, err := c.Write(data); err != nil {
				t.unregister(connID)
			}
		}
	case FrameTypeTCPClose:
		t.unregister(connID)
	default:
		// ignore unexpected frames
	}
	return nil
}

func (t *clientTCPConns) closeAll() {
	t.mu.Lock()
	defer t.mu.Unlock()
	for id, c := range t.conns {
		_ = c.Close()
		delete(t.conns, id)
	}
}

// hostOf extracts the host part of host:port.
func hostOf(addr string) string {
	if h, _, err := net.SplitHostPort(addr); err == nil {
		return h
	}
	return addr
}
