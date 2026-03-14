package plugins

import (
	"fmt"

	"github.com/EME130/lazymd/internal/editor"
)

type GraphViewPlugin struct{}

func (p *GraphViewPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "graph-view",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "ASCII graph of note connections",
	}
}

func (p *GraphViewPlugin) Init(ed editor.PluginEditor) {}

func (p *GraphViewPlugin) OnEvent(event *PluginEvent) {}

func (p *GraphViewPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "graph", Description: "Render knowledge graph", Handler: graphHandler},
		{Name: "graph.local", Description: "Local graph for current file", Handler: graphLocalHandler},
		{Name: "graph.orphans", Description: "Find orphaned notes", Handler: graphOrphansHandler},
	}
}

func graphHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Rendering knowledge graph...", false)
}

func graphLocalHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus(fmt.Sprintf("Local graph for: %s", ed.FilePath()), false)
}

func graphOrphansHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Finding orphaned notes...", false)
}
