---
title: MCP Server
sidebar_position: 1
description: Use lazy-md as an MCP (Model Context Protocol) server for AI agents. 22 built-in tools for reading, navigating, editing markdown documents, and querying the knowledge graph via JSON-RPC 2.0 over stdio. Integrates with Claude Code and Gemini CLI.
keywords: [MCP server, Model Context Protocol, AI agent markdown, Claude Code MCP, Gemini CLI MCP, JSON-RPC markdown, lazy-md MCP, stdio server, wiki-links, backlinks, knowledge graph]
---

# MCP Server

lazy-md includes an MCP (Model Context Protocol) server that lets AI agents interact with markdown documents via JSON-RPC 2.0 over stdio.

## Starting the server

```bash
lazy-md --mcp-server              # Start MCP server
lazy-md --mcp-server myfile.md    # Start with file preloaded
```

## 22 tools exposed

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

### Brain tools

These tools query the knowledge graph built from `[[wiki-links]]` across your vault:

| Tool | Description |
|------|-------------|
| `list_links` | List all outgoing `[[wiki-links]]` from the current document with line numbers |
| `get_backlinks` | Find all files that link TO a given note. Defaults to current file |
| `get_graph` | Return the full connection graph as JSON (nodes, edges, stats). Optionally scoped to neighbors of a specific node |
| `get_neighbors` | Get all directly connected notes for a given note (outgoing + backlinks) with link counts |
| `find_path` | Find the shortest path between two notes in the knowledge graph |
| `get_orphans` | List all orphan notes with zero incoming and zero outgoing links |
| `get_hub_notes` | Find the most connected notes in the vault, ranked by total link count |

#### Example: `get_backlinks`

```json
{"method": "tools/call", "params": {"name": "get_backlinks", "arguments": {"note": "daily-note"}}}
```

Returns:
```json
[{"file": "index.md", "line": 5, "context": "See [[daily-note]] for details"}]
```

#### Example: `get_graph`

```json
{"method": "tools/call", "params": {"name": "get_graph", "arguments": {"node": "README", "depth": 2}}}
```

Returns:
```json
{"nodes": [...], "edges": [...], "stats": {"total_notes": 12, "total_links": 28, "orphans": 2}}
```

#### Example: `get_neighbors`

```json
{"method": "tools/call", "params": {"name": "get_neighbors", "arguments": {"note": "daily-note"}}}
```

Returns outgoing links, backlinks, and optionally all reachable notes within a given depth.

#### Example: `find_path`

```json
{"method": "tools/call", "params": {"name": "find_path", "arguments": {"from": "README", "to": "daily-note"}}}
```

Returns the shortest chain of notes connecting the two, e.g. `README -> project-plan -> daily-note`.

#### Example: `get_hub_notes`

```json
{"method": "tools/call", "params": {"name": "get_hub_notes", "arguments": {"limit": 5}}}
```

Returns the top 5 most connected notes ranked by total link count.

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
