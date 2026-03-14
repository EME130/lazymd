---
title: Package Reference
sidebar_position: 2
description: Complete package reference for the LazyMD codebase — buffer, markdown, editor, nav, brain, highlight, plugins, themes, ui, mcp, web, and agent packages.
keywords: [LazyMD packages, Go packages, terminal editor internals, buffer package, code reference]
---

# Package Reference

| Package | Description |
|---------|-------------|
| `buffer` | Gap buffer with undo/redo stack and line tracking |
| `markdown` | Markdown tokenizer with 28 token types and color theme |
| `editor` | Vim modal editing, cursor management, keybindings |
| `nav` | Navigation interface (heading paths, tasks, breadcrumbs, sections) |
| `brain` | Knowledge graph with BFS, backlinks, and vault scanner |
| `highlight` | Highlighter interface with built-in keyword tokenizer |
| `plugins` | Plugin system with registry, lifecycle management, and events |
| `themes` | Color themes (Tokyo Night, Solarized, etc.) |
| `ui` | Bubble Tea TUI shell, panel layout, file tree, preview, brain view |
| `mcp` | MCP server with 22 tools over JSON-RPC 2.0 stdio |
| `web` | HTTP server with RFC 6455 WebSocket support |
| `agent` | Agent backend interface with MCP stdio and WebSocket implementations |
