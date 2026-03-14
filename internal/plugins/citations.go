package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type CitationsPlugin struct{}

func (p *CitationsPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "citations",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Academic citations and BibTeX",
	}
}

func (p *CitationsPlugin) Init(ed editor.PluginEditor) {}

func (p *CitationsPlugin) OnEvent(event *PluginEvent) {}

func (p *CitationsPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "cite", Description: "Insert citation", Handler: citeHandler},
		{Name: "cite.list", Description: "List citations in document", Handler: citeListHandler},
		{Name: "cite.ref", Description: "Insert BibTeX reference", Handler: citeRefHandler},
	}
}

func citeHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)

	key := strings.TrimSpace(args)
	if key == "" {
		key = "key"
	}

	citation := fmt.Sprintf("[@%s]", key)
	buf.InsertString(offset, citation)
	ed.SetStatus(fmt.Sprintf("Inserted citation: %s", citation), false)
}

func citeListHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	count := 0

	for i := 0; i < buf.LineCount(); i++ {
		line := buf.Line(i)
		count += strings.Count(line, "[@")
	}

	ed.SetStatus(fmt.Sprintf("Found %d citation(s) in document", count), false)
}

func citeRefHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)

	template := `@article{key,
  author = {},
  title = {},
  journal = {},
  year = {},
}
`
	buf.InsertString(offset, template)
	ed.SetStatus("Inserted BibTeX @article template", false)
}
