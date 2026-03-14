package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type TemplatesPlugin struct{}

func (p *TemplatesPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "templates",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Markdown document templates",
	}
}

func (p *TemplatesPlugin) Init(ed editor.PluginEditor) {}

func (p *TemplatesPlugin) OnEvent(event *PluginEvent) {}

func (p *TemplatesPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "tpl.meeting", Description: "Insert meeting template", Handler: tplMeetingHandler},
		{Name: "tpl.daily", Description: "Insert daily note template", Handler: tplDailyHandler},
		{Name: "tpl.readme", Description: "Insert README template", Handler: tplReadmeHandler},
		{Name: "tpl.blog", Description: "Insert blog post template", Handler: tplBlogHandler},
	}
}

func tplMeetingHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	template := `# Meeting Notes

**Date:** 2024-01-01
**Attendees:**
**Topic:**

## Agenda

-

## Discussion

-

## Action Items

- [ ]

`
	buf.InsertString(offset, template)
	ed.SetStatus("Meeting template inserted", false)
}

func tplDailyHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	template := `# Daily Note

## Tasks

- [ ]

## Notes

`
	buf.InsertString(offset, template)
	ed.SetStatus("Daily note template inserted", false)
}

func tplReadmeHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	template := `# Project Title

## Description

Brief description of the project.

## Installation

` + "```bash" + `
# Installation commands
` + "```" + `

## Usage

` + "```bash" + `
# Usage examples
` + "```" + `

## Contributing

Contributions are welcome!

## License

MIT

`
	buf.InsertString(offset, template)
	ed.SetStatus("README template inserted", false)
}

func tplBlogHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	template := `---
title: Post Title
date: 2024-01-01
tags: []
draft: true
---

# Post Title

Introduction paragraph.

## Section 1

Content here.

## Conclusion

Closing thoughts.

`
	buf.InsertString(offset, template)
	ed.SetStatus("Blog post template inserted", false)
}
