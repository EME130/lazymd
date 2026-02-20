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
  mcp/
    Server.zig       # MCP server (JSON-RPC 2.0 over stdio)
    tools.json       # Tool definitions (embedded at compile time)
build.zig            # Build configuration
build.zig.zon        # Package manifest
```

## MCP Server Mode

lazy-md is an MCP server. AI agents connect via stdio (JSON-RPC 2.0):

```bash
lazy-md --mcp-server              # Start MCP server
lazy-md --mcp-server myfile.md    # Start with file preloaded
```

**9 tools exposed**: `open_file`, `read_document`, `write_document`, `list_headings`, `edit_section`, `insert_text`, `delete_lines`, `search_content`, `get_structure`

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
