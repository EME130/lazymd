package agent

import (
	"github.com/EME130/lazymd/internal/editor"
)

// Transport identifies the agent communication transport.
type Transport int

const (
	TransportStdio     Transport = iota
	TransportWebSocket
	TransportHTTP
)

// Config holds agent connection configuration.
type Config struct {
	Model     string
	APIKey    string
	Endpoint  string
	Transport Transport
}

// EditorContext holds current editor state for the agent.
type EditorContext struct {
	FilePath  string `json:"file_path,omitempty"`
	Content   string `json:"content,omitempty"`
	CursorRow int    `json:"cursor_row"`
	CursorCol int    `json:"cursor_col"`
	Mode      string `json:"mode"`
}

// EventType identifies agent event types.
type EventType string

const (
	EventFileOpened     EventType = "file_opened"
	EventFileSaved      EventType = "file_saved"
	EventContentChanged EventType = "content_changed"
	EventModeChanged    EventType = "mode_changed"
	EventCursorMoved    EventType = "cursor_moved"
)

// Event is an editor event notification for the agent.
type Event struct {
	Type     EventType `json:"type"`
	FilePath string    `json:"file_path,omitempty"`
	Content  string    `json:"content,omitempty"`
	Mode     string    `json:"mode,omitempty"`
}

// CommandType identifies agent command types.
type CommandType string

const (
	CmdInsertText     CommandType = "insert_text"
	CmdDeleteRange    CommandType = "delete_range"
	CmdReplaceSection CommandType = "replace_section"
	CmdOpenFile       CommandType = "open_file"
	CmdSaveFile       CommandType = "save_file"
	CmdRunCommand     CommandType = "run_command"
	CmdRequestContext CommandType = "request_context"
)

// Command is a command from the agent to the editor.
type Command struct {
	Type      CommandType `json:"type"`
	Text      string      `json:"text,omitempty"`
	Line      int         `json:"line,omitempty"`
	Col       int         `json:"col,omitempty"`
	StartLine int         `json:"start_line,omitempty"`
	EndLine   int         `json:"end_line,omitempty"`
	Heading   string      `json:"heading,omitempty"`
	Path      string      `json:"path,omitempty"`
	Command   string      `json:"command,omitempty"`
}

// BackendInfo describes an agent backend.
type BackendInfo struct {
	Name      string
	AgentName string
	Transport Transport
}

// Backend is the interface for agent communication backends.
type Backend interface {
	Connect(config Config) error
	Disconnect()
	SendContext(ctx EditorContext) error
	SendEvent(event Event) error
	PollCommand() (*Command, error)
	IsConnected() bool
	Info() BackendInfo
}

// Plugin manages agent backend lifecycle and editor integration.
type Plugin struct {
	backend   Backend
	editor    editor.PluginEditor
	connected bool
}

// NewPlugin creates a new agent plugin.
func NewPlugin() *Plugin {
	return &Plugin{}
}

// SetBackend sets the active agent backend.
func (p *Plugin) SetBackend(b Backend) {
	if p.backend != nil && p.backend.IsConnected() {
		p.backend.Disconnect()
	}
	p.backend = b
}

// Connect connects to the agent via the active backend.
func (p *Plugin) Connect(config Config) error {
	if p.backend == nil {
		return nil
	}
	if err := p.backend.Connect(config); err != nil {
		return err
	}
	p.connected = true
	return nil
}

// Disconnect disconnects from the agent.
func (p *Plugin) Disconnect() {
	if p.backend != nil {
		p.backend.Disconnect()
	}
	p.connected = false
}

// Tick polls for commands and executes them.
func (p *Plugin) Tick() {
	if p.backend == nil || !p.backend.IsConnected() || p.editor == nil {
		return
	}

	cmd, err := p.backend.PollCommand()
	if err != nil || cmd == nil {
		return
	}
	p.executeCommand(cmd)
}

func (p *Plugin) executeCommand(cmd *Command) {
	switch cmd.Type {
	case CmdInsertText:
		if cmd.Text != "" {
			buf := p.editor.Buffer()
			pos := buf.PosToOffset(cmd.Line, cmd.Col)
			buf.InsertString(pos, cmd.Text)
		}
	case CmdOpenFile:
		// Would need access to editor.OpenFile — deferred to full integration
	case CmdRequestContext:
		p.sendCurrentContext()
	}
}

func (p *Plugin) sendCurrentContext() {
	if p.backend == nil || !p.backend.IsConnected() || p.editor == nil {
		return
	}
	p.backend.SendContext(EditorContext{
		FilePath:  p.editor.FilePath(),
		CursorRow: p.editor.CursorRow(),
		CursorCol: p.editor.CursorCol(),
		Mode:      p.editor.EditorMode().String(),
	})
}

// NotifyEvent sends an editor event to the agent.
func (p *Plugin) NotifyEvent(eventType EventType, ed editor.PluginEditor) {
	if p.backend == nil || !p.backend.IsConnected() {
		return
	}
	event := Event{
		Type:     eventType,
		FilePath: ed.FilePath(),
		Mode:     ed.EditorMode().String(),
	}
	p.backend.SendEvent(event)
}
