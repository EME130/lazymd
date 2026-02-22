---
title: Panels & Layout
sidebar_position: 5
description: "lazy-md's multi-panel TUI layout inspired by lazygit: file tree, editor, live markdown preview, and brain graph view. Toggle and resize panels with keyboard shortcuts."
keywords: [multi panel layout, tui layout, terminal ui, lazygit inspired, file tree panel, markdown preview panel, brain graph view, knowledge graph]
---

# Panels & Layout

lazy-md features a multi-panel layout inspired by lazygit:

```
┌─────────────────────────────────────────────────┐
│  lazy-md v0.1.0   Tab:panels  1:tree  2:preview │
│                    3:brain  :q quit              │
├──────────┬─────────────────────┬─────────────────┤
│ Files    │  1  # Hello World   │ Preview         │
│          │  2                   │                 │
│ 📁 src   │  3  Some text here  │ Hello World     │
│ 📄 README│  4                   │ ═══════════     │
│          │  5  ## Section       │                 │
│          │                      │ Some text here  │
├──────────┴─────────────────────┴─────────────────┤
│ NORMAL  README.md                    Ln 1, Col 1 │
└───────────────────────────────────────────────────┘
```

## Panel shortcuts

| Key | Action |
|-----|--------|
| <kbd>Tab</kbd> | Cycle focus between panels |
| <kbd>Alt+1</kbd> | Toggle file tree panel |
| <kbd>Alt+2</kbd> | Toggle preview panel |
| <kbd>Alt+3</kbd> | Toggle brain graph panel |

Panel widths are computed responsively based on terminal size. The editor panel is always visible and takes up remaining space.

## Brain panel

The brain panel (<kbd>Alt+3</kbd>) shows an Obsidian-style knowledge graph of `[[wiki-links]]` across your vault. It replaces the preview panel (they are mutually exclusive).

```
┌─────────────────────┬─────────────────┐
│  Editor             │ Brain           │
│                     │                 │
│  See [[note-a]] and │  ◉ note-a       │
│  also [[note-b]].   │   ·  ·         │
│                     │  • note-b       │
│                     │   ·             │
│                     │  • note-c       │
│                     │                 │
│                     │  note-a out:2   │
│                     │          GRAPH  │
└─────────────────────┴─────────────────┘
```

When the brain panel is focused, use these keys:

| Key | Action |
|-----|--------|
| <kbd>j</kbd> / <kbd>k</kbd> | Move selection between nodes |
| <kbd>f</kbd> | Toggle local mode (only neighbors of current file) |
| <kbd>+</kbd> / <kbd>-</kbd> | Zoom in / out |
| <kbd>h</kbd> / <kbd>l</kbd> | Pan viewport left / right |
