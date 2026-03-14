package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type DailyNotesPlugin struct{}

func (p *DailyNotesPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "daily-notes",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Daily journal notes",
	}
}

func (p *DailyNotesPlugin) Init(ed editor.PluginEditor) {}

func (p *DailyNotesPlugin) OnEvent(event *PluginEvent) {}

func (p *DailyNotesPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "daily", Description: "Open today's daily note", Handler: dailyHandler},
		{Name: "daily.yesterday", Description: "Open yesterday's note", Handler: dailyYesterdayHandler},
		{Name: "daily.tomorrow", Description: "Open tomorrow's note", Handler: dailyTomorrowHandler},
	}
}

func dailyHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Opening today's daily note...", false)
}

func dailyYesterdayHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Opening yesterday's note...", false)
}

func dailyTomorrowHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Opening tomorrow's note...", false)
}
