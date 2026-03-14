package plugins

import (
	"fmt"

	"github.com/EME130/lazymd/internal/editor"
)

var pomoSessions int

type PomodoroPlugin struct{}

func (p *PomodoroPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "pomodoro",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Pomodoro focus timer",
	}
}

func (p *PomodoroPlugin) Init(ed editor.PluginEditor) {}

func (p *PomodoroPlugin) OnEvent(event *PluginEvent) {}

func (p *PomodoroPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "pomo.start", Description: "Start pomodoro timer", Handler: pomoStartHandler},
		{Name: "pomo.stop", Description: "Stop pomodoro timer", Handler: pomoStopHandler},
		{Name: "pomo.status", Description: "Show pomodoro status", Handler: pomoStatusHandler},
	}
}

func pomoStartHandler(ed editor.PluginEditor, args string) {
	pomoSessions++
	ed.SetStatus(fmt.Sprintf("Pomodoro started (25 min) — session %d", pomoSessions), false)
}

func pomoStopHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Pomodoro stopped", false)
}

func pomoStatusHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus(fmt.Sprintf("Pomodoro: session %d", pomoSessions), false)
}
