package web

import (
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"strings"
)

const wsMagic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

// Opcode represents a WebSocket frame opcode.
type Opcode byte

const (
	OpText   Opcode = 0x1
	OpBinary Opcode = 0x2
	OpClose  Opcode = 0x8
	OpPing   Opcode = 0x9
	OpPong   Opcode = 0xA
)

// WSConn wraps a net.Conn with WebSocket frame reading/writing.
type WSConn struct {
	conn   net.Conn
	closed bool
}

// NewWSConn creates a WebSocket connection wrapper.
func NewWSConn(conn net.Conn) *WSConn {
	return &WSConn{conn: conn}
}

// ComputeAcceptKey computes the Sec-WebSocket-Accept value per RFC 6455.
func ComputeAcceptKey(key string) string {
	h := sha1.New()
	h.Write([]byte(key))
	h.Write([]byte(wsMagic))
	return base64.StdEncoding.EncodeToString(h.Sum(nil))
}

// UpgradeResponse builds the HTTP 101 response for a WebSocket upgrade.
func UpgradeResponse(key string) string {
	accept := ComputeAcceptKey(key)
	return "HTTP/1.1 101 Switching Protocols\r\n" +
		"Upgrade: websocket\r\n" +
		"Connection: Upgrade\r\n" +
		"Sec-WebSocket-Accept: " + accept + "\r\n\r\n"
}

// ExtractWSKey extracts the Sec-WebSocket-Key from an HTTP request.
func ExtractWSKey(request string) string {
	for _, line := range strings.Split(request, "\r\n") {
		lower := strings.ToLower(line)
		if strings.HasPrefix(lower, "sec-websocket-key:") {
			return strings.TrimSpace(line[len("sec-websocket-key:"):])
		}
	}
	return ""
}

// IsUpgradeRequest checks if an HTTP request is a WebSocket upgrade.
func IsUpgradeRequest(request string) bool {
	for _, line := range strings.Split(request, "\r\n") {
		lower := strings.ToLower(line)
		if strings.HasPrefix(lower, "upgrade:") {
			val := strings.TrimSpace(lower[len("upgrade:"):])
			if val == "websocket" {
				return true
			}
		}
	}
	return false
}

// ReadFrame reads a WebSocket frame. Returns opcode and payload.
func (ws *WSConn) ReadFrame() (Opcode, []byte, error) {
	if ws.closed {
		return 0, nil, errors.New("connection closed")
	}

	// Read header (2 bytes)
	header := make([]byte, 2)
	if _, err := io.ReadFull(ws.conn, header); err != nil {
		return 0, nil, err
	}

	opcode := Opcode(header[0] & 0x0F)
	isMasked := (header[1] & 0x80) != 0
	payloadLen := uint64(header[1] & 0x7F)

	// Extended payload length
	if payloadLen == 126 {
		ext := make([]byte, 2)
		if _, err := io.ReadFull(ws.conn, ext); err != nil {
			return 0, nil, err
		}
		payloadLen = uint64(binary.BigEndian.Uint16(ext))
	} else if payloadLen == 127 {
		ext := make([]byte, 8)
		if _, err := io.ReadFull(ws.conn, ext); err != nil {
			return 0, nil, err
		}
		payloadLen = binary.BigEndian.Uint64(ext)
	}

	// Masking key
	var mask [4]byte
	if isMasked {
		if _, err := io.ReadFull(ws.conn, mask[:]); err != nil {
			return 0, nil, err
		}
	}

	// Payload
	if payloadLen > 1024*1024 {
		return 0, nil, errors.New("payload too large")
	}
	payload := make([]byte, payloadLen)
	if _, err := io.ReadFull(ws.conn, payload); err != nil {
		return 0, nil, err
	}

	// Unmask
	if isMasked {
		for i := range payload {
			payload[i] ^= mask[i%4]
		}
	}

	// Handle control frames
	switch opcode {
	case OpClose:
		ws.closed = true
		ws.sendFrame(OpClose, nil)
		return OpClose, nil, nil
	case OpPing:
		ws.sendFrame(OpPong, payload)
		return ws.ReadFrame() // read next real frame
	case OpPong:
		return ws.ReadFrame()
	}

	return opcode, payload, nil
}

// SendText sends a text frame.
func (ws *WSConn) SendText(payload []byte) error {
	return ws.sendFrame(OpText, payload)
}

func (ws *WSConn) sendFrame(opcode Opcode, payload []byte) error {
	if ws.closed && opcode != OpClose {
		return errors.New("connection closed")
	}

	// Header: FIN + opcode
	header := []byte{0x80 | byte(opcode)}

	// Server doesn't mask (per RFC 6455)
	pLen := len(payload)
	if pLen < 126 {
		header = append(header, byte(pLen))
	} else if pLen < 65536 {
		header = append(header, 126)
		ext := make([]byte, 2)
		binary.BigEndian.PutUint16(ext, uint16(pLen))
		header = append(header, ext...)
	} else {
		header = append(header, 127)
		ext := make([]byte, 8)
		binary.BigEndian.PutUint64(ext, uint64(pLen))
		header = append(header, ext...)
	}

	if _, err := ws.conn.Write(header); err != nil {
		return err
	}
	if len(payload) > 0 {
		if _, err := ws.conn.Write(payload); err != nil {
			return err
		}
	}
	return nil
}

// Close closes the WebSocket connection.
func (ws *WSConn) Close() {
	if !ws.closed {
		ws.sendFrame(OpClose, nil)
		ws.closed = true
	}
	ws.conn.Close()
}
