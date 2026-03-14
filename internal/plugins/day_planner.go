package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type DayPlannerPlugin struct{}

func (p *DayPlannerPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "day-planner",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Time-blocked daily planning",
	}
}

func (p *DayPlannerPlugin) Init(ed editor.PluginEditor) {}

func (p *DayPlannerPlugin) OnEvent(event *PluginEvent) {}

func (p *DayPlannerPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "plan", Description: "Open day planner", Handler: planHandler},
		{Name: "plan.today", Description: "Plan for today", Handler: planTodayHandler},
		{Name: "plan.template", Description: "Insert time-block template", Handler: planTemplateHandler},
	}
}

func planHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Day planner: review your schedule", false)
}

func planTodayHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Planning for today...", false)
}

func planTemplateHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)

	template := `## Daily Schedule

- 09:00 - 10:00
- 10:00 - 11:00
- 11:00 - 12:00
- 12:00 - 13:00 Lunch
- 13:00 - 14:00
- 14:00 - 15:00
- 15:00 - 16:00
- 16:00 - 17:00
`
	buf.InsertString(offset, template)
	ed.SetStatus("Inserted time-block template", false)
}
