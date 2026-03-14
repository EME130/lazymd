package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type ExportHTMLPlugin struct{}

func (p *ExportHTMLPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "export-html",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Export to HTML",
	}
}

func (p *ExportHTMLPlugin) Init(ed editor.PluginEditor) {}

func (p *ExportHTMLPlugin) OnEvent(event *PluginEvent) {}

func (p *ExportHTMLPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "export.html", Description: "Export document to HTML", Handler: exportHTMLHandler},
	}
}

func exportHTMLHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Exporting to HTML...", false)
}
