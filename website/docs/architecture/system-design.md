---
title: System Design
sidebar_position: 1
description: Architecture overview of LazyMD — gap buffer, Bubble Tea TUI, interface-based plugin system, and package separation.
keywords: [LazyMD architecture, gap buffer, Bubble Tea, Go terminal editor, interface pattern, system design]
---

# System Design

lm is built with clean package separation:

```
cmd/lm/main.go  (Entry Point — mode dispatch)
  internal/
    buffer/          Gap buffer, undo/redo, file I/O
    markdown/        Tokenizer (28 token types) + theme
    editor/          Vim modes, cursor, keybindings
    nav/             Navigation interface (headings, tasks, breadcrumbs)
    brain/           Knowledge graph + vault scanner
    highlight/
      highlighter.go       Highlighter interface
      builtin.go           Keyword-based tokenizer
      languages.go         16 language definitions
    plugins/         Plugin system (registry, lifecycle, events)
    themes/          Color themes
    ui/              Bubble Tea TUI (app, layout, panels, styles)
    mcp/             MCP server (JSON-RPC 2.0 over stdio)
    web/             HTTP + WebSocket server
    agent/           Agent backend interface + implementations
```

## Key design decisions

- **Gap buffer** — Efficient for insert/delete at cursor position
- **Bubble Tea v2** — Elm Architecture TUI framework for composable models
- **Lip Gloss** — Declarative terminal styling
- **Glamour** — Markdown rendering for preview panel
- **Interface-based plugins** — Go interfaces for extensibility
- **Interface-based highlighter** — Switchable backend for syntax highlighting
