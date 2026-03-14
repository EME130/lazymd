package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type RandomNotePlugin struct{}

func (p *RandomNotePlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "random-note",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Open a random note",
	}
}

func (p *RandomNotePlugin) Init(ed editor.PluginEditor) {}

func (p *RandomNotePlugin) OnEvent(event *PluginEvent) {}

func (p *RandomNotePlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "random", Description: "Open a random note", Handler: randomHandler},
	}
}

func randomHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Opening random note...", false)
}
