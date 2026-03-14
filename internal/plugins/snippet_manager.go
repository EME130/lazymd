package plugins

import (
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type SnippetManagerPlugin struct{}

var snippets = map[string]string{
	"fn":     "func name() {\n\t\n}",
	"if":     "if condition {\n\t\n}",
	"for":    "for i := range n {\n\t\n}",
	"switch": "switch value {\ncase x:\n\t\n}",
	"struct": "type Name struct {\n\t\n}",
	"iface":  "type Name interface {\n\t\n}",
	"map":    "map[string]interface{}",
	"slice":  "[]string{}",
	"err":    "if err != nil {\n\treturn err\n}",
	"test":   "func TestName(t *testing.T) {\n\t\n}",
	"main":   "func main() {\n\t\n}",
	"pkg":    "package main\n\n",
	"import": "import (\n\t\"\"\n)",
	"const":  "const Name = value",
	"var":    "var name type",
	"defer":  "defer func() {\n\t\n}()",
}

func (p *SnippetManagerPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "snippet-manager",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Reusable text snippets",
	}
}

func (p *SnippetManagerPlugin) Init(ed editor.PluginEditor) {}

func (p *SnippetManagerPlugin) OnEvent(event *PluginEvent) {}

func (p *SnippetManagerPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "snip", Description: "Insert snippet", Handler: snipHandler},
		{Name: "snip.list", Description: "List all snippets", Handler: snipListHandler},
	}
}

func snipHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: :snip <name>", false)
		return
	}

	snippet, exists := snippets[args]
	if !exists {
		ed.SetStatus("Snippet '"+args+"' not found. Use :snip.list to see available snippets", false)
		return
	}

	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())
	buf.InsertString(offset, snippet)

	ed.SetStatus("Inserted snippet: "+args, false)
}

func snipListHandler(ed editor.PluginEditor, args string) {
	names := make([]string, 0, len(snippets))
	for name := range snippets {
		names = append(names, name)
	}

	msg := "Snippets: " + strings.Join(names, ", ")
	ed.SetStatus(msg, false)
}
