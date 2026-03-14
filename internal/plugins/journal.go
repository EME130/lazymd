package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type JournalPlugin struct{}

func (p *JournalPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "journal",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Chronological journal entries",
	}
}

func (p *JournalPlugin) Init(ed editor.PluginEditor) {}

func (p *JournalPlugin) OnEvent(event *PluginEvent) {}

func (p *JournalPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "journal", Description: "Show recent entries", Handler: journalHandler},
		{Name: "journal.new", Description: "Create new entry", Handler: journalNewHandler},
		{Name: "journal.timestamp", Description: "Insert timestamp", Handler: journalTimestampHandler},
	}
}

func journalHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Journal: recent entries", false)
}

func journalNewHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "## Journal Entry\n\n")
	ed.SetStatus("Journal entry created", false)
}

func journalTimestampHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "2024-01-01 12:00")
	ed.SetStatus("Timestamp inserted", false)
}
