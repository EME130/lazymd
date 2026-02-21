---
title: Module Reference
sidebar_position: 2
description: All modules in the lazy-md codebase
---

# Module Reference

| Module | Description |
|--------|-------------|
| `Terminal.zig` | POSIX terminal control: raw mode, alternate screen, colors, styles |
| `Input.zig` | Reads keyboard and mouse events, parses escape sequences |
| `Buffer.zig` | Gap buffer with undo/redo stack and line tracking |
| `Editor.zig` | Vim modal editing, cursor management, rendering |
| `Renderer.zig` | Cell grid with diff-based flush to terminal |
| `ui/Layout.zig` | 3-panel layout computation and chrome rendering |
| `ui/Preview.zig` | Markdown-to-ASCII preview rendering |
| `markdown/syntax.zig` | Markdown tokenizer with 28 token types and color theme |
| `plugin.zig` | Plugin interface, manager, and helper utilities |
