package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type PeriodicNotesPlugin struct{}

func (p *PeriodicNotesPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "periodic-notes",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Weekly and monthly journal notes",
	}
}

func (p *PeriodicNotesPlugin) Init(ed editor.PluginEditor) {}

func (p *PeriodicNotesPlugin) OnEvent(event *PluginEvent) {}

func (p *PeriodicNotesPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "weekly", Description: "Open weekly note", Handler: weeklyHandler},
		{Name: "monthly", Description: "Open monthly note", Handler: monthlyHandler},
		{Name: "quarterly", Description: "Open quarterly note", Handler: quarterlyHandler},
	}
}

func weeklyHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Opening weekly note...", false)
}

func monthlyHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Opening monthly note...", false)
}

func quarterlyHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Opening quarterly note...", false)
}
