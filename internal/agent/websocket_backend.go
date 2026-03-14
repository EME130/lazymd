package agent

import (
	"encoding/json"
	"fmt"
	"net"
	"strings"
)

// WebSocketBackend implements Backend for WebSocket transport.
type WebSocketBackend struct {
	connected bool
	endpoint  string
	conn      net.Conn
}

// NewWebSocketBackend creates a new WebSocket backend.
func NewWebSocketBackend() *WebSocketBackend {
	return &WebSocketBackend{}
}

func (b *WebSocketBackend) Connect(config Config) error {
	endpoint := config.Endpoint
	if endpoint == "" {
		return fmt.Errorf("missing endpoint")
	}

	// Parse host:port
	host := endpoint
	port := "8080"

	host = strings.TrimPrefix(host, "ws://")
	host = strings.TrimPrefix(host, "wss://")

	if idx := strings.LastIndex(host, ":"); idx >= 0 {
		port = host[idx+1:]
		host = host[:idx]
	}

	// TCP connect
	conn, err := net.Dial("tcp", host+":"+port)
	if err != nil {
		return fmt.Errorf("connection failed: %w", err)
	}
	b.conn = conn

	// WebSocket handshake
	handshake := fmt.Sprintf(
		"GET / HTTP/1.1\r\nHost: %s:%s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n",
		host, port)
	if _, err := conn.Write([]byte(handshake)); err != nil {
		conn.Close()
		return err
	}

	// Read handshake response
	buf := make([]byte, 1024)
	n, err := conn.Read(buf)
	if err != nil {
		conn.Close()
		return err
	}
	if !strings.HasPrefix(string(buf[:n]), "HTTP/1.1 101") {
		conn.Close()
		return fmt.Errorf("WebSocket handshake failed")
	}

	b.endpoint = endpoint
	b.connected = true
	return nil
}

func (b *WebSocketBackend) Disconnect() {
	if b.conn != nil {
		// Send close frame
		closeFrame := []byte{0x88, 0x80, 0x00, 0x00, 0x00, 0x00}
		b.conn.Write(closeFrame)
		b.conn.Close()
		b.conn = nil
	}
	b.connected = false
}

func (b *WebSocketBackend) SendContext(ctx EditorContext) error {
	if !b.connected {
		return nil
	}
	msg := map[string]any{
		"jsonrpc": "2.0",
		"method":  "editor/context",
		"params":  ctx,
	}
	return b.sendJSON(msg)
}

func (b *WebSocketBackend) SendEvent(event Event) error {
	if !b.connected {
		return nil
	}
	method := "editor/" + strings.ReplaceAll(string(event.Type), "_", "")
	msg := map[string]any{
		"jsonrpc": "2.0",
		"method":  method,
		"params":  event,
	}
	return b.sendJSON(msg)
}

func (b *WebSocketBackend) PollCommand() (*Command, error) {
	if !b.connected || b.conn == nil {
		return nil, nil
	}
	// Non-blocking read isn't practical here — would need goroutine.
	return nil, nil
}

func (b *WebSocketBackend) IsConnected() bool {
	return b.connected
}

func (b *WebSocketBackend) Info() BackendInfo {
	return BackendInfo{
		Name:      "websocket",
		Transport: TransportWebSocket,
	}
}

func (b *WebSocketBackend) sendJSON(msg any) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}
	return b.sendFrame(data)
}

func (b *WebSocketBackend) sendFrame(payload []byte) error {
	if b.conn == nil {
		return fmt.Errorf("not connected")
	}

	// Build masked text frame (client must mask per RFC 6455)
	header := []byte{0x81} // FIN + text opcode
	pLen := len(payload)

	if pLen < 126 {
		header = append(header, byte(pLen)|0x80) // mask bit set
	} else if pLen < 65536 {
		header = append(header, 126|0x80)
		header = append(header, byte(pLen>>8), byte(pLen&0xFF))
	} else {
		header = append(header, 127|0x80)
		for i := 7; i >= 0; i-- {
			header = append(header, byte((pLen>>(i*8))&0xFF))
		}
	}

	// Masking key
	mask := [4]byte{0x37, 0xfa, 0x21, 0x3d}
	header = append(header, mask[:]...)

	if _, err := b.conn.Write(header); err != nil {
		return err
	}

	// Masked payload
	masked := make([]byte, len(payload))
	for i, b := range payload {
		masked[i] = b ^ mask[i%4]
	}
	_, err := b.conn.Write(masked)
	return err
}
