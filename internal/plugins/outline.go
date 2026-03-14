package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type OutlinePlugin struct{}

func (p *OutlinePlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "outline",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Document outline / table of contents",
	}
}

func (p *OutlinePlugin) Init(ed editor.PluginEditor) {}

func (p *OutlinePlugin) OnEvent(event *PluginEvent) {}

func (p *OutlinePlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "outline", Description: "Show document outline", Handler: outlineHandler},
		{Name: "toc", Description: "Generate table of contents", Handler: tocHandler},
		{Name: "outline.next", Description: "Jump to next heading", Handler: outlineNextHandler},
		{Name: "outline.prev", Description: "Jump to previous heading", Handler: outlinePrevHandler},
	}
}

func outlineHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	var outline strings.Builder
	outline.WriteString("Outline: ")

	for i := 0; i < buf.LineCount(); i++ {
		line := strings.TrimSpace(buf.Line(i))
		if strings.HasPrefix(line, "#") {
			level := 0
			for _, ch := range line {
				if ch == '#' {
					level++
				} else {
					break
				}
			}
			heading := strings.TrimSpace(strings.TrimPrefix(line, strings.Repeat("#", level)))
			indent := strings.Repeat("  ", level-1)
			outline.WriteString(fmt.Sprintf("\n%s- %s", indent, heading))
		}
	}

	ed.SetStatus(outline.String(), false)
}

func tocHandler(ed editor.PluginEditor, args string) {
	outlineHandler(ed, args)
}

func outlineNextHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	currentRow := ed.CursorRow()

	for i := currentRow + 1; i < buf.LineCount(); i++ {
		line := strings.TrimSpace(buf.Line(i))
		if strings.HasPrefix(line, "#") {
			ed.SetCursorRow(i)
			ed.SetStatus(fmt.Sprintf("Jumped to line %d", i+1), false)
			return
		}
	}

	ed.SetStatus("No next heading found", false)
}

func outlinePrevHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	currentRow := ed.CursorRow()

	for i := currentRow - 1; i >= 0; i-- {
		line := strings.TrimSpace(buf.Line(i))
		if strings.HasPrefix(line, "#") {
			ed.SetCursorRow(i)
			ed.SetStatus(fmt.Sprintf("Jumped to line %d", i+1), false)
			return
		}
	}

	ed.SetStatus("No previous heading found", false)
}
