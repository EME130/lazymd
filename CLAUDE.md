# LazyMD

Terminal-based markdown editor written in Go. Inspired by lazygit/lazydocker.

## Tech Stack

- Language: Go (1.24.2+)
- TUI: Bubble Tea v2 + Lip Gloss + Glamour
- File format: `.rndm` (100% backward compatible with `.md`)

## Build Commands

```bash
go build ./cmd/lm     # Build the binary
go run ./cmd/lm       # Run the editor
go test ./...         # Run all tests
```

## Project Structure

```
cmd/
  lm/
    main.go              # Entry point (TUI, MCP, Web, Agent mode dispatch)
internal/
  buffer/
    buffer.go            # Gap buffer with undo/redo, line tracking, file I/O
  markdown/
    parser.go            # Markdown tokenizer (28 token types)
    syntax.go            # Token colors and theme mapping
  nav/
    navigator.go         # Navigation interface (heading paths, tasks, breadcrumbs)
  brain/
    graph.go             # Knowledge graph (nodes, edges, backlinks, BFS)
    scanner.go           # Recursive vault scanner for [[wiki-links]]
  highlight/
    highlighter.go       # Highlighter interface (switchable backend)
    builtin.go           # Keyword-based tokenizer (default backend)
    languages.go         # 16 language definitions
  editor/
    editor.go            # Vim modal editing, cursor, keybindings
  plugins/
    manager.go           # Plugin system (registry, lifecycle, events)
  themes/
    themes.go            # Color themes (Tokyo Night, Solarized, etc.)
  mcp/
    server.go            # MCP server (JSON-RPC 2.0 over stdio)
    tools.go             # 22 tool handlers
  ui/
    app.go               # Root Bubble Tea model (TUI shell)
    layout.go            # Panel layout (file_tree, editor, preview, brain)
    styles.go            # Lip Gloss style definitions
    filetree.go          # File tree panel
    preview.go           # Glamour markdown preview panel
    brainview.go         # Force-directed ASCII graph panel
    statusbar.go         # Status bar renderer
    commandbar.go        # Command bar renderer
  web/
    server.go            # HTTP + WebSocket server
    websocket.go         # RFC 6455 WebSocket implementation
  agent/
    agent.go             # Agent types, Backend interface, Plugin
    mcp_backend.go       # MCP stdio backend
    websocket_backend.go # WebSocket backend
go.mod
go.sum
```

## MCP Server Mode

lm is an MCP server. AI agents connect via stdio (JSON-RPC 2.0):

```bash
lm --mcp-server              # Start MCP server
lm --mcp-server myfile.md    # Start with file preloaded
```

**22 tools exposed**:

Document tools: `open_file`, `read_document`, `write_document`, `list_headings`, `edit_section`, `insert_text`, `delete_lines`, `search_content`, `get_structure`

Navigation tools (via `Navigator` interface):
- `read_section` — read section by heading path (e.g. `"Plan/Step 1/Subtask A"`)
- `list_tasks` — list task checkboxes, optionally scoped to a section and filtered by status
- `update_task` — toggle a task checkbox done/pending
- `get_breadcrumb` — get heading hierarchy for a line (e.g. `"Plan > Step 1 > Subtask A"`)
- `move_section` — relocate a section after/before another heading
- `read_section_range` — read numbered lines from a section with optional offset/limit

Brain tools (knowledge graph via `[[wiki-links]]`):
- `list_links` — list outgoing wiki-links from the current document
- `get_backlinks` — find files that link TO a given note
- `get_graph` — return connection graph as JSON (nodes, edges, stats)
- `get_neighbors` — get directly connected notes (outgoing + backlinks) with link counts
- `find_path` — find shortest path between two notes
- `get_orphans` — list notes with zero links (isolated)
- `get_hub_notes` — find most connected notes ranked by link count

### Claude Code
```bash
claude mcp add LazyMD -- /path/to/lm --mcp-server
```

### Gemini CLI
Add to `~/.gemini/settings.json`:
```json
{ "mcpServers": { "LazyMD": { "command": "/path/to/lm", "args": ["--mcp-server"] } } }
```

## Planned Features

- Built-in version control support
- Extensible plugin system
- ACP agent mode (host LazyMD as agent in Zed/JetBrains)

## Slash Commands

Go dev: `/release`, `/changelog`, `/issue-triage`, `/contrib-guide`

## Hooks

- `PostToolUse` on `Edit|Write`: auto-runs `gofmt` on `.go` files via `.claude/hooks/go-fmt.sh`

## Reference Projects

- [lazygit](https://github.com/jesseduffield/lazygit)
- [lazydocker](https://github.com/jesseduffield/lazydocker)
