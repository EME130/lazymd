package plugins

import (
	"fmt"

	"github.com/EME130/lazymd/internal/editor"
)

type NoteRefactorPlugin struct{}

func (p *NoteRefactorPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "note-refactor",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Extract and split notes",
	}
}

func (p *NoteRefactorPlugin) Init(ed editor.PluginEditor) {}

func (p *NoteRefactorPlugin) OnEvent(event *PluginEvent) {}

func (p *NoteRefactorPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "refactor.extract", Description: "Extract selection to new note", Handler: refactorExtractHandler},
		{Name: "refactor.split", Description: "Split note at cursor", Handler: refactorSplitHandler},
	}
}

func refactorExtractHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Extract selection to new note...", false)
}

func refactorSplitHandler(ed editor.PluginEditor, args string) {
	row := ed.CursorRow() + 1
	ed.SetStatus(fmt.Sprintf("Splitting note at line %d...", row), false)
}
