package plugins

import (
	"fmt"

	"github.com/EME130/lazymd/internal/editor"
)

type McpConnectorPlugin struct{}

func (p *McpConnectorPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "mcp-connector",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "MCP protocol for AI agent access",
	}
}

func (p *McpConnectorPlugin) Init(ed editor.PluginEditor) {}

func (p *McpConnectorPlugin) OnEvent(event *PluginEvent) {}

func (p *McpConnectorPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "mcp", Description: "Export vault context", Handler: mcpHandler},
		{Name: "mcp.export", Description: "Export current file", Handler: mcpExportHandler},
		{Name: "mcp.context", Description: "Show MCP context", Handler: mcpContextHandler},
	}
}

func mcpHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("MCP: exporting vault context...", false)
}

func mcpExportHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus(fmt.Sprintf("Exporting: %s", ed.FilePath()), false)
}

func mcpContextHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("MCP context: ready for AI agent connection", false)
}
