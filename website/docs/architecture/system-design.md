---
title: System Design
sidebar_position: 1
description: Architecture overview of lazy-md
---

# System Design

lazy-md is built with clean module separation:

```
main.zig  (Event Loop)
  ├─ Terminal.zig    Raw mode, ANSI escape codes, colors
  ├─ Input.zig       Key + mouse event parsing
  ├─ Editor.zig      Vim modes, cursor, scroll
  │   ├─ Buffer.zig  Gap buffer, undo/redo, file I/O
  │   └─ markdown/syntax.zig  Tokenizer + theme
  ├─ ui/Layout.zig   3-panel geometry
  ├─ ui/Preview.zig  Rendered markdown preview
  ├─ highlight/
  │   ├─ Highlighter.zig        Highlighter vtable interface
  │   ├─ BuiltinHighlighter.zig Keyword-based tokenizer
  │   └─ languages.zig          16 language definitions
  ├─ Renderer.zig    Double-buffered cell grid
  └─ plugin.zig      Plugin system
```

## Key design decisions

- **Gap buffer** — Efficient for insert/delete at cursor position
- **Double buffering** — Diff-based rendering prevents flicker
- **Zero dependencies** — Uses only Zig stdlib + POSIX
- **Vtable plugins** — Type-erased interface for extensibility
- **Vtable highlighter** — Switchable backend for syntax highlighting (built-in keyword tokenizer or external LSP/tools)
