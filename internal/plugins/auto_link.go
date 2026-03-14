package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type AutoLinkPlugin struct{}

func (p *AutoLinkPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "auto-link",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Auto-convert URLs to links",
	}
}

func (p *AutoLinkPlugin) Init(ed editor.PluginEditor) {}

func (p *AutoLinkPlugin) OnEvent(event *PluginEvent) {}

func (p *AutoLinkPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "autolink", Description: "Scan current line for URLs", Handler: autolinkHandler},
	}
}

func autolinkHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	line := buf.Line(row)

	count := 0
	if strings.Contains(line, "http://") {
		count += strings.Count(line, "http://")
	}
	if strings.Contains(line, "https://") {
		count += strings.Count(line, "https://")
	}

	ed.SetStatus(fmt.Sprintf("Found %d URL(s) on current line", count), false)
}
