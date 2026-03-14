package plugins

import (
	"fmt"
	"time"

	"github.com/EME130/lazymd/internal/editor"
)

type CalendarPlugin struct{}

func (p *CalendarPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "calendar",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Visual calendar navigation",
	}
}

func (p *CalendarPlugin) Init(ed editor.PluginEditor) {}

func (p *CalendarPlugin) OnEvent(event *PluginEvent) {}

func (p *CalendarPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "cal", Description: "Show current month", Handler: calHandler},
		{Name: "cal.today", Description: "Open today's note", Handler: calTodayHandler},
		{Name: "cal.goto", Description: "Navigate to date", Handler: calGotoHandler},
	}
}

func calHandler(ed editor.PluginEditor, args string) {
	now := time.Now()
	ed.SetStatus(fmt.Sprintf("Calendar: %s %d", now.Month(), now.Year()), false)
}

func calTodayHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Opening today's note...", false)
}

func calGotoHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus(fmt.Sprintf("Navigate to date: %s", args), false)
}
