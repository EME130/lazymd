package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type FlashcardsPlugin struct{}

func (p *FlashcardsPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "flashcards",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Spaced repetition flashcards",
	}
}

func (p *FlashcardsPlugin) Init(ed editor.PluginEditor) {}

func (p *FlashcardsPlugin) OnEvent(event *PluginEvent) {}

func (p *FlashcardsPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "flash", Description: "Enter flashcard mode", Handler: flashHandler},
		{Name: "flash.add", Description: "Add flashcard template", Handler: flashAddHandler},
		{Name: "flash.review", Description: "Review flashcards", Handler: flashReviewHandler},
	}
}

func flashHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Flashcard mode: Q:/A: format", false)
}

func flashAddHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "Q: \nA: \n")
	ed.SetStatus("Inserted flashcard template", false)
}

func flashReviewHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Entering review mode...", false)
}
