package web

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"strings"

	"github.com/EME130/lazymd/internal/buffer"
	"github.com/EME130/lazymd/internal/mcp"
)

// Server is the LazyMD web server (HTTP + WebSocket).
type Server struct {
	buf      *buffer.Buffer
	port     int
	filePath string
}

// NewServer creates a new web server.
func NewServer(buf *buffer.Buffer, port int) *Server {
	return &Server{buf: buf, port: port}
}

// SetFilePath sets the file path for preloading.
func (s *Server) SetFilePath(path string) {
	s.filePath = path
}

// Run starts the HTTP server.
func (s *Server) Run() error {
	mux := http.NewServeMux()
	mux.HandleFunc("/", s.handleIndex)
	mux.HandleFunc("/health", s.handleHealth)
	mux.HandleFunc("/ws", s.handleWebSocket)

	addr := fmt.Sprintf(":%d", s.port)
	fmt.Fprintf(os.Stderr, "LazyMD web server listening on http://localhost%s\n", addr)
	return http.ListenAndServe(addr, corsMiddleware(mux))
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" && r.URL.Path != "/index.html" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html")
	fmt.Fprint(w, `<!DOCTYPE html>
<html><head><title>LazyMD</title>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
</head><body>
<h1>LazyMD web server</h1>
<p>Connect your editor frontend to ws://localhost on this port.</p>
<p>Status: <span id="status">Checking...</span></p>
<script>
const ws = new WebSocket(`+"`"+`ws://${location.host}/ws`+"`"+`);
ws.onopen = () => document.getElementById('status').textContent = 'Connected';
ws.onclose = () => document.getElementById('status').textContent = 'Disconnected';
</script>
</body></html>`)
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	// Hijack the connection for WebSocket
	hj, ok := w.(http.Hijacker)
	if !ok {
		http.Error(w, "WebSocket upgrade not supported", http.StatusInternalServerError)
		return
	}

	conn, bufrw, err := hj.Hijack()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Complete WebSocket handshake
	key := r.Header.Get("Sec-WebSocket-Key")
	if key == "" {
		conn.Close()
		return
	}
	response := UpgradeResponse(key)
	bufrw.WriteString(response)
	bufrw.Flush()

	// Handle WebSocket messages
	ws := NewWSConn(conn)
	defer ws.Close()

	// Create an MCP server for tool dispatch
	mcpSrv := mcp.New(s.buf)
	if s.filePath != "" {
		mcpSrv.SetFilePath(s.filePath)
	}

	s.wsLoop(ws, mcpSrv, conn)
}

func (s *Server) wsLoop(ws *WSConn, _ *mcp.LazyMDServer, _ net.Conn) {
	for {
		opcode, payload, err := ws.ReadFrame()
		if err != nil {
			return
		}
		if opcode == OpClose {
			return
		}
		if opcode != OpText {
			continue
		}

		// Parse JSON-RPC request
		resp := s.processJSONRPC(payload)
		if resp != nil {
			ws.SendText(resp)
		}
	}
}

func (s *Server) processJSONRPC(message []byte) []byte {
	var req struct {
		JSONRPC string          `json:"jsonrpc"`
		Method  string          `json:"method"`
		ID      json.RawMessage `json:"id"`
		Params  json.RawMessage `json:"params"`
	}
	if err := json.Unmarshal(message, &req); err != nil {
		return nil
	}

	id := string(req.ID)
	if id == "" {
		id = "1"
	}

	switch req.Method {
	case "initialize":
		return []byte(fmt.Sprintf(
			`{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"LazyMD","version":"0.1.0"}}}`,
			id))
	case "tools/list":
		return []byte(fmt.Sprintf(
			`{"jsonrpc":"2.0","id":%s,"result":{"tools":[]}}`, id))
	case "read_document":
		content := s.buf.Content()
		escaped := strings.ReplaceAll(content, `\`, `\\`)
		escaped = strings.ReplaceAll(escaped, `"`, `\"`)
		escaped = strings.ReplaceAll(escaped, "\n", `\n`)
		return []byte(fmt.Sprintf(
			`{"jsonrpc":"2.0","id":%s,"result":{"content":[{"type":"text","text":"%s"}]}}`,
			id, escaped))
	}

	return nil
}
