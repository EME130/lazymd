package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type ZettelkastenPlugin struct{}

func (p *ZettelkastenPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "zettelkasten",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Zettelkasten note-taking method",
	}
}

func (p *ZettelkastenPlugin) Init(ed editor.PluginEditor) {}

func (p *ZettelkastenPlugin) OnEvent(event *PluginEvent) {}

func (p *ZettelkastenPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "zk.new", Description: "Create new zettel", Handler: zkNewHandler},
		{Name: "zk.link", Description: "Insert zettel link", Handler: zkLinkHandler},
		{Name: "zk.index", Description: "Show zettel index", Handler: zkIndexHandler},
	}
}

func zkNewHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	template := "---\nid: 20240101120000\ntitle: \ntags: []\n---\n\n# "
	buf.InsertString(offset, template)

	ed.SetStatus("New zettel template inserted", false)
}

func zkLinkHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: :zk.link <note-name>", false)
		return
	}

	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	link := "[[" + args + "]]"
	buf.InsertString(offset, link)

	ed.SetStatus("Zettel link inserted", false)
}

func zkIndexHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Zettel index: scanning zk/ directory...", false)
}
