package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type TagManagerPlugin struct{}

func (p *TagManagerPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "tag-manager",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Manage and search #tags",
	}
}

func (p *TagManagerPlugin) Init(ed editor.PluginEditor) {}

func (p *TagManagerPlugin) OnEvent(event *PluginEvent) {}

func (p *TagManagerPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "tags", Description: "List tags in current file", Handler: tagsHandler},
		{Name: "tags.search", Description: "Search vault for tag", Handler: tagsSearchHandler},
		{Name: "tags.add", Description: "Add tag at cursor", Handler: tagsAddHandler},
	}
}

func tagsHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	content := buf.Content()

	tagMap := make(map[string]bool)
	words := strings.Fields(content)

	for _, word := range words {
		if strings.HasPrefix(word, "#") && len(word) > 1 {
			tag := strings.TrimRight(word, ".,!?;:")
			tagMap[tag] = true
		}
	}

	tagCount := len(tagMap)
	tags := make([]string, 0, tagCount)
	for tag := range tagMap {
		tags = append(tags, tag)
	}

	msg := fmt.Sprintf("Found %d tags: %s", tagCount, strings.Join(tags, ", "))
	if tagCount == 0 {
		msg = "No tags found"
	}

	ed.SetStatus(msg, false)
}

func tagsSearchHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: :tags.search <tag>", false)
		return
	}

	tag := args
	if !strings.HasPrefix(tag, "#") {
		tag = "#" + tag
	}

	ed.SetStatus("Searching vault for: "+tag, false)
}

func tagsAddHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: :tags.add <tag>", false)
		return
	}

	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	tag := args
	if !strings.HasPrefix(tag, "#") {
		tag = "#" + tag
	}

	buf.InsertString(offset, tag)
	ed.SetStatus("Tag inserted: "+tag, false)
}
