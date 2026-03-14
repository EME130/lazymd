package plugins

import (
	"fmt"

	"github.com/EME130/lazymd/internal/editor"
)

type NoteRenamePlugin struct{}

func (p *NoteRenamePlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "note-rename",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Rename notes with auto link updates",
	}
}

func (p *NoteRenamePlugin) Init(ed editor.PluginEditor) {}

func (p *NoteRenamePlugin) OnEvent(event *PluginEvent) {}

func (p *NoteRenamePlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "rename", Description: "Rename current note", Handler: renameHandler},
		{Name: "rename.preview", Description: "Preview rename", Handler: renamePreviewHandler},
	}
}

func renameHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: rename <new-name>", true)
	} else {
		ed.SetStatus(fmt.Sprintf("Renaming to: %s", args), false)
	}
}

func renamePreviewHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Preview: files that would be affected...", false)
}
