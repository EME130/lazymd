package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type ChecklistPlugin struct{}

func (p *ChecklistPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "checklist",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Checklist management and progress",
	}
}

func (p *ChecklistPlugin) Init(ed editor.PluginEditor) {}

func (p *ChecklistPlugin) OnEvent(event *PluginEvent) {}

func (p *ChecklistPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "check", Description: "Show checklist progress", Handler: checkHandler},
		{Name: "check.toggle", Description: "Toggle checkbox on current line", Handler: checkToggleHandler},
		{Name: "check.progress", Description: "Show checklist progress", Handler: checkHandler},
	}
}

func checkHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	unchecked := 0
	checked := 0

	for i := 0; i < buf.LineCount(); i++ {
		line := buf.Line(i)
		if strings.Contains(line, "- [ ]") {
			unchecked++
		}
		if strings.Contains(line, "- [x]") || strings.Contains(line, "- [X]") {
			checked++
		}
	}

	total := unchecked + checked
	if total == 0 {
		ed.SetStatus("No tasks found", false)
		return
	}

	percentage := 0
	if total > 0 {
		percentage = (checked * 100) / total
	}

	ed.SetStatus(fmt.Sprintf("Tasks: %d/%d complete (%d%%)", checked, total, percentage), false)
}

func checkToggleHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	line := buf.Line(row)

	if strings.Contains(line, "- [ ]") {
		newLine := strings.Replace(line, "- [ ]", "- [x]", 1)
		offset := buf.PosToOffset(row, 0)
		buf.DeleteRange(offset, len(line))
		buf.InsertString(offset, newLine)
		ed.SetStatus("Task marked complete", false)
	} else if strings.Contains(line, "- [x]") || strings.Contains(line, "- [X]") {
		newLine := strings.Replace(strings.Replace(line, "- [x]", "- [ ]", 1), "- [X]", "- [ ]", 1)
		offset := buf.PosToOffset(row, 0)
		buf.DeleteRange(offset, len(line))
		buf.InsertString(offset, newLine)
		ed.SetStatus("Task marked pending", false)
	} else {
		ed.SetStatus("No checkbox found on current line", true)
	}
}
