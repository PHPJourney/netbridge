package obfstransport

// DNS-53 transport shape: tunnel frames are carried inside DNS messages over
// TCP 53, so the traffic looks like DNS zone-transfer / server-to-server
// synchronization rather than a VPN tunnel.
//
// Each transport message is a standard DNS message:
//
//	header:      random ID; QR=0 (query) from client, QR=1 (response) from server
//	question:    fake domain (e.g. "a1b2c3.example.com") + QTYPE=TXT
//	answer:      one TXT record; rdata = frame bytes (split into <=255-byte
//	             character-strings per RFC 1035)
//
// The frame inside the TXT rdata is the regular protocol frame
// (magic/type/len/padlen/payload/padding), so mux/auth logic is shared with
// the TLS transport.

import (
	"encoding/binary"
	"fmt"
	"io"
	"math/rand"
	"net"
	"time"
)

// dnsTypeTXT is the resource record type for TXT (16).
const dnsTypeTXT = 16

// encodeDNSFrame wraps one protocol frame in a DNS message. qr=true marks the
// message as a response, false as a query.
func encodeDNSFrame(frame []byte, qr bool) []byte {
	// header (12B)
	id := uint16(rand.Intn(65536))
	flags := uint16(0x0100) // standard query, RD=1
	if qr {
		flags = 0x8180 // standard response, QR=1 RD=1 RA=1
	}
	msg := make([]byte, 12)
	binary.BigEndian.PutUint16(msg[0:2], id)
	binary.BigEndian.PutUint16(msg[2:4], flags)
	binary.BigEndian.PutUint16(msg[4:6], 1) // QDCOUNT
	binary.BigEndian.PutUint16(msg[6:8], 1) // ANCOUNT

	// question: fake domain + TXT + IN
	qname := fakeQName()
	msg = append(msg, qname...)
	msg = binary.BigEndian.AppendUint16(msg, dnsTypeTXT)
	msg = binary.BigEndian.AppendUint16(msg, 1) // QCLASS IN

	// answer: name pointer to question (0xC00C), TXT, IN, TTL=0
	msg = binary.BigEndian.AppendUint16(msg, 0xC00C)
	msg = binary.BigEndian.AppendUint16(msg, dnsTypeTXT)
	msg = binary.BigEndian.AppendUint16(msg, 1)
	msg = binary.BigEndian.AppendUint32(msg, 0)
	// rdata: split frame into <=255-byte character-strings
	rdata := dnsTXTEncode(frame)
	msg = binary.BigEndian.AppendUint16(msg, uint16(len(rdata)))
	msg = append(msg, rdata...)
	return msg
}

// decodeDNSFrame extracts the protocol frame from a DNS message's TXT rdata.
func decodeDNSFrame(msg []byte) ([]byte, error) {
	if len(msg) < 12 {
		return nil, fmt.Errorf("dns message too short")
	}
	qdcount := binary.BigEndian.Uint16(msg[4:6])
	ancount := binary.BigEndian.Uint16(msg[6:8])
	pos := 12
	for i := 0; i < int(qdcount); i++ {
		pos = skipDNSName(msg, pos)
		pos += 4 // QTYPE + QCLASS
		if pos > len(msg) {
			return nil, fmt.Errorf("dns question overrun")
		}
	}
	for i := 0; i < int(ancount); i++ {
		pos = skipDNSName(msg, pos)
		if pos+10 > len(msg) {
			return nil, fmt.Errorf("dns answer overrun")
		}
		rdlength := int(binary.BigEndian.Uint16(msg[pos+8 : pos+10]))
		rdata := msg[pos+10 : pos+10+rdlength]
		if pos+10+rdlength > len(msg) {
			return nil, fmt.Errorf("dns rdata overrun")
		}
		if rdlength > 0 {
			return dnsTXTDecode(rdata), nil
		}
		return nil, nil
	}
	return nil, nil
}

