//go:build windows

package obfstransport

import (
	"encoding/binary"
	"fmt"
	"net"
	"syscall"

	"golang.org/x/sys/windows"
)

// bindToPhysicalInterface returns a Dialer whose sockets are bound to the
// default-route (physical) interface. On Windows this uses IP_UNICAST_IF
// (IPv4, option 31) with the interface index in network byte order — the
// Windows equivalent of the macOS/Linux SO_BINDTOIFINDEX guard against the
// full-tunnel route loop in the obfs2 transport.
func bindToPhysicalInterface() *net.Dialer {
	d := &net.Dialer{}
	ifIndex, err := defaultIfIndex()
	if err != nil || ifIndex <= 0 {
		return d
	}
	// Windows expects the interface index in network byte order.
	idx := int(binary.BigEndian.Uint32([]byte{0, 0, byte(ifIndex >> 8), byte(ifIndex)}))
	d.Control = func(network, address string, c syscall.RawConn) error {
		var serr error
		if cerr := c.Control(func(fd uintptr) {
			serr = windows.SetsockoptInt(
				windows.Handle(fd), windows.IPPROTO_IP, 31 /* IP_UNICAST_IF */, idx)
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
