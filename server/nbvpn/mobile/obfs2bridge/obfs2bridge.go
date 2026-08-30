// Package obfs2bridge exposes the obfs2 transport client to mobile apps
// (Android AAR / iOS xcframework) via gomobile bind.
package obfs2bridge

import (
	"encoding/hex"
	"fmt"
	"strings"

	"github.com/netbridge/nbvpn/internal/obfstransport"
)

var client *obfstransport.Client

// Start launches the obfs2 client bridge (multi-channel, multi-entry,
// auto-reconnect). serverAddrs is a comma-separated entry pool such as
// "1.2.3.4:443,1.2.3.4:8443"; pskHex is the hex-encoded PSK; localUDP is the
// local UDP port the bridge listens on (WireGuard Endpoint must point at
// 127.0.0.1:localUDP); insecure allows self-signed server certs; channels is
// the parallel tunnel count.
func Start(serverAddrs string, pskHex string, localUDP int, insecure bool, channels int) error {
	Stop()

	entries := splitTrim(serverAddrs)
	if len(entries) == 0 {
		return fmt.Errorf("obfs2bridge: no server entries")
	}
	psk, err := hex.DecodeString(strings.TrimSpace(pskHex))
	if err != nil || len(psk) < 16 {
		return fmt.Errorf("obfs2bridge: invalid PSK")
	}
	if channels <= 0 {
		channels = 4
	}
	c, err := obfstransport.NewClient(obfstransport.ClientOptions{
		ServerAddrs:        entries,
		LocalUDP:           fmt.Sprintf("127.0.0.1:%d", localUDP),
		PSK:                obfstransport.PSK(psk),
		Channels:           channels,
		InsecureSkipVerify: insecure,
	})
	if err != nil {
		return err
	}
	client = c
	go func() {
		_ = c.Run()
	}()
	return nil
}

// Stop terminates the bridge.
func Stop() {
	if client != nil {
		client.Stop()
		client = nil
	}
}

// Running reports whether the bridge is active.
func Running() bool { return client != nil }

func splitTrim(s string) []string {
	var out []string
	for _, part := range strings.Split(s, ",") {
		p := strings.TrimSpace(part)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
