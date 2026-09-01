//go:build !windows

package obfstransport

import (
	"fmt"
	"net"
	"runtime"
	"syscall"

	"golang.org/x/sys/unix"
)

// bindToPhysicalInterface returns a Dialer whose sockets are bound to the
// default-route (physical) interface. Without this, a full-tunnel WireGuard
// route (0.0.0.0/0) captures the obfs2 transport's own outbound TCP and loops
// it back into the tunnel, so the handshake never reaches the server (the
// "connected but zero traffic" bug).
//
// macOS/iOS: IP_BOUND_IF. Linux: SO_BINDTOIFINDEX.
func bindToPhysicalInterface() *net.Dialer {
	d := &net.Dialer{}
	ifIndex, err := defaultIfIndex()
	if err != nil || ifIndex <= 0 {
		return d
	}
	d.Control = func(network, address string, c syscall.RawConn) error {
		var serr error
		if cerr := c.Control(func(fd uintptr) {
			switch runtime.GOOS {
			case "darwin", "ios":
				// IP_BOUND_IF (25) — only defined on darwin; literal for linux builds.
				serr = unix.SetsockoptInt(int(fd), unix.IPPROTO_IP, 25, ifIndex)
			case "linux":
				// SO_BINDTOIFINDEX (26) — not exposed as a named const in x/sys/unix.
				serr = unix.SetsockoptInt(int(fd), unix.SOL_SOCKET, 26, ifIndex)
			}
		}); cerr != nil {
			return cerr
		}
		return serr
	}
	return d
}

// defaultIfIndex discovers the interface that carries the default route by
// probing a public resolver over UDP and resolving the local source address.
func defaultIfIndex() (int, error) {
	c, err := net.Dial("udp4", "8.8.8.8:53")
	if err != nil {
		return 0, err
	}
	defer c.Close()
	la, ok := c.LocalAddr().(*net.UDPAddr)
	if !ok {
		return 0, fmt.Errorf("unexpected local addr type")
	}
	ifaces, err := net.Interfaces()
	if err != nil {
		return 0, err
	}
	for _, ifi := range ifaces {
		addrs, err := ifi.Addrs()
		if err != nil {
			continue
		}
		for _, a := range addrs {
			if ipn, ok := a.(*net.IPNet); ok && ipn.IP.Equal(la.IP) {
				return ifi.Index, nil
			}
		}
	}
	return 0, fmt.Errorf("no interface for %s", la.IP)
}
