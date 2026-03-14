package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type GitSyncPlugin struct{}

func (p *GitSyncPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "git-sync",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Git-based note synchronization",
	}
}

func (p *GitSyncPlugin) Init(ed editor.PluginEditor) {}

func (p *GitSyncPlugin) OnEvent(event *PluginEvent) {}

func (p *GitSyncPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "git", Description: "Check repository status", Handler: gitHandler},
		{Name: "git.commit", Description: "Commit changes", Handler: gitCommitHandler},
		{Name: "git.push", Description: "Push to remote", Handler: gitPushHandler},
		{Name: "git.pull", Description: "Pull from remote", Handler: gitPullHandler},
		{Name: "git.status", Description: "Git status", Handler: gitStatusHandler},
		{Name: "git.log", Description: "Git log", Handler: gitLogHandler},
	}
}

func gitHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Git: checking repository status...", false)
}

func gitCommitHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Committing changes...", false)
}

func gitPushHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Pushing to remote...", false)
}

func gitPullHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Pulling from remote...", false)
}

func gitStatusHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Git status: checking...", false)
}

func gitLogHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Git log: recent commits...", false)
}
