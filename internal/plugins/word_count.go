package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type WordCountPlugin struct{}

func (p *WordCountPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "word-count",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Word, line, and character counts",
	}
}

func (p *WordCountPlugin) Init(ed editor.PluginEditor) {}

func (p *WordCountPlugin) OnEvent(event *PluginEvent) {}

func (p *WordCountPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "wc", Description: "Count words, lines, characters", Handler: wcHandler},
	}
}

func wcHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()

	lineCount := buf.LineCount()
	content := buf.Content()
	wordCount := len(strings.Fields(content))
	charCount := len(content)

	msg := fmt.Sprintf("%d words, %d lines, %d chars", wordCount, lineCount, charCount)
	ed.SetStatus(msg, false)
}
