package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type VaultStatsPlugin struct{}

func (p *VaultStatsPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "vault-stats",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Vault analytics and statistics",
	}
}

func (p *VaultStatsPlugin) Init(ed editor.PluginEditor) {}

func (p *VaultStatsPlugin) OnEvent(event *PluginEvent) {}

func (p *VaultStatsPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "vault", Description: "Show vault statistics", Handler: vaultHandler},
		{Name: "vault.health", Description: "Check vault health", Handler: vaultHealthHandler},
		{Name: "vault.summary", Description: "Insert vault summary", Handler: vaultSummaryHandler},
	}
}

func vaultHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()

	lineCount := buf.LineCount()
	content := buf.Content()
	wordCount := len(strings.Fields(content))
	charCount := len(content)

	msg := fmt.Sprintf("Lines: %d, Words: %d, Characters: %d", lineCount, wordCount, charCount)
	ed.SetStatus(msg, false)
}

func vaultHealthHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	issues := []string{}

	// Check for empty lines at start
	if buf.LineCount() > 0 && strings.TrimSpace(buf.Line(0)) == "" {
		issues = append(issues, "empty first line")
	}

	// Check for headings
	hasHeading := false
	for i := 0; i < buf.LineCount(); i++ {
		line := strings.TrimSpace(buf.Line(i))
		if strings.HasPrefix(line, "#") {
			hasHeading = true
			break
		}
	}

	if !hasHeading {
		issues = append(issues, "no headings found")
	}

	if len(issues) == 0 {
		ed.SetStatus("Vault health: OK", false)
	} else {
		msg := fmt.Sprintf("Vault health: %s", strings.Join(issues, ", "))
		ed.SetStatus(msg, false)
	}
}

func vaultSummaryHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	lineCount := buf.LineCount()
	content := buf.Content()
	wordCount := len(strings.Fields(content))

	summary := fmt.Sprintf("## Vault Summary\n\nNotes: %d\nWords: %d\n\n", lineCount, wordCount)
	buf.InsertString(offset, summary)

	ed.SetStatus("Vault summary inserted", false)
}
