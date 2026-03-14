package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type BookmarksPlugin struct{}

var marks [26]int

func init() {
	for i := range marks {
		marks[i] = -1
	}
}

func (p *BookmarksPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "bookmarks",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Bookmark positions in files",
	}
}

func (p *BookmarksPlugin) Init(ed editor.PluginEditor) {}

func (p *BookmarksPlugin) OnEvent(event *PluginEvent) {}

func (p *BookmarksPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "bm.set", Description: "Set bookmark (a-z)", Handler: bmSetHandler},
		{Name: "bm.go", Description: "Jump to bookmark", Handler: bmGoHandler},
		{Name: "bm.list", Description: "List active bookmarks", Handler: bmListHandler},
		{Name: "bm.clear", Description: "Clear all bookmarks", Handler: bmClearHandler},
	}
}

func bmSetHandler(ed editor.PluginEditor, args string) {
	args = strings.TrimSpace(args)
	if len(args) != 1 || args[0] < 'a' || args[0] > 'z' {
		ed.SetStatus("Usage: bm.set <a-z>", true)
		return
	}
	idx := int(args[0] - 'a')
	marks[idx] = ed.CursorRow()
	ed.SetStatus(fmt.Sprintf("Bookmark '%s' set to row %d", args, marks[idx]), false)
}

func bmGoHandler(ed editor.PluginEditor, args string) {
	args = strings.TrimSpace(args)
	if len(args) != 1 || args[0] < 'a' || args[0] > 'z' {
		ed.SetStatus("Usage: bm.go <a-z>", true)
		return
	}
	idx := int(args[0] - 'a')
	if marks[idx] == -1 {
		ed.SetStatus(fmt.Sprintf("Bookmark '%s' not set", args), true)
		return
	}
	ed.SetCursorRow(marks[idx])
	ed.SetStatus(fmt.Sprintf("Jumped to bookmark '%s' (row %d)", args, marks[idx]), false)
}

func bmListHandler(ed editor.PluginEditor, args string) {
	active := []string{}
	for i := 0; i < 26; i++ {
		if marks[i] != -1 {
			active = append(active, fmt.Sprintf("%c:%d", 'a'+i, marks[i]))
		}
	}
	if len(active) == 0 {
		ed.SetStatus("No active bookmarks", false)
	} else {
		ed.SetStatus(fmt.Sprintf("Bookmarks: %s", strings.Join(active, ", ")), false)
	}
}

func bmClearHandler(ed editor.PluginEditor, args string) {
	for i := range marks {
		marks[i] = -1
	}
	ed.SetStatus("All bookmarks cleared", false)
}
