---
title: MCP Server
sidebar_position: 1
description: Using lazy-md as an MCP server for AI agents
---

# MCP Server

lazy-md includes an MCP (Model Context Protocol) server that lets AI agents interact with markdown documents via JSON-RPC 2.0 over stdio.

## Starting the server

```bash
lazy-md --mcp-server              # Start MCP server
lazy-md --mcp-server myfile.md    # Start with file preloaded
```

## 15 tools exposed

### Document tools

| Tool | Description |
|------|-------------|
| `open_file` | Open a markdown file |
| `read_document` | Read the full document content |
| `write_document` | Write/replace document content |
| `list_headings` | List all headings in the document |
| `edit_section` | Edit a section by heading |
| `insert_text` | Insert text at a position |
| `delete_lines` | Delete a range of lines |
| `search_content` | Search for text in the document |
| `get_structure` | Get the document structure |

### Navigation tools

These use a switchable `Navigator` vtable interface:

| Tool | Description |
|------|-------------|
| `read_section` | Read section by heading path (e.g. `"Plan/Step 1/Subtask A"`) |
| `list_tasks` | List task checkboxes, optionally scoped to a section and filtered by status |
| `update_task` | Toggle a task checkbox done/pending |
| `get_breadcrumb` | Get heading hierarchy for a line (e.g. `"Plan > Step 1 > Subtask A"`) |
| `move_section` | Relocate a section after/before another heading |
| `read_section_range` | Read numbered lines from a section with optional offset/limit |

## Integration with Claude Code

```bash
claude mcp add lazy-md -- /path/to/lazy-md --mcp-server
```

## Integration with Gemini CLI

Add to `~/.gemini/settings.json`:

```json
{
  "mcpServers": {
    "lazy-md": {
      "command": "/path/to/lazy-md",
      "args": ["--mcp-server"]
    }
  }
}
```
