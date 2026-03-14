package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type HabitTrackerPlugin struct{}

func (p *HabitTrackerPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "habit-tracker",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Daily habit tracking",
	}
}

func (p *HabitTrackerPlugin) Init(ed editor.PluginEditor) {}

func (p *HabitTrackerPlugin) OnEvent(event *PluginEvent) {}

func (p *HabitTrackerPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "habit", Description: "Show today's habits", Handler: habitHandler},
		{Name: "habit.new", Description: "Create new habit", Handler: habitNewHandler},
		{Name: "habit.add", Description: "Log habit for today", Handler: habitAddHandler},
	}
}

func habitHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Habit tracker: today's habits", false)
}

func habitNewHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "- [ ] "+args)
	ed.SetStatus("Habit created", false)
}

func habitAddHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Habit logged for today", false)
}
