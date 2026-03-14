package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

type FileRecoveryPlugin struct{}

func (p *FileRecoveryPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "file-recovery",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Auto-save snapshots and crash recovery",
	}
}

func (p *FileRecoveryPlugin) Init(ed editor.PluginEditor) {}

func (p *FileRecoveryPlugin) OnEvent(event *PluginEvent) {}

func (p *FileRecoveryPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "recover", Description: "Recover from last snapshot", Handler: recoverHandler},
		{Name: "recover.list", Description: "List recovery snapshots", Handler: recoverListHandler},
		{Name: "recover.save", Description: "Save recovery snapshot", Handler: recoverSaveHandler},
	}
}

func recoverHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Recovering from last snapshot...", false)
}

func recoverListHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Listing recovery snapshots...", false)
}

func recoverSaveHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Saving recovery snapshot...", false)
}
