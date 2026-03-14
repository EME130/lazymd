package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type PasteImagePlugin struct{}

func (p *PasteImagePlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "paste-image",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Paste images from clipboard",
	}
}

func (p *PasteImagePlugin) Init(ed editor.PluginEditor) {}

func (p *PasteImagePlugin) OnEvent(event *PluginEvent) {}

func (p *PasteImagePlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "paste.img", Description: "Paste image from clipboard", Handler: pasteImgHandler},
		{Name: "paste.link", Description: "Insert image link", Handler: pasteLinkHandler},
		{Name: "paste.list", Description: "List pasted images", Handler: pasteListHandler},
	}
}

func pasteImgHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Pasting image from clipboard...", false)
}

func pasteLinkHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	buf.InsertString(offset, "![image](attachments/image.png)")
	ed.SetStatus("Image link inserted", false)
}

func pasteListHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Listing pasted images...", false)
}
