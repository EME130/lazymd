package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type MathPlugin struct{}

func (p *MathPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "math",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "LaTeX math expression support",
	}
}

func (p *MathPlugin) Init(ed editor.PluginEditor) {}

func (p *MathPlugin) OnEvent(event *PluginEvent) {}

func (p *MathPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "math", Description: "Insert inline math", Handler: mathHandler},
		{Name: "math.block", Description: "Insert math block", Handler: mathBlockHandler},
		{Name: "math.count", Description: "Count math blocks", Handler: mathCountHandler},
	}
}

func mathHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "$$ $$")
	ed.SetStatus("Inline math inserted", false)
}

func mathBlockHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "$$\n\n$$\n")
	ed.SetStatus("Math block inserted", false)
}

func mathCountHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	content := buf.Content()
	count := strings.Count(content, "$$")
	blockCount := count / 2
	ed.SetStatus(fmt.Sprintf("Math blocks: %d", blockCount), false)
}
