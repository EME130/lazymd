package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type TypewriterPlugin struct{}

var typewriterActive bool

func (p *TypewriterPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "typewriter",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Typewriter scrolling — cursor always centered",
	}
}

func (p *TypewriterPlugin) Init(ed editor.PluginEditor) {}

func (p *TypewriterPlugin) OnEvent(event *PluginEvent) {}

func (p *TypewriterPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "typewriter", Description: "Toggle typewriter mode", Handler: typewriterHandler},
		{Name: "typewriter.off", Description: "Disable typewriter mode", Handler: typewriterOffHandler},
	}
}

func typewriterHandler(ed editor.PluginEditor, args string) {
	typewriterActive = !typewriterActive

	status := "OFF"
	if typewriterActive {
		status = "ON"
	}

	ed.SetStatus("Typewriter mode "+status, false)
}

func typewriterOffHandler(ed editor.PluginEditor, args string) {
	typewriterActive = false
	ed.SetStatus("Typewriter mode OFF", false)
}
