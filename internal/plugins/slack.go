package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type SlackPlugin struct{}

func (p *SlackPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "slack",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Slack messaging integration",
	}
}

func (p *SlackPlugin) Init(ed editor.PluginEditor) {}

func (p *SlackPlugin) OnEvent(event *PluginEvent) {}

func (p *SlackPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "slack", Description: "Convert to Slack format", Handler: slackHandler},
		{Name: "slack.format", Description: "Format for Slack", Handler: slackFormatHandler},
		{Name: "slack.export", Description: "Export to Slack", Handler: slackExportHandler},
	}
}

func slackHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Converting to Slack mrkdwn format...", false)
}

func slackFormatHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Formatting for Slack...", false)
}

func slackExportHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Exporting to Slack format...", false)
}
