package plugins

import (
	"fmt"
	"path/filepath"

	"github.com/EME130/lazymd/internal/editor"
)

type BacklinksPlugin struct{}

func (p *BacklinksPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "backlinks",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Find files linking to current note",
	}
}

func (p *BacklinksPlugin) Init(ed editor.PluginEditor) {}

func (p *BacklinksPlugin) OnEvent(event *PluginEvent) {}

func (p *BacklinksPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "backlinks", Description: "Find backlinks to current note", Handler: backlinksHandler},
	}
}

func backlinksHandler(ed editor.PluginEditor, args string) {
	filename := filepath.Base(ed.FilePath())
	ed.SetStatus(fmt.Sprintf("Scanning vault for backlinks to %s...", filename), false)
}
