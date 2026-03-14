package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type AdmonitionsPlugin struct{}

func (p *AdmonitionsPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "admonitions",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Callout blocks (tip, warning, note)",
	}
}

func (p *AdmonitionsPlugin) Init(ed editor.PluginEditor) {}

func (p *AdmonitionsPlugin) OnEvent(event *PluginEvent) {}

func (p *AdmonitionsPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "callout", Description: "Insert callout block", Handler: calloutHandler},
		{Name: "callout.tip", Description: "Insert tip callout", Handler: calloutTipHandler},
		{Name: "callout.warn", Description: "Insert warning callout", Handler: calloutWarnHandler},
		{Name: "callout.note", Description: "Insert note callout", Handler: calloutNoteHandler},
	}
}

func calloutHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "> [!NOTE]\n> Content\n")
	ed.SetStatus("Inserted NOTE callout", false)
}

func calloutTipHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "> [!TIP]\n> Content\n")
	ed.SetStatus("Inserted TIP callout", false)
}

func calloutWarnHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "> [!WARNING]\n> Content\n")
	ed.SetStatus("Inserted WARNING callout", false)
}

func calloutNoteHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "> [!NOTE]\n> Content\n")
	ed.SetStatus("Inserted NOTE callout", false)
}
