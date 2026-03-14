package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type LinterPlugin struct{}

func (p *LinterPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "linter",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Markdown linting and style checks",
	}
}

func (p *LinterPlugin) Init(ed editor.PluginEditor) {}

func (p *LinterPlugin) OnEvent(event *PluginEvent) {}

func (p *LinterPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "lint", Description: "Check for issues", Handler: lintHandler},
		{Name: "lint.fix", Description: "Auto-fix issues", Handler: lintFixHandler},
	}
}

func lintHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	issues := 0

	for i := 0; i < buf.LineCount(); i++ {
		line := buf.Line(i)

		// Check trailing whitespace
		if len(line) > 0 && (line[len(line)-1] == ' ' || line[len(line)-1] == '\t') {
			issues++
		}

		// Check blank line after heading
		if strings.HasPrefix(strings.TrimSpace(line), "#") {
			if i+1 < buf.LineCount() {
				nextLine := strings.TrimSpace(buf.Line(i + 1))
				if nextLine != "" && !strings.HasPrefix(nextLine, "#") {
					issues++
				}
			}
		}
	}

	ed.SetStatus(fmt.Sprintf("Lint: found %d issue(s)", issues), false)
}

func lintFixHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Auto-fixing lint issues...", false)
}
