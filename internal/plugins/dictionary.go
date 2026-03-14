package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type DictionaryPlugin struct{}

var dictionary = map[string]string{
	"api":        "Application Programming Interface - a set of rules for software communication",
	"algorithm":  "A step-by-step procedure for solving a problem or performing a computation",
	"buffer":     "A temporary storage area for data being transferred between devices or processes",
	"cache":      "A hardware or software component that stores data for faster future access",
	"compiler":   "A program that translates source code into machine code",
	"database":   "An organized collection of structured data stored electronically",
	"framework":  "A platform providing structure and tools for software development",
	"git":        "A distributed version control system for tracking code changes",
	"json":       "JavaScript Object Notation - a lightweight data interchange format",
	"repository": "A central location where code and version history are stored",
}

func (p *DictionaryPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "dictionary",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Word definition lookup",
	}
}

func (p *DictionaryPlugin) Init(ed editor.PluginEditor) {}

func (p *DictionaryPlugin) OnEvent(event *PluginEvent) {}

func (p *DictionaryPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "define", Description: "Look up word definition", Handler: defineHandler},
		{Name: "define.insert", Description: "Insert definition at cursor", Handler: defineInsertHandler},
	}
}

func defineHandler(ed editor.PluginEditor, args string) {
	word := strings.ToLower(strings.TrimSpace(args))
	if word == "" {
		ed.SetStatus("Usage: define <word>", true)
		return
	}

	if definition, found := dictionary[word]; found {
		ed.SetStatus(fmt.Sprintf("%s: %s", word, definition), false)
	} else {
		ed.SetStatus(fmt.Sprintf("Definition not found for: %s", word), true)
	}
}

func defineInsertHandler(ed editor.PluginEditor, args string) {
	word := strings.ToLower(strings.TrimSpace(args))
	if word == "" {
		ed.SetStatus("Usage: define.insert <word>", true)
		return
	}

	if definition, found := dictionary[word]; found {
		buf := ed.Buffer()
		row := ed.CursorRow()
		col := ed.CursorCol()
		offset := buf.PosToOffset(row, col)
		text := fmt.Sprintf("**%s**: %s\n", word, definition)
		buf.InsertString(offset, text)
		ed.SetStatus(fmt.Sprintf("Inserted definition for: %s", word), false)
	} else {
		ed.SetStatus(fmt.Sprintf("Definition not found for: %s", word), true)
	}
}
