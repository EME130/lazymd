package agent

import (
	"testing"

	"github.com/EME130/lazymd/internal/buffer"
	"github.com/EME130/lazymd/internal/editor"
)

type mockEditor struct {
	buf    *buffer.Buffer
	row    int
	col    int
	file   string
	status string
	isErr  bool
}

func (m *mockEditor) Buffer() *buffer.Buffer    { return m.buf }
func (m *mockEditor) CursorRow() int             { return m.row }
func (m *mockEditor) CursorCol() int             { return m.col }
func (m *mockEditor) FilePath() string            { return m.file }
func (m *mockEditor) EditorMode() editor.Mode     { return editor.ModeNormal }
func (m *mockEditor) SetStatus(msg string, e bool) { m.status = msg; m.isErr = e }
func (m *mockEditor) SetCursorRow(row int)         { m.row = row }
func (m *mockEditor) SetCursorCol(col int)         { m.col = col }

func TestPluginInitDeinit(t *testing.T) {
	p := NewPlugin()
	if p.backend != nil {
		t.Error("expected nil backend")
	}
	if p.connected {
		t.Error("expected not connected")
	}
}

func TestPluginSetBackend(t *testing.T) {
	p := NewPlugin()
	b := NewMcpBackend()
	p.SetBackend(b)
	if p.backend == nil {
		t.Error("expected backend to be set")
	}
}

func TestPluginTickNoBackend(t *testing.T) {
	p := NewPlugin()
	// Should not panic with no backend
	p.Tick()
}

func TestPluginTickNotConnected(t *testing.T) {
	p := NewPlugin()
	p.SetBackend(NewMcpBackend())
	// Should not panic when not connected
	p.Tick()
}

func TestMcpBackendConnect(t *testing.T) {
	b := NewMcpBackend()
	if b.IsConnected() {
		t.Error("expected not connected")
	}

	b.Connect(Config{})
	if !b.IsConnected() {
		t.Error("expected connected")
	}

	b.Disconnect()
	if b.IsConnected() {
		t.Error("expected disconnected")
	}
}

func TestMcpBackendInfo(t *testing.T) {
	b := NewMcpBackend()
	info := b.Info()
	if info.Name != "mcp" {
		t.Errorf("expected mcp, got %s", info.Name)
	}
	if info.Transport != TransportStdio {
		t.Errorf("expected stdio transport")
	}
}

func TestWebSocketBackendInfo(t *testing.T) {
	b := NewWebSocketBackend()
	info := b.Info()
	if info.Name != "websocket" {
		t.Errorf("expected websocket, got %s", info.Name)
	}
	if info.Transport != TransportWebSocket {
		t.Errorf("expected websocket transport")
	}
}

func TestWebSocketBackendNotConnected(t *testing.T) {
	b := NewWebSocketBackend()
	if b.IsConnected() {
		t.Error("expected not connected")
	}

	cmd, err := b.PollCommand()
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if cmd != nil {
		t.Error("expected nil command")
	}
}

func TestConfigDefaults(t *testing.T) {
	c := Config{}
	if c.Transport != TransportStdio {
		t.Errorf("expected stdio transport, got %d", c.Transport)
	}
	if c.Model != "" {
		t.Error("expected empty model")
	}
}

func TestNotifyEventNoBackend(t *testing.T) {
	p := NewPlugin()
	ed := &mockEditor{buf: buffer.New(), file: "test.md"}
	// Should not panic
	p.NotifyEvent(EventFileOpened, ed)
}
