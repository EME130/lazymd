package main

import (
	"flag"
	"fmt"
	"os"

	tea "charm.land/bubbletea/v2"
	"github.com/EME130/lazymd/internal/agent"
	"github.com/EME130/lazymd/internal/buffer"
	"github.com/EME130/lazymd/internal/demo"
	"github.com/EME130/lazymd/internal/mcp"
	"github.com/EME130/lazymd/internal/ui"
	"github.com/EME130/lazymd/internal/web"
)

var version = "dev"

func main() {
	mcpServer := flag.Bool("mcp-server", false, "Start MCP server mode")
	mcpAlias := flag.Bool("mcp", false, "Start MCP server mode (alias)")
	webServer := flag.Bool("web-server", false, "Start web server mode")
	port := flag.Int("port", 8080, "Web server port")
	agentMode := flag.Bool("agent", false, "Start agent mode")
	demoMode := flag.Bool("demo", false, "Launch with demo vault")
	showVersion := flag.Bool("version", false, "Print version and exit")
	flag.Parse()

	if *showVersion {
		fmt.Println("lm " + version)
		return
	}

	switch {
	case *mcpServer || *mcpAlias:
		buf := buffer.New()
		srv := mcp.New(buf)

		// If a file argument was provided, preload it
		args := flag.Args()
		if len(args) > 0 {
			srv.SetFilePath(args[0])
			if err := srv.LoadFileIfNeeded(); err != nil {
				fmt.Fprintf(os.Stderr, "Failed to load file: %v\n", err)
				os.Exit(1)
			}
		}

		if err := srv.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "MCP server error: %v\n", err)
			os.Exit(1)
		}
	case *webServer:
		buf := buffer.New()
		srv := web.NewServer(buf, *port)

		args := flag.Args()
		if len(args) > 0 {
			srv.SetFilePath(args[0])
			if err := buf.LoadFile(args[0]); err != nil {
				fmt.Fprintf(os.Stderr, "Failed to load file: %v\n", err)
				os.Exit(1)
			}
		}

		if err := srv.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "Web server error: %v\n", err)
			os.Exit(1)
		}
	case *agentMode:
		// Agent mode: MCP stdio backend for bidirectional agent communication
		buf := buffer.New()
		mcpSrv := mcp.New(buf)

		args := flag.Args()
		if len(args) > 0 {
			mcpSrv.SetFilePath(args[0])
			if err := mcpSrv.LoadFileIfNeeded(); err != nil {
				fmt.Fprintf(os.Stderr, "Failed to load file: %v\n", err)
				os.Exit(1)
			}
		}

		ap := agent.NewPlugin()
		ap.SetBackend(agent.NewMcpBackend())
		ap.Connect(agent.Config{Transport: agent.TransportStdio})

		fmt.Fprintln(os.Stderr, "LazyMD agent mode: MCP stdio backend active")

		// Run MCP server (agent commands are received via MCP tools)
		if err := mcpSrv.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "Agent error: %v\n", err)
			os.Exit(1)
		}
	default:
		filePath := ""
		args := flag.Args()
		if len(args) > 0 {
			filePath = args[0]
		}
		if *demoMode {
			vaultPath, err := demo.CreateVault()
			if err != nil {
				fmt.Fprintf(os.Stderr, "Failed to create demo vault: %v\n", err)
				os.Exit(1)
			}
			defer demo.CleanupVault(vaultPath)
			if err := os.Chdir(vaultPath); err != nil {
				fmt.Fprintf(os.Stderr, "Failed to enter demo vault: %v\n", err)
				os.Exit(1)
			}
			filePath = "welcome.md"
		}
		app := ui.NewApp(filePath)
		p := tea.NewProgram(app)
		if _, err := p.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	}
}
