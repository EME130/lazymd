package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type AutoCompletePlugin struct{}

func (p *AutoCompletePlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "auto-complete",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Auto-complete for links and tags",
	}
}

func (p *AutoCompletePlugin) Init(ed editor.PluginEditor) {}

func (p *AutoCompletePlugin) OnEvent(event *PluginEvent) {}

func (p *AutoCompletePlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "autocomplete", Description: "Scan vault for suggestions", Handler: autocompleteHandler},
		{Name: "autocomplete.tag", Description: "Scan vault for tags", Handler: autocompleteTagHandler},
	}
}

func autocompleteHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Auto-complete: scan vault for suggestions", false)
}

func autocompleteTagHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Tag auto-complete: scan vault for #tags", false)
}
