package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type FocusModePlugin struct{}

var focusActive bool

func (p *FocusModePlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "focus-mode",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Highlight current paragraph/sentence",
	}
}

func (p *FocusModePlugin) Init(ed editor.PluginEditor) {}

func (p *FocusModePlugin) OnEvent(event *PluginEvent) {}

func (p *FocusModePlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "focus", Description: "Toggle focus mode", Handler: focusHandler},
		{Name: "focus.para", Description: "Focus paragraph mode", Handler: focusParaHandler},
		{Name: "focus.sentence", Description: "Focus sentence mode", Handler: focusSentenceHandler},
	}
}

func focusHandler(ed editor.PluginEditor, args string) {
	focusActive = !focusActive
	if focusActive {
		ed.SetStatus("Focus mode ON", false)
	} else {
		ed.SetStatus("Focus mode OFF", false)
	}
}

func focusParaHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Focus: paragraph mode", false)
}

func focusSentenceHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Focus: sentence mode", false)
}
