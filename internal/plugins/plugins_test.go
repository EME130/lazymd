package plugins

import (
	"testing"

	"github.com/EME130/lazymd/internal/buffer"
	"github.com/EME130/lazymd/internal/editor"
)

// mockEditor implements editor.PluginEditor for testing.
type mockEditor struct {
	buf    *buffer.Buffer
	row    int
	col    int
	file   string
	status string
	isErr  bool
}

func newMockEditor(content string) *mockEditor {
	buf := buffer.New()
	if content != "" {
		buf.InsertString(0, content)
	}
	return &mockEditor{buf: buf, file: "test.md"}
}

func (m *mockEditor) Buffer() *buffer.Buffer       { return m.buf }
func (m *mockEditor) CursorRow() int               { return m.row }
func (m *mockEditor) CursorCol() int               { return m.col }
func (m *mockEditor) FilePath() string             { return m.file }
func (m *mockEditor) EditorMode() editor.Mode      { return editor.ModeNormal }
func (m *mockEditor) SetStatus(msg string, e bool) { m.status = msg; m.isErr = e }
func (m *mockEditor) SetCursorRow(row int)         { m.row = row }
func (m *mockEditor) SetCursorCol(col int)         { m.col = col }

func TestAllPluginsRegistered(t *testing.T) {
	all := AllPlugins()
	if len(all) != 66 {
		t.Errorf("expected 66 plugins, got %d", len(all))
	}
}

func TestPluginManagerBasics(t *testing.T) {
	pm := NewManager()
	ed := newMockEditor("")

	pm.Register(&WordCountPlugin{}, ed)

	if pm.PluginCount() != 1 {
		t.Errorf("expected 1 plugin, got %d", pm.PluginCount())
	}

	if !pm.ExecuteCommand("wc", ed, "") {
		t.Error("expected wc command to be found")
	}
	if ed.status == "" {
		t.Error("expected status message after wc")
	}

	if pm.ExecuteCommand("nonexistent", ed, "") {
		t.Error("nonexistent command should not be found")
	}
}

func TestWordCountPlugin(t *testing.T) {
	ed := newMockEditor("Hello world\nFoo bar baz\n")
	p := &WordCountPlugin{}
	info := p.Info()
	if info.Name != "word-count" {
		t.Errorf("expected word-count, got %s", info.Name)
	}

	cmds := p.Commands()
	if len(cmds) != 1 || cmds[0].Name != "wc" {
		t.Error("expected wc command")
	}

	cmds[0].Handler(ed, "")
	if ed.status == "" {
		t.Error("expected status message")
	}
}

func TestKanbanPlugin(t *testing.T) {
	ed := newMockEditor("")
	p := &KanbanPlugin{}
	cmds := p.Commands()
	if len(cmds) != 3 {
		t.Errorf("expected 3 kanban commands, got %d", len(cmds))
	}

	// kanban.new inserts template
	for _, cmd := range cmds {
		if cmd.Name == "kanban.new" {
			cmd.Handler(ed, "")
			content := ed.buf.Content()
			if len(content) == 0 {
				t.Error("expected kanban template to be inserted")
			}
			break
		}
	}
}

func TestEmojiPlugin(t *testing.T) {
	ed := newMockEditor("")
	p := &EmojiPlugin{}
	cmds := p.Commands()

	// Insert a known emoji
	for _, cmd := range cmds {
		if cmd.Name == "emoji" {
			cmd.Handler(ed, "smile")
			content := ed.buf.Content()
			if len(content) == 0 {
				t.Error("expected emoji to be inserted")
			}
			break
		}
	}
}

func TestBookmarksPlugin(t *testing.T) {
	ed := newMockEditor("Line 1\nLine 2\nLine 3\n")
	ed.row = 2

	p := &BookmarksPlugin{}
	cmds := p.Commands()

	// Set bookmark 'a'
	for _, cmd := range cmds {
		if cmd.Name == "bm.set" {
			cmd.Handler(ed, "a")
			break
		}
	}

	// Jump to bookmark 'a'
	ed.row = 0
	for _, cmd := range cmds {
		if cmd.Name == "bm.go" {
			cmd.Handler(ed, "a")
			break
		}
	}
	if ed.row != 2 {
		t.Errorf("expected row 2 after bookmark jump, got %d", ed.row)
	}
}

func TestRegisterAll(t *testing.T) {
	pm := NewManager()
	ed := newMockEditor("")
	RegisterAll(pm, ed)

	if pm.PluginCount() != 66 {
		t.Errorf("expected 66 plugins after RegisterAll, got %d", pm.PluginCount())
	}

	// Verify we have a good number of commands
	cmds := pm.AllCommands()
	if len(cmds) < 100 {
		t.Errorf("expected at least 100 commands, got %d", len(cmds))
	}
}

func TestPluginInfoUnique(t *testing.T) {
	all := AllPlugins()
	names := make(map[string]bool)
	for _, p := range all {
		name := p.Info().Name
		if names[name] {
			t.Errorf("duplicate plugin name: %s", name)
		}
		names[name] = true
	}
}

func TestListPlugins(t *testing.T) {
	pm := NewManager()
	ed := newMockEditor("")
	pm.Register(&WordCountPlugin{}, ed)
	pm.Register(&KanbanPlugin{}, ed)

	summaries := pm.ListPlugins()
	if len(summaries) != 2 {
		t.Fatalf("expected 2 plugin summaries, got %d", len(summaries))
	}
	if summaries[0].Name != "word-count" {
		t.Errorf("expected first plugin name 'word-count', got %q", summaries[0].Name)
	}
}

func TestListCommands(t *testing.T) {
	pm := NewManager()
	ed := newMockEditor("")
	pm.Register(&KanbanPlugin{}, ed)

	cmds := pm.ListCommands()
	if len(cmds) != 3 {
		t.Fatalf("expected 3 command summaries, got %d", len(cmds))
	}
	for _, cmd := range cmds {
		if cmd.PluginName != "kanban" {
			t.Errorf("expected PluginName 'kanban', got %q", cmd.PluginName)
		}
	}
}
