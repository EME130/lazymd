package plugins

import (
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type FrontmatterPlugin struct{}

func (p *FrontmatterPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "frontmatter",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "YAML frontmatter management",
	}
}

func (p *FrontmatterPlugin) Init(ed editor.PluginEditor) {}

func (p *FrontmatterPlugin) OnEvent(event *PluginEvent) {}

func (p *FrontmatterPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "fm", Description: "Show frontmatter", Handler: fmHandler},
		{Name: "fm.add", Description: "Add frontmatter template", Handler: fmAddHandler},
		{Name: "fm.edit", Description: "Edit frontmatter", Handler: fmEditHandler},
	}
}

func fmHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	if buf.LineCount() == 0 {
		ed.SetStatus("No frontmatter found", false)
		return
	}

	firstLine := strings.TrimSpace(buf.Line(0))
	if firstLine == "---" {
		ed.SetStatus("Document has frontmatter", false)
	} else {
		ed.SetStatus("No frontmatter found", false)
	}
}

func fmAddHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()

	// Check if frontmatter already exists
	if buf.LineCount() > 0 {
		firstLine := strings.TrimSpace(buf.Line(0))
		if firstLine == "---" {
			ed.SetStatus("Frontmatter already exists", true)
			return
		}
	}

	// Insert at beginning
	template := "---\ntitle: \ndate: \ntags: []\n---\n"
	buf.InsertString(0, template)
	ed.SetStatus("Added frontmatter template", false)
}

func fmEditHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Editing frontmatter...", false)
}
