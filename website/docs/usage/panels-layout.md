---
title: Panels & Layout
sidebar_position: 5
description: "lazy-md's 3-panel TUI layout inspired by lazygit: file tree, editor, and live markdown preview. Toggle and resize panels with keyboard shortcuts."
keywords: [three panel layout, tui layout, terminal ui, lazygit inspired, file tree panel, markdown preview panel]
---

# Panels & Layout

lazy-md features a 3-panel layout inspired by lazygit:

```
┌─────────────────────────────────────────────────┐
│  lazy-md v0.1.0        Tab:panels  :q quit      │
├──────────┬─────────────────────┬─────────────────┤
│ Files    │  1  # Hello World   │ Preview         │
│          │  2                   │                 │
│ 📁 src   │  3  Some text here  │ Hello World     │
│ 📄 README│  4                   │ ═══════════     │
│          │  5  ## Section       │                 │
│          │                      │ Some text here  │
├──────────┴─────────────────────┴─────────────────┤
│ NORMAL  README.md                    Ln 1, Col 1 │
│                                                   │
└───────────────────────────────────────────────────┘
```

| Key | Action |
|-----|--------|
| <kbd>Tab</kbd> | Cycle focus between panels |
| <kbd>Alt+1</kbd> | Toggle file tree panel |
| <kbd>Alt+2</kbd> | Toggle preview panel |

Panel widths are computed responsively based on terminal size. The editor panel is always visible and takes up remaining space.
