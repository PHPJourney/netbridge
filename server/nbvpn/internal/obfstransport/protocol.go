// Package obfstransport implements the NetBridge self-developed obfuscation
// transport: WireGuard UDP datagrams carried inside a TLS 1.3 session that
// looks like ordinary HTTPS traffic. See docs/OBFS-TRANSPORT.md.
package obfstransport

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"time"
)

const (
	// ProtocolVersion is the wire protocol version.
	ProtocolVersion byte = 1

	// FrameMagic marks the start of every post-TLS frame.
	FrameMagic byte = 0xE7

	// Frame types.
	FrameTypeChallenge byte = 0x00 // server -> client: 8-byte nonce
	FrameTypeAuth      byte = 0x01 // client -> server: auth tag
	FrameTypeWGDatagram byte = 0x10 // tunneled WireGuard UDP datagram
	FrameTypeHeartbeat byte = 0x11 // keepalive, no payload
	FrameTypeReauth    byte = 0x12 // session re-auth request

	// TCP forwarding frames (muxed over the same TLS stream).
	// Payload layout for all three: connID(2B, big-endian) [ + data ].
	FrameTypeTCPConnect byte = 0x20 // client -> server: connID + "host:port"
	FrameTypeTCPData    byte = 0x21 // both directions: connID + stream bytes
	FrameTypeTCPClose   byte = 0x22 // both directions: connID

	// MaxWGDatagram caps the accepted WG payload (WG max is 65535, MTU ~1420).
	MaxWGDatagram = 65535

	// DefaultClientPort is the local UDP port the client-side transport
	// listens on; WireGuard's Endpoint points at 127.0.0.1:<this>.
	DefaultClientPort = 51822

	// authWindow bounds the tolerated client/server clock skew.
	authWindow = 2 * time.Minute

	// heartbeatMin/Max are the randomized heartbeat interval bounds.
	heartbeatMin = 15 * time.Second
	heartbeatMax = 45 * time.Second
)

// Common protocol errors.
var (
	ErrBadMagic       = errors.New("obfstransport: bad frame magic")
	ErrAuthFailed     = errors.New("obfstransport: authentication failed")
	ErrNotAuthorized  = errors.New("obfstransport: session not authorized")
	ErrBadFrameLength = errors.New("obfstransport: frame length out of range")
)

// PSK is the pre-shared authentication secret (32 bytes recommended).
type PSK []byte

// GeneratePSK returns a random 32-byte PSK.
func GeneratePSK() (PSK, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	return PSK(b), nil
}

// authTag computes HMAC-SHA256(psk, nonce || ts || "nbvpn-obfs-v1").
func authTag(psk PSK, nonce [8]byte, ts int64) []byte {
	mac := hmac.New(sha256.New, psk)
	var buf [16]byte
	binary.BigEndian.PutUint64(buf[0:8], binary.BigEndian.Uint64(nonce[:]))
	binary.BigEndian.PutUint64(buf[8:16], uint64(ts))
	mac.Write(buf[:])
	mac.Write([]byte("nbvpn-obfs-v1"))
	return mac.Sum(nil)
}

// VerifyAuth checks nonce timestamp and tag in constant time where possible.
func VerifyAuth(psk PSK, nonce [8]byte, ts int64, tag []byte) bool {
	now := time.Now().Unix()
	if now-ts > int64(authWindow/time.Second) || ts-now > int64(authWindow/time.Second) {
		return false
	}
	expect := authTag(psk, nonce, ts)
	if len(tag) != len(expect) {
		return false
	}
	return subtle.ConstantTimeCompare(tag, expect) == 1
}

// Frame is one post-TLS protocol frame (header + payload, padding not retained).
type Frame struct {
	Type    byte
	Payload []byte
}

// writeFrame writes a frame: magic(1) type(1) len(2) padlen(2) payload padding.
// The receiver strips padding using padlen, so WireGuard only ever sees the
// original datagram.
func writeFrame(w io.Writer, ft byte, payload []byte) error {
	if len(payload) > MaxWGDatagram {
		return ErrBadFrameLength
	}
	padding := shapePadding(payload)
	hdr := []byte{
		FrameMagic, ft,
		byte(len(payload) >> 8), byte(len(payload)),
		byte(len(padding) >> 8), byte(len(padding)),
	}
	if _, err := w.Write(hdr); err != nil {
		return err
	}
	if len(payload) > 0 {
		if _, err := w.Write(payload); err != nil {
			return err
		}
	}
	if len(padding) > 0 {
		_, err := w.Write(padding)
		return err
	}
	return nil
}

// readFrame reads one frame and strips its padding.
func readFrame(r io.Reader) (Frame, error) {
	var hdr [6]byte
	if _, err := io.ReadFull(r, hdr[:]); err != nil {
		return Frame{}, err
	}
	if hdr[0] != FrameMagic {
		return Frame{}, ErrBadMagic
	}
	n := int(binary.BigEndian.Uint16(hdr[2:4]))
	pad := int(binary.BigEndian.Uint16(hdr[4:6]))
	if n > MaxWGDatagram || pad > 65535 {
		return Frame{}, ErrBadFrameLength
	}
	payload := make([]byte, n)
	if _, err := io.ReadFull(r, payload); err != nil {
		return Frame{}, err
	}
	if pad > 0 {
		discard := make([]byte, pad)
		if _, err := io.ReadFull(r, discard); err != nil {
			return Frame{}, err
		}
	}
	return Frame{Type: hdr[1], Payload: payload}, nil
}

// shapePadding returns 0..1400-N random bytes so a WG datagram lands in a
// plausible HTTPS traffic size distribution. See docs/OBFS-TRANSPORT.md §6.
func shapePadding(payload []byte) []byte {
	switch randByte() % 10 {
	case 0, 1, 2, 3:
		// 40%: API-request-ish 300..600B
		return padBytes(payload, 300+int(randByte()%255))
	case 4, 5, 6, 7:
		// 40%: response-payload-ish 900..1300B
		return padBytes(payload, 900+int(randByte()%255))
	default:
		// 20%: no padding
		return nil
	}
}

// padBytes returns n random bytes such that len(payload)+n == target.
func padBytes(payload []byte, target int) []byte {
	if len(payload) >= target {
		return nil
	}
	b := make([]byte, target-len(payload))
	_, _ = rand.Read(b)
	return b
}

// randRead fills b with random bytes.
func randRead(b []byte) (int, error) { return rand.Read(b) }

func randByte() byte {
	var b [1]byte
	_, _ = rand.Read(b[:])
	return b[0]
}

// heartbeatInterval returns a randomized heartbeat period.
func heartbeatInterval() time.Duration {
	return heartbeatMin + time.Duration(randByte()%200)*100*time.Millisecond
}

// ValidatePSK rejects weak secrets.
func ValidatePSK(psk PSK) error {
	if len(psk) < 16 {
		return fmt.Errorf("PSK too short (%d bytes; use at least 16)", len(psk))
	}
	return nil
}
