package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type SearchPlugin struct{}

func (p *SearchPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "search",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Full-text search in file and vault",
	}
}

func (p *SearchPlugin) Init(ed editor.PluginEditor) {}

func (p *SearchPlugin) OnEvent(event *PluginEvent) {}

func (p *SearchPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "search", Description: "Search in current file", Handler: searchHandler},
		{Name: "search.replace", Description: "Search and replace", Handler: searchReplaceHandler},
		{Name: "search.vault", Description: "Search entire vault", Handler: searchVaultHandler},
	}
}

func searchHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: :search <query>", false)
		return
	}

	buf := ed.Buffer()
	query := strings.ToLower(args)
	matchCount := 0

	for i := 0; i < buf.LineCount(); i++ {
		line := strings.ToLower(buf.Line(i))
		if strings.Contains(line, query) {
			matchCount++
		}
	}

	msg := fmt.Sprintf("Found %d matches for '%s'", matchCount, args)
	ed.SetStatus(msg, false)
}

func searchReplaceHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Usage: :search.replace <find> <replace>", false)
}

func searchVaultHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Searching vault for: "+args+"...", false)
}
