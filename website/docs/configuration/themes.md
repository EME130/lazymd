---
title: Themes
sidebar_position: 2
description: 12 built-in color themes for lazy-md — Dracula, Gruvbox, Nord, Catppuccin, Tokyo Night, and more. Syntax highlighting colors for 16 languages with truecolor support.
keywords: [terminal editor themes, dracula theme, gruvbox, nord, catppuccin, color themes, syntax highlighting colors, lazy-md themes]
---

# Themes

lazy-md ships with **12 built-in color themes**. Switch themes using command mode:

| Command | Action |
|---------|--------|
| `:theme` | Show current theme |
| `:theme <name>` | Switch to named theme |
| `:theme.cycle` | Cycle to next theme |
| `:theme.list` | List all available themes |

## Available Themes

| Name | Description |
|------|-------------|
| `default` | Default lazy-md theme (16-color terminal) |
| `dracula` | Dracula dark theme |
| `gruvbox` | Gruvbox retro groove |
| `nord` | Arctic, north-bluish clean |
| `solarized` | Solarized dark precision colors |
| `monokai` | Monokai classic dark |
| `catppuccin` | Catppuccin mocha soothing pastels |
| `tokyo-night` | Tokyo Night vibrant dark |
| `one-dark` | Atom One Dark |
| `rose-pine` | Rose Pine all natural |
| `kanagawa` | Kanagawa wave inspired by Hokusai |
| `everforest` | Everforest comfortable green |

Each theme defines colors for UI chrome, syntax highlighting, mode indicators, and preview rendering. Themes use RGB colors for truecolor terminals with fallback to 256-color.

## Syntax Highlighting Colors

All 12 themes include dedicated syntax highlighting colors for code blocks. These are the `syn_*` fields in each theme definition:

| Field | Purpose |
|-------|---------|
| `syn_keyword` | Language keywords (`const`, `fn`, `def`, `if`, etc.) |
| `syn_type` | Type names (`u32`, `String`, `int`, etc.) |
| `syn_string` | String literals |
| `syn_number` | Numeric literals |
| `syn_comment` | Comments (line and block) |
| `syn_builtin` | Built-in functions and macros |
| `syn_operator` | Operators (`=`, `+`, `<`, etc.) |
| `syn_punctuation` | Punctuation (`(`, `)`, `;`, etc.) |
| `syn_annotation` | Annotations/attributes (`@import`, `#[derive]`, etc.) |
| `syn_normal` | Default/unclassified tokens |

### Supported Languages

Syntax highlighting is available for 16 languages: Zig, Python, JavaScript, TypeScript, Rust, Go, C, C++, Bash, JSON, YAML, HTML, CSS, SQL, Lua, Ruby, and Java.
