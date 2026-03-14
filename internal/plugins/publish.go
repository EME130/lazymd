package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type PublishPlugin struct{}

func (p *PublishPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "publish",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Publish notes as static site",
	}
}

func (p *PublishPlugin) Init(ed editor.PluginEditor) {}

func (p *PublishPlugin) OnEvent(event *PluginEvent) {}

func (p *PublishPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "publish", Description: "Publish vault", Handler: publishHandler},
		{Name: "publish.build", Description: "Build static site", Handler: publishBuildHandler},
		{Name: "publish.preview", Description: "Preview publication", Handler: publishPreviewHandler},
	}
}

func publishHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Publishing vault...", false)
}

func publishBuildHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Building static site...", false)
}

func publishPreviewHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Previewing publication...", false)
}
