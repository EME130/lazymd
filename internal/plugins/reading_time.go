package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type ReadingTimePlugin struct{}

func (p *ReadingTimePlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "reading-time",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Estimate document reading time",
	}
}

func (p *ReadingTimePlugin) Init(ed editor.PluginEditor) {}

func (p *ReadingTimePlugin) OnEvent(event *PluginEvent) {}

func (p *ReadingTimePlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "reading-time", Description: "Calculate reading time", Handler: readingTimeHandler},
	}
}

func readingTimeHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	content := buf.Content()

	words := strings.Fields(content)
	wordCount := len(words)

	// Reading speed: 200 words per minute
	readingTime := wordCount / 200
	if readingTime == 0 && wordCount > 0 {
		readingTime = 1
	}

	msg := fmt.Sprintf("Reading time: %d min (%d words)", readingTime, wordCount)
	ed.SetStatus(msg, false)
}
