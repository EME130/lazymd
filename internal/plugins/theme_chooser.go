package plugins

import (
	"fmt"

	"github.com/EME130/lazymd/internal/editor"
	"github.com/EME130/lazymd/internal/themes"
)

type ThemeChooserPlugin struct{}

func (p *ThemeChooserPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "theme-chooser",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Interactive theme browser and chooser",
	}
}

func (p *ThemeChooserPlugin) Init(ed editor.PluginEditor) {}

func (p *ThemeChooserPlugin) OnEvent(event *PluginEvent) {}

func (p *ThemeChooserPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "theme.chooser", Description: "Open theme chooser", Handler: themeChooserHandler},
		{Name: "theme.preview", Description: "Preview current theme", Handler: themePreviewHandler},
		{Name: "theme.info", Description: "Show theme info", Handler: themeInfoHandler},
	}
}

func themeChooserHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Theme chooser: use :theme.cycle to browse", false)
}

func themePreviewHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Preview: current theme applied", false)
}

func themeInfoHandler(ed editor.PluginEditor, args string) {
	t := themes.Current()
	ed.SetStatus(fmt.Sprintf("Theme: %s — %s", t.Name, t.Description), false)
}
