package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type MindMapPlugin struct{}

func (p *MindMapPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "mind-map",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "ASCII mind map from headings",
	}
}

func (p *MindMapPlugin) Init(ed editor.PluginEditor) {}

func (p *MindMapPlugin) OnEvent(event *PluginEvent) {}

func (p *MindMapPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "mindmap", Description: "Show mind map", Handler: mindmapHandler},
		{Name: "mindmap.insert", Description: "Insert mind map template", Handler: mindmapInsertHandler},
	}
}

func mindmapHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	var tree strings.Builder
	tree.WriteString("Mind map: ")

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
			tree.WriteString(fmt.Sprintf("\n%s- %s", indent, heading))
		}
	}

	ed.SetStatus(tree.String(), false)
}

func mindmapInsertHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	template := "# Central Topic\n\n## Branch 1\n\n## Branch 2\n"
	buf.InsertString(offset, template)
	ed.SetStatus("Mind map template inserted", false)
}
