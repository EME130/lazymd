package plugins

import (
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type TextExpanderPlugin struct{}

var expansions = map[string]string{
	"sig":   "Best regards,\nLazyMD User",
	"todo":  "- [ ] TODO: ",
	"date":  "2024-01-01",
	"time":  "12:00",
	"shrug": "¯\\_(ツ)_/¯",
	"check": "✓",
	"cross": "✗",
	"arrow": "→",
	"email": "user@example.com",
	"phone": "+1-555-0100",
}

func (p *TextExpanderPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "text-expander",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Shorthand text expansion",
	}
}

func (p *TextExpanderPlugin) Init(ed editor.PluginEditor) {}

func (p *TextExpanderPlugin) OnEvent(event *PluginEvent) {}

func (p *TextExpanderPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "expand", Description: "Expand shorthand", Handler: expandHandler},
		{Name: "expand.list", Description: "List all expansions", Handler: expandListHandler},
		{Name: "expand.date", Description: "Insert date placeholder", Handler: expandDateHandler},
		{Name: "expand.time", Description: "Insert time placeholder", Handler: expandTimeHandler},
	}
}

func expandHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: :expand <trigger>", false)
		return
	}

	expansion, exists := expansions[args]
	if !exists {
		ed.SetStatus("Expansion '"+args+"' not found. Use :expand.list to see available expansions", false)
		return
	}

	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())
	buf.InsertString(offset, expansion)

	ed.SetStatus("Expanded: "+args, false)
}

func expandListHandler(ed editor.PluginEditor, args string) {
	triggers := make([]string, 0, len(expansions))
	for trigger := range expansions {
		triggers = append(triggers, trigger)
	}

	msg := "Expansions: " + strings.Join(triggers, ", ")
	ed.SetStatus(msg, false)
}

func expandDateHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())
	buf.InsertString(offset, "{{date}}")

	ed.SetStatus("Date placeholder inserted", false)
}

func expandTimeHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())
	buf.InsertString(offset, "{{time}}")

	ed.SetStatus("Time placeholder inserted", false)
}
