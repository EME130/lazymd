package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type VersionHistoryPlugin struct{}

func (p *VersionHistoryPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "version-history",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Document version tracking",
	}
}

func (p *VersionHistoryPlugin) Init(ed editor.PluginEditor) {}

func (p *VersionHistoryPlugin) OnEvent(event *PluginEvent) {}

func (p *VersionHistoryPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "history", Description: "Show version history", Handler: historyHandler},
		{Name: "history.diff", Description: "Compare versions", Handler: historyDiffHandler},
		{Name: "history.save", Description: "Save version snapshot", Handler: historySaveHandler},
	}
}

func historyHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Version history: checking...", false)
}

func historyDiffHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Comparing versions...", false)
}

func historySaveHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Saving version snapshot...", false)
}
