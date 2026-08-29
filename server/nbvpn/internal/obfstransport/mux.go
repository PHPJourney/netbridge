package obfstransport

import (
	"crypto/tls"
	"encoding/binary"
	"sync"
)

// mux multiplexes UDP (WireGuard) and TCP forwarding traffic over one TLS
// stream. Frames are written under a lock; a single read loop dispatches.
type mux struct {
	conn    *tls.Conn
	writeMu sync.Mutex

	// udpSink delivers FrameTypeWGDatagram payloads (e.g. to the WG socket).
	udpSink func(payload []byte) error
	// tcpSink delivers TCP frames: (frameType, connID, rest-of-payload).
	tcpSink func(ft byte, connID uint16, data []byte) error
}

// writeFrame serializes frame writes (TLS conn is not safe for concurrent use).
func (m *mux) writeFrame(ft byte, payload []byte) error {
	m.writeMu.Lock()
	defer m.writeMu.Unlock()
	return writeFrame(m.conn, ft, payload)
}

// readLoop reads frames until the stream fails; it calls onClose when done.
func (m *mux) readLoop(onClose func()) {
	defer onClose()
	for {
		f, err := readFrame(m.conn)
		if err != nil {
			return
		}
		switch f.Type {
		case FrameTypeWGDatagram:
			if m.udpSink != nil && len(f.Payload) > 0 {
				if err := m.udpSink(f.Payload); err != nil {
					return
				}
			}
		case FrameTypeTCPData, FrameTypeTCPConnect, FrameTypeTCPClose:
			if m.tcpSink != nil {
				if len(f.Payload) < 2 {
					continue
				}
				connID := binary.BigEndian.Uint16(f.Payload[0:2])
				if err := m.tcpSink(f.Type, connID, f.Payload[2:]); err != nil {
					return
				}
			}
		case FrameTypeHeartbeat:
			// respond to keep the bidirectional pattern alive
			_ = m.writeFrame(FrameTypeHeartbeat, nil)
		default:
			// ignore unknown frames
		}
	}
}

// tcpFramePayload builds connID(2B) + data.
func tcpFramePayload(connID uint16, data []byte) []byte {
	out := make([]byte, 2+len(data))
	binary.BigEndian.PutUint16(out[0:2], connID)
	copy(out[2:], data)
	return out
}
