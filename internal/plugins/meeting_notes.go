package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type MeetingNotesPlugin struct{}

func (p *MeetingNotesPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "meeting-notes",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Structured meeting notes",
	}
}

func (p *MeetingNotesPlugin) Init(ed editor.PluginEditor) {}

func (p *MeetingNotesPlugin) OnEvent(event *PluginEvent) {}

func (p *MeetingNotesPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "meeting", Description: "Show recent meetings", Handler: meetingHandler},
		{Name: "meeting.new", Description: "Create meeting template", Handler: meetingNewHandler},
	}
}

func meetingHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Meeting notes: recent meetings", false)
}

func meetingNewHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	template := "## Meeting Notes\n\n**Date:** \n**Attendees:** \n\n### Agenda\n\n### Action Items\n\n- [ ] \n"
	buf.InsertString(offset, template)
	ed.SetStatus("Meeting template created", false)
}
