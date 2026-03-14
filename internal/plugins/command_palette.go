package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type CommandPalettePlugin struct{}

func (p *CommandPalettePlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "command-palette",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Fuzzy command palette",
	}
}

func (p *CommandPalettePlugin) Init(ed editor.PluginEditor) {}

func (p *CommandPalettePlugin) OnEvent(event *PluginEvent) {}

func (p *CommandPalettePlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "palette", Description: "Open command palette", Handler: paletteHandler},
		{Name: "commands", Description: "Show commands help", Handler: commandsHandler},
		{Name: "help", Description: "Show help", Handler: helpHandler},
	}
}

func paletteHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Command palette: type to filter...", false)
}

func commandsHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Use :palette to browse commands", false)
}

func helpHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("LazyMD v0.1.0 — :help for docs", false)
}
