package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type KanbanPlugin struct{}

func (p *KanbanPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "kanban",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Markdown-based kanban board",
	}
}

func (p *KanbanPlugin) Init(ed editor.PluginEditor) {}

func (p *KanbanPlugin) OnEvent(event *PluginEvent) {}

func (p *KanbanPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "kanban", Description: "Show kanban summary", Handler: kanbanHandler},
		{Name: "kanban.new", Description: "Create kanban template", Handler: kanbanNewHandler},
		{Name: "kanban.add", Description: "Add kanban item", Handler: kanbanAddHandler},
	}
}

func kanbanHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	columns := make(map[string]int)
	var currentCol string

	for i := 0; i < buf.LineCount(); i++ {
		line := strings.TrimSpace(buf.Line(i))
		if strings.HasPrefix(line, "## ") {
			currentCol = strings.TrimPrefix(line, "## ")
			columns[currentCol] = 0
		} else if (strings.HasPrefix(line, "- [ ]") || strings.HasPrefix(line, "- [x]")) && currentCol != "" {
			columns[currentCol]++
		}
	}

	var summary strings.Builder
	summary.WriteString(fmt.Sprintf("Kanban (%d cols): ", len(columns)))
	first := true
	for col, count := range columns {
		if !first {
			summary.WriteString(", ")
		}
		summary.WriteString(fmt.Sprintf("%s(%d)", col, count))
		first = false
	}

	ed.SetStatus(summary.String(), false)
}

func kanbanNewHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	template := "## Backlog\n\n- [ ] \n\n## In Progress\n\n- [ ] \n\n## Done\n\n- [x] \n"
	buf.InsertString(offset, template)
	ed.SetStatus("Kanban template created", false)
}

func kanbanAddHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	lineLen := buf.LineLen(row)
	offset := buf.PosToOffset(row, lineLen)
	buf.InsertString(offset, "\n- [ ] "+args)
	ed.SetStatus("Kanban item added", false)
}
