package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type QuickSwitcherPlugin struct{}

func (p *QuickSwitcherPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "quick-switcher",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Fuzzy file switcher",
	}
}

func (p *QuickSwitcherPlugin) Init(ed editor.PluginEditor) {}

func (p *QuickSwitcherPlugin) OnEvent(event *PluginEvent) {}

func (p *QuickSwitcherPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "open", Description: "Open a file", Handler: openHandler},
		{Name: "switcher", Description: "Quick file switcher", Handler: switcherHandler},
	}
}

func openHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: :open <filename>", false)
		return
	}
	ed.SetStatus("Opening: "+args+"...", false)
}

func switcherHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Quick switcher: type to filter files...", false)
}
