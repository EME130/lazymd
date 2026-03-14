package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type MermaidPlugin struct{}

func (p *MermaidPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "mermaid",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Mermaid diagram support",
	}
}

func (p *MermaidPlugin) Init(ed editor.PluginEditor) {}

func (p *MermaidPlugin) OnEvent(event *PluginEvent) {}

func (p *MermaidPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "mermaid", Description: "Insert mermaid diagram", Handler: mermaidHandler},
		{Name: "mermaid.flow", Description: "Insert flowchart template", Handler: mermaidFlowHandler},
		{Name: "mermaid.seq", Description: "Insert sequence diagram", Handler: mermaidSeqHandler},
		{Name: "mermaid.gantt", Description: "Insert gantt chart", Handler: mermaidGanttHandler},
	}
}

func mermaidHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "```mermaid\ngraph TD\n    A-->B\n```\n")
	ed.SetStatus("Mermaid diagram inserted", false)
}

func mermaidFlowHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	template := "```mermaid\nflowchart TD\n    Start --> Process\n    Process --> End\n```\n"
	buf.InsertString(offset, template)
	ed.SetStatus("Flowchart template inserted", false)
}

func mermaidSeqHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	template := "```mermaid\nsequenceDiagram\n    Alice->>Bob: Hello\n    Bob->>Alice: Hi\n```\n"
	buf.InsertString(offset, template)
	ed.SetStatus("Sequence diagram inserted", false)
}

func mermaidGanttHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	template := "```mermaid\ngantt\n    title Project Schedule\n    section Phase 1\n    Task 1 :a1, 2024-01-01, 30d\n```\n"
	buf.InsertString(offset, template)
	ed.SetStatus("Gantt chart inserted", false)
}
