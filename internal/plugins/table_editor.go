package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type TableEditorPlugin struct{}

func (p *TableEditorPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "table-editor",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Markdown table creation and formatting",
	}
}

func (p *TableEditorPlugin) Init(ed editor.PluginEditor) {}

func (p *TableEditorPlugin) OnEvent(event *PluginEvent) {}

func (p *TableEditorPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "table", Description: "Insert table template", Handler: tableHandler},
		{Name: "table.fmt", Description: "Format table", Handler: tableFmtHandler},
		{Name: "table.add-row", Description: "Add table row", Handler: tableAddRowHandler},
	}
}

func tableHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	table := "| Header 1 | Header 2 |\n| -------- | -------- |\n| Cell 1   | Cell 2   |\n"
	buf.InsertString(offset, table)

	ed.SetStatus("Table inserted", false)
}

func tableFmtHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Formatting table...", false)
}

func tableAddRowHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	currentRow := ed.CursorRow()

	// Insert after current line
	if currentRow < buf.LineCount()-1 {
		offset := buf.PosToOffset(currentRow+1, 0)
		buf.InsertString(offset, "| | |\n")
	} else {
		// At end of buffer
		offset := buf.Length()
		buf.InsertString(offset, "\n| | |\n")
	}

	ed.SetStatus("Table row added", false)
}
