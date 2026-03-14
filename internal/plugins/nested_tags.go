package plugins

import (
	"fmt"
	"regexp"

	"github.com/EME130/lazymd/internal/editor"
)

type NestedTagsPlugin struct{}

func (p *NestedTagsPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "nested-tags",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Hierarchical nested tag support",
	}
}

func (p *NestedTagsPlugin) Init(ed editor.PluginEditor) {}

func (p *NestedTagsPlugin) OnEvent(event *PluginEvent) {}

func (p *NestedTagsPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "ntag", Description: "Show nested tags", Handler: ntagHandler},
		{Name: "ntag.add", Description: "Add nested tag", Handler: ntagAddHandler},
		{Name: "ntag.tree", Description: "Build tag hierarchy", Handler: ntagTreeHandler},
	}
}

func ntagHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	content := buf.Content()
	re := regexp.MustCompile(`#\w+/\w+`)
	matches := re.FindAllString(content, -1)
	ed.SetStatus(fmt.Sprintf("Nested tags: found %d tag(s)", len(matches)), false)
}

func ntagAddHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "#"+args)
	ed.SetStatus("Nested tag added", false)
}

func ntagTreeHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Building tag hierarchy...", false)
}
