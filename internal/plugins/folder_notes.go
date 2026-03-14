package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type FolderNotesPlugin struct{}

func (p *FolderNotesPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "folder-notes",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Auto-generate folder index notes",
	}
}

func (p *FolderNotesPlugin) Init(ed editor.PluginEditor) {}

func (p *FolderNotesPlugin) OnEvent(event *PluginEvent) {}

func (p *FolderNotesPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "folder.index", Description: "Generate folder index", Handler: folderIndexHandler},
		{Name: "folder.create", Description: "Create folder structure", Handler: folderCreateHandler},
	}
}

func folderIndexHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Generating folder index...", false)
}

func folderCreateHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Creating folder structure...", false)
}
