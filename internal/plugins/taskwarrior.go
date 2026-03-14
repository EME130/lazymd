package plugins

import (
	"fmt"

	"github.com/EME130/lazymd/internal/editor"
)

type TaskWarriorPlugin struct{}

func (p *TaskWarriorPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "taskwarrior",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "TaskWarrior TUI integration",
	}
}

func (p *TaskWarriorPlugin) Init(ed editor.PluginEditor) {}

func (p *TaskWarriorPlugin) OnEvent(event *PluginEvent) {}

func (p *TaskWarriorPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "tw.list", Description: "List TaskWarrior tasks", Handler: twListHandler},
		{Name: "tw.add", Description: "Add TaskWarrior task", Handler: twAddHandler},
		{Name: "tw.done", Description: "Mark task done", Handler: twDoneHandler},
	}
}

func twListHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("TaskWarrior: listing tasks...", false)
}

func twAddHandler(ed editor.PluginEditor, args string) {
	msg := fmt.Sprintf("Adding task: %s", args)
	ed.SetStatus(msg, false)
}

func twDoneHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Marking task done...", false)
}
