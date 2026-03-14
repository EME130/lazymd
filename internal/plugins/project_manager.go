package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type ProjectManagerPlugin struct{}

func (p *ProjectManagerPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "project-manager",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Switch between project vaults",
	}
}

func (p *ProjectManagerPlugin) Init(ed editor.PluginEditor) {}

func (p *ProjectManagerPlugin) OnEvent(event *PluginEvent) {}

func (p *ProjectManagerPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "project", Description: "Show project stats", Handler: projectHandler},
		{Name: "project.stats", Description: "Detailed project stats", Handler: projectStatsHandler},
		{Name: "project.new", Description: "Create new project vault", Handler: projectNewHandler},
	}
}

func projectHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Project: scanning vault files...", false)
}

func projectStatsHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Project stats: calculating...", false)
}

func projectNewHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Creating new project vault...", false)
}
