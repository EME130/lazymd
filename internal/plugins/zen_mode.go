package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type ZenModePlugin struct{}

var zenActive bool

func (p *ZenModePlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "zen-mode",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Distraction-free writing mode",
	}
}

func (p *ZenModePlugin) Init(ed editor.PluginEditor) {}

func (p *ZenModePlugin) OnEvent(event *PluginEvent) {}

func (p *ZenModePlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "zen", Description: "Toggle zen mode", Handler: zenHandler},
		{Name: "zen.off", Description: "Disable zen mode", Handler: zenOffHandler},
	}
}

func zenHandler(ed editor.PluginEditor, args string) {
	zenActive = !zenActive

	status := "OFF"
	if zenActive {
		status = "ON"
	}

	ed.SetStatus("Zen mode "+status, false)
}

func zenOffHandler(ed editor.PluginEditor, args string) {
	zenActive = false
	ed.SetStatus("Zen mode OFF", false)
}
