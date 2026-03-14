package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type SpellCheckPlugin struct{}

func (p *SpellCheckPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "spell-check",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Spell checking for documents",
	}
}

func (p *SpellCheckPlugin) Init(ed editor.PluginEditor) {}

func (p *SpellCheckPlugin) OnEvent(event *PluginEvent) {}

func (p *SpellCheckPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "spell", Description: "Check spelling in current file", Handler: spellHandler},
		{Name: "spell.all", Description: "Check spelling in all files", Handler: spellAllHandler},
		{Name: "spell.fix", Description: "Auto-fix common misspellings", Handler: spellFixHandler},
	}
}

func spellHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Checking spelling...", false)
}

func spellAllHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Checking all vault files...", false)
}

func spellFixHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Auto-fixing common misspellings...", false)
}
