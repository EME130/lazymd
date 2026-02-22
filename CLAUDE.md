# lazy-md

Terminal-based markdown editor written in Zig. Inspired by lazygit/lazydocker.

## Tech Stack

- Language: Zig (0.13.0+)
- File format: `.rndm` (100% backward compatible with `.md`)

## Build Commands

```bash
zig build        # Build the project
zig build run    # Run the editor
zig build test   # Run tests
```

## Project Structure

```
src/
  main.zig           # Entry point (TUI + MCP mode dispatch)
  brain/
    Graph.zig          # Knowledge graph (nodes, edges, backlinks, BFS)
    Scanner.zig        # Recursive vault scanner for [[wiki-links]]
  ui/
    Layout.zig         # Panel layout (file_tree, editor, preview, brain)
    Preview.zig        # Rendered markdown preview panel
    BrainView.zig      # Force-directed ASCII graph panel
  mcp/
    Server.zig       # MCP server (JSON-RPC 2.0 over stdio)
    tools.json       # Tool definitions (embedded at compile time)
  nav/
    Navigator.zig        # Navigation vtable interface (switchable backend)
    BuiltinNavigator.zig # Built-in implementation using Buffer
  highlight/
    Highlighter.zig        # Highlighter vtable interface (switchable backend)
    BuiltinHighlighter.zig # Keyword-based tokenizer (default backend)
    languages.zig          # 16 language definitions
build.zig            # Build configuration
build.zig.zon        # Package manifest
```

## MCP Server Mode

lazy-md is an MCP server. AI agents connect via stdio (JSON-RPC 2.0):

```bash
lazy-md --mcp-server              # Start MCP server
lazy-md --mcp-server myfile.md    # Start with file preloaded
```

**18 tools exposed**:

Document tools: `open_file`, `read_document`, `write_document`, `list_headings`, `edit_section`, `insert_text`, `delete_lines`, `search_content`, `get_structure`

Navigation tools (via switchable `Navigator` vtable):
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

### Claude Code
```bash
claude mcp add lazy-md -- /path/to/lazy-md --mcp-server
```

### Gemini CLI
Add to `~/.gemini/settings.json`:
```json
{ "mcpServers": { "lazy-md": { "command": "/path/to/lazy-md", "args": ["--mcp-server"] } } }
```

## Planned Features

- Built-in version control support
- Extensible plugin system
- ACP agent mode (host lazy-md as coding agent in Zed/JetBrains)

## Slash Commands

Zig dev: `/zig-test`, `/zig-check`, `/zig-build`, `/zig-debug`
OSS: `/release`, `/changelog`, `/issue-triage`, `/contrib-guide`

## Hooks

- `PostToolUse` on `Edit|Write`: auto-runs `zig fmt` on `.zig` files via `.claude/hooks/zig-fmt.sh`

## Reference Projects

- [lazygit](https://github.com/jesseduffield/lazygit)
- [lazydocker](https://github.com/jesseduffield/lazydocker)
