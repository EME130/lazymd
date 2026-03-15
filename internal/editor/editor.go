package editor

import (
	"github.com/EME130/lazymd/internal/buffer"
)

// Mode represents the editor's current mode.
type Mode int

const (
	ModeNormal Mode = iota
	ModeInsert
	ModeCommand
)

// String returns the mode name.
func (m Mode) String() string {
	switch m {
	case ModeNormal:
		return "NORMAL"
	case ModeInsert:
		return "INSERT"
	case ModeCommand:
		return "COMMAND"
	default:
		return "UNKNOWN"
	}
}

// PluginSummary describes a plugin (avoids circular import with plugins package).
type PluginSummary struct {
	Name        string
	Version     string
	Description string
}

// CommandSummary describes a plugin command (avoids circular import with plugins package).
type CommandSummary struct {
	Name        string
	Description string
	PluginName  string
}

// CommandExecutor is an interface for plugin command dispatch.
// This avoids circular imports between editor and plugins packages.
type CommandExecutor interface {
	ExecuteCommand(name string, ed PluginEditor, args string) bool
	Broadcast(eventType string, ed PluginEditor)
	ListPlugins() []PluginSummary
	ListCommands() []CommandSummary
}

// PluginEditor is the interface plugins use to access editor state.
type PluginEditor interface {
	Buffer() *buffer.Buffer
	CursorRow() int
	CursorCol() int
	FilePath() string
	EditorMode() Mode
	SetStatus(msg string, isError bool)
	SetCursorRow(row int)
	SetCursorCol(col int)
}

// EditorModel is the core editor state.
type EditorModel struct {
	Buf        *buffer.Buffer
	Row        int
	Col        int
	DesiredCol int
	ScrollRow  int
	ScrollCol  int
	ViewWidth  int
	ViewHeight int
	mode       Mode
	CmdBuf     string
	File       string
	Status     StatusMsg
	ShouldQuit bool
	Count      int
	PendingOp  rune
	CmdExec    CommandExecutor
	changed    bool
}

// StatusMsg holds the status bar message.
type StatusMsg struct {
	Text    string
	IsError bool
}

// New creates a new EditorModel.
func New(buf *buffer.Buffer) *EditorModel {
	return &EditorModel{
		Buf:        buf,
		ViewWidth:  80,
		ViewHeight: 24,
	}
}

// Mode returns the current mode.
func (e *EditorModel) Mode() Mode { return e.mode }

// SetMode sets the editor mode.
func (e *EditorModel) SetMode(m Mode) { e.mode = m }

// BufferChanged returns true if the buffer was modified since last check.
func (e *EditorModel) BufferChanged() bool {
	c := e.changed
	e.changed = false
	return c
}

// MarkChanged marks the buffer as changed.
func (e *EditorModel) MarkChanged() { e.changed = true }

// -- PluginEditor interface implementation --

func (e *EditorModel) Buffer() *buffer.Buffer { return e.Buf }
func (e *EditorModel) CursorRow() int         { return e.Row }
func (e *EditorModel) CursorCol() int         { return e.Col }
func (e *EditorModel) FilePath() string       { return e.File }
func (e *EditorModel) EditorMode() Mode       { return e.mode }

func (e *EditorModel) SetStatus(msg string, isError bool) {
	e.Status = StatusMsg{Text: msg, IsError: isError}
}

func (e *EditorModel) SetCursorRow(row int) {
	if row >= 0 && row < e.Buf.LineCount() {
		e.Row = row
	}
}

func (e *EditorModel) SetCursorCol(col int) {
	if col >= 0 {
		e.Col = col
	}
}

// HandleKey dispatches a key event to the current mode handler.
func (e *EditorModel) HandleKey(key Key) {
	switch e.mode {
	case ModeNormal:
		e.handleNormal(key)
	case ModeInsert:
		e.handleInsert(key)
	case ModeCommand:
		e.handleCommand(key)
	}
}

// OpenFile loads a file into the buffer.
func (e *EditorModel) OpenFile(path string) error {
	if err := e.Buf.LoadFile(path); err != nil {
		return err
	}
	e.File = path
	e.Row = 0
	e.Col = 0
	e.ScrollRow = 0
	e.SetStatus("File opened", false)
	if e.CmdExec != nil {
		e.CmdExec.Broadcast("file_open", e)
	}
	return nil
}

// Save writes the buffer to the current file path.
func (e *EditorModel) Save() error {
	if e.File == "" {
		e.SetStatus("No filename. Use :w <filename>", true)
		return nil
	}
	if err := e.Buf.SaveFile(e.File); err != nil {
		return err
	}
	e.SetStatus("File saved", false)
	if e.CmdExec != nil {
		e.CmdExec.Broadcast("file_save", e)
	}
	return nil
}

// SaveAs writes the buffer to a specified path.
func (e *EditorModel) SaveAs(path string) error {
	if err := e.Buf.SaveFile(path); err != nil {
		return err
	}
	e.File = path
	e.SetStatus("File saved", false)
	return nil
}

// Key represents a keyboard input.
type Key struct {
	Type KeyType
	Char rune
	Ctrl bool
}

// KeyType identifies special keys.
type KeyType int

const (
	KeyChar KeyType = iota
	KeyEscape
	KeyEnter
	KeyBackspace
	KeyDelete
	KeyTab
	KeyUp
	KeyDown
	KeyLeft
	KeyRight
	KeyHome
	KeyEnd
	KeyPageUp
	KeyPageDown
)

// CharKey creates a Key for a character.
func CharKey(c rune) Key { return Key{Type: KeyChar, Char: c} }

// CtrlKey creates a Key for a ctrl+char combination.
func CtrlKey(c rune) Key { return Key{Type: KeyChar, Char: c, Ctrl: true} }

// SpecialKey creates a Key for a special key.
func SpecialKey(t KeyType) Key { return Key{Type: t} }
