---
title: Brain — Knowledge Graph
sidebar_position: 7
description: "Obsidian-style knowledge graph for lazy-md. Visualize [[wiki-link]] connections between notes with a force-directed ASCII layout, backlink discovery, and graph queries via MCP."
keywords: [brain, knowledge graph, wiki-links, backlinks, obsidian graph, force directed layout, note connections, graph view]
---

# Brain — Knowledge Graph

The brain feature gives lazy-md an Obsidian-style knowledge graph. It scans your vault for `[[wiki-links]]` and visualizes connections between notes as a force-directed ASCII graph.

## How it works

1. **Scanner** — Recursively walks your project directory for `.md` and `.rndm` files
2. **Link extraction** — Finds all `[[wiki-links]]` in each file (supports `[[target|display]]` alias syntax)
3. **Graph building** — Creates nodes (files) and edges (links between files), computes backlinks
4. **Visualization** — Force-directed layout renders nodes and edges as ASCII art in a TUI panel

## Opening the brain panel

Press <kbd>Alt+3</kbd> to toggle the brain panel. It replaces the preview panel (they are mutually exclusive).

## Navigation

When the brain panel is focused (click it or use <kbd>Tab</kbd> to cycle):

| Key | Action |
|-----|--------|
| <kbd>j</kbd> / <kbd>k</kbd> or arrows | Move selection between nodes |
| <kbd>f</kbd> | Toggle local mode (show only neighbors of current file) |
| <kbd>+</kbd> / <kbd>-</kbd> | Zoom in / out |
| <kbd>h</kbd> / <kbd>l</kbd> | Pan viewport left / right |

## Display

- **Current file** — Shown with a `◉` marker in green
- **Selected node** — Shown with a `○` marker in cyan
- **Other nodes** — Shown with a `•` marker
- **Edges** — Drawn as `·` dot trails between connected nodes
- **Status bar** — Shows selected node name, outgoing link count, and backlink count
- **Mode indicator** — `GRAPH` (full vault) or `LOCAL` (neighbors only)

## Wiki-link syntax

The scanner recognizes these wiki-link formats:

```markdown
[[note-name]]              → links to note-name.md
[[note-name|Display Text]] → links to note-name.md (alias)
[[path/to/note]]           → links to note.md (path prefix stripped)
```

Link resolution is case-insensitive — `[[readme]]` resolves to `README.md`.

## MCP brain tools

Seven MCP tools expose the knowledge graph to AI agents:

### `list_links`

List all outgoing `[[wiki-links]]` from the current document.

```json
{"method": "tools/call", "params": {"name": "list_links"}}
```

### `get_backlinks`

Find all files that link to a given note.

```json
{"method": "tools/call", "params": {"name": "get_backlinks", "arguments": {"note": "daily-note"}}}
```

### `get_graph`

Return the full connection graph as JSON. Optionally scope to neighbors of a node.

```json
{"method": "tools/call", "params": {"name": "get_graph", "arguments": {"node": "README", "depth": 2}}}
```

### `get_neighbors`

Get all directly connected notes — outgoing links and backlinks — with link counts. Great for exploring the local graph.

```json
{"method": "tools/call", "params": {"name": "get_neighbors", "arguments": {"note": "daily-note", "depth": 2}}}
```

### `find_path`

Find the shortest path between two notes. Useful for understanding how ideas connect across the vault.

```json
{"method": "tools/call", "params": {"name": "find_path", "arguments": {"from": "README", "to": "daily-note"}}}
```

### `get_orphans`

List all notes with zero links — not connected to the knowledge graph.

```json
{"method": "tools/call", "params": {"name": "get_orphans"}}
```

### `get_hub_notes`

Find the most connected notes in the vault, ranked by total link count.

```json
{"method": "tools/call", "params": {"name": "get_hub_notes", "arguments": {"limit": 5}}}
```

## Architecture

```
src/brain/
  Graph.zig     — Graph data structure (nodes, edges, backlinks, BFS neighbors)
  Scanner.zig   — Recursive vault scanner with wiki-link extraction
src/ui/
  BrainView.zig — Force-directed ASCII graph panel with interactive navigation
```

The graph is built once at startup by scanning the working directory. The force-directed layout runs iteratively until convergence (typically 30-50 iterations).