// dnsTXTEncode splits data into RFC 1035 character-strings (1B len + bytes).
func dnsTXTEncode(data []byte) []byte {
	var out []byte
	for len(data) > 0 {
		n := len(data)
		if n > 255 {
			n = 255
		}
		out = append(out, byte(n))
		out = append(out, data[:n]...)
		data = data[n:]
	}
	return out
}

// dnsTXTDecode joins character-strings back into one byte slice.
func dnsTXTDecode(rdata []byte) []byte {
	var out []byte
	for len(rdata) > 0 {
		n := int(rdata[0])
		if n > len(rdata)-1 {
			n = len(rdata) - 1
		}
		out = append(out, rdata[1:1+n]...)
		rdata = rdata[1+n:]
	}
	return out
}

// fakeQName builds a random-looking domain name (three labels + .net/.com).
func fakeQName() []byte {
	labels := make([]string, 3)
	for i := range labels {
		l := 4 + rand.Intn(8)
		b := make([]byte, l)
		for j := range b {
			b[j] = byte('a' + rand.Intn(26))
		}
		labels[i] = string(b)
	}
	tld := "net"
	if rand.Intn(2) == 0 {
		tld = "com"
	}
	domain := labels[0] + "." + labels[1] + "." + labels[2] + "." + tld
	out := make([]byte, 0, len(domain)+2)
	for _, part := range splitLabels(domain) {
		out = append(out, byte(len(part)))
		out = append(out, part...)
	}
	return append(out, 0)
}

func splitLabels(domain string) []string {
	var parts []string
	start := 0
	for i := 0; i < len(domain); i++ {
		if domain[i] == '.' {
			parts = append(parts, domain[start:i])
			start = i + 1
		}
	}
	parts = append(parts, domain[start:])
	return parts
}

// skipDNSName skips a (possibly compressed) DNS name starting at pos.
func skipDNSName(msg []byte, pos int) int {
	for pos < len(msg) {
		l := int(msg[pos])
		if l == 0 {
			return pos + 1
		}
		if l&0xC0 == 0xC0 {
			return pos + 2 // compression pointer
		}
		pos += 1 + l
	}
	return pos
}

// dnsFrameConn is a net.Conn wrapper that transparently encodes/decodes
// protocol frames as DNS messages. It implements the mux wire interface
// via encodeDNSFrame/decodeDNSFrame around the raw TCP stream.
type dnsFrameConn struct {
	conn net.Conn
	qr   bool // true on the server side (we answer), false on client (we query)
}

// writeFrame encodes one protocol frame as a DNS message and writes it.
func (d *dnsFrameConn) writeFrame(frame []byte) error {
	msg := encodeDNSFrame(frame, d.qr)
	// DNS over TCP framing: 2-byte length prefix per RFC 1035 §4.2.2.
	_ = d.conn.SetWriteDeadline(time.Now().Add(15 * time.Second))
	prefix := make([]byte, 2, 2+len(msg))
	binary.BigEndian.PutUint16(prefix, uint16(len(msg)))
	if _, err := d.conn.Write(prefix); err != nil {
		return err
	}
	_, err := d.conn.Write(msg)
	return err
}

// readFrame reads one DNS message and decodes the protocol frame inside.
func (d *dnsFrameConn) readFrame() ([]byte, error) {
	_ = d.conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	var prefix [2]byte
	if _, err := io.ReadFull(d.conn, prefix[:]); err != nil {
		return nil, err
	}
	n := int(binary.BigEndian.Uint16(prefix[:]))
	if n <= 0 || n > 65535 {
		return nil, fmt.Errorf("bad dns message length %d", n)
	}
	msg := make([]byte, n)
	if _, err := io.ReadFull(d.conn, msg); err != nil {
		return nil, err
	}
	frame, err := decodeDNSFrame(msg)
	if err != nil {
		return nil, err
	}
	if len(frame) == 0 {
		return nil, fmt.Errorf("empty dns frame")
	}
	return frame, nil
}
