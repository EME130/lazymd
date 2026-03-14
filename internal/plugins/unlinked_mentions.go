package plugins

import (
	"fmt"
	"path/filepath"

	"github.com/EME130/lazymd/internal/editor"
)

type UnlinkedMentionsPlugin struct{}

func (p *UnlinkedMentionsPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "unlinked-mentions",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Find unlinked mentions of current note",
	}
}

func (p *UnlinkedMentionsPlugin) Init(ed editor.PluginEditor) {}

func (p *UnlinkedMentionsPlugin) OnEvent(event *PluginEvent) {}

func (p *UnlinkedMentionsPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "unlinked", Description: "Find unlinked mentions", Handler: unlinkedHandler},
		{Name: "unlinked.link", Description: "Convert mention to wiki-link", Handler: unlinkedLinkHandler},
	}
}

func unlinkedHandler(ed editor.PluginEditor, args string) {
	filePath := ed.FilePath()
	fileName := filepath.Base(filePath)

	msg := fmt.Sprintf("Scanning for unlinked mentions of '%s'...", fileName)
	ed.SetStatus(msg, false)
}

func unlinkedLinkHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Converting mention to [[wiki-link]]...", false)
}
