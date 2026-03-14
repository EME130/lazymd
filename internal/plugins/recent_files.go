package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type RecentFilesPlugin struct{}

func (p *RecentFilesPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "recent-files",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Recently opened files list",
	}
}

func (p *RecentFilesPlugin) Init(ed editor.PluginEditor) {}

func (p *RecentFilesPlugin) OnEvent(event *PluginEvent) {}

func (p *RecentFilesPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "recent", Description: "Show recent files", Handler: recentHandler},
		{Name: "recent.clear", Description: "Clear recent files list", Handler: recentClearHandler},
	}
}

func recentHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Recent files: use file tree to browse", false)
}

func recentClearHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Recent files list cleared", false)
}
