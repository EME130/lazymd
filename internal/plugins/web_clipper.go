package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type WebClipperPlugin struct{}

func (p *WebClipperPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "web-clipper",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Clip web pages to markdown",
	}
}

func (p *WebClipperPlugin) Init(ed editor.PluginEditor) {}

func (p *WebClipperPlugin) OnEvent(event *PluginEvent) {}

func (p *WebClipperPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "clip", Description: "Clip web page", Handler: clipHandler},
		{Name: "clip.insert", Description: "Insert clipped content", Handler: clipInsertHandler},
		{Name: "clip.list", Description: "List web clippings", Handler: clipListHandler},
	}
}

func clipHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: :clip <url>", false)
		return
	}

	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	template := "---\nsource: " + args + "\nclipped: 2024-01-01\n---\n\n# Web Clipping\n\n"
	buf.InsertString(offset, template)

	ed.SetStatus("Web clipping template inserted", false)
}

func clipInsertHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Inserting clipped content...", false)
}

func clipListHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Listing web clippings...", false)
}
