package plugins

import (
	"fmt"

	"github.com/EME130/lazymd/internal/editor"
)

type TodoistPlugin struct{}

func (p *TodoistPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "todoist",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Todoist task integration",
	}
}

func (p *TodoistPlugin) Init(ed editor.PluginEditor) {}

func (p *TodoistPlugin) OnEvent(event *PluginEvent) {}

func (p *TodoistPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "todoist", Description: "Connect to Todoist", Handler: todoistHandler},
		{Name: "todoist.add", Description: "Add task to Todoist", Handler: todoistAddHandler},
		{Name: "todoist.done", Description: "Mark Todoist task done", Handler: todoistDoneHandler},
		{Name: "todoist.inbox", Description: "Show Todoist inbox", Handler: todoistInboxHandler},
	}
}

func todoistHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Todoist: connecting...", false)
}

func todoistAddHandler(ed editor.PluginEditor, args string) {
	msg := fmt.Sprintf("Adding to Todoist: %s", args)
	ed.SetStatus(msg, false)
}

func todoistDoneHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Marking Todoist task done...", false)
}

func todoistInboxHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Todoist inbox: loading...", false)
}
