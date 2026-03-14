package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type DataviewPlugin struct{}

func (p *DataviewPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "dataview",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Query note metadata and frontmatter",
	}
}

func (p *DataviewPlugin) Init(ed editor.PluginEditor) {}

func (p *DataviewPlugin) OnEvent(event *PluginEvent) {}

func (p *DataviewPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "dv", Description: "Scan vault metadata", Handler: dvHandler},
		{Name: "dv.list", Description: "List documents with frontmatter", Handler: dvListHandler},
		{Name: "dv.tasks", Description: "Scan vault for tasks", Handler: dvTasksHandler},
	}
}

func dvHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Dataview: scanning vault metadata...", false)
}

func dvListHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Listing documents with frontmatter...", false)
}

func dvTasksHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Scanning vault for tasks...", false)
}
