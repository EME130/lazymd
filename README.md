# lazy-md

A terminal-based markdown editor written in Zig. Inspired by [lazygit](https://github.com/jesseduffield/lazygit) and [lazydocker](https://github.com/jesseduffield/lazydocker).

![Zig](https://img.shields.io/badge/Zig-0.15.1-f7a41d?logo=zig&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)
![Zero Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)
[![CI](https://github.com/user/lazy-md/actions/workflows/ci.yml/badge.svg)](https://github.com/user/lazy-md/actions/workflows/ci.yml)

## Screenshot

```
┌──────────────────────────────────────────────────────────────────────────┐
│ lazy-md v0.1.0                         Tab:panels  1:tree  2:preview    │
├────────────┬──────────────────────────────────────┬──────────────────────┤
│ Files      │  1  # Welcome to lazy-md             │ Preview              │
│            │  2                                    │                      │
│  📁 src    │  3  A **fast** terminal editor        │ Welcome to lazy-md   │
│  📄 README │  4  with *vim* keybindings.           │ ══════════════════   │
│  📄 main   │  5                                    │                      │
│            │  6  ## Features                       │ A fast terminal      │
│            │  7                                    │ editor with vim      │
│            │  8  - Syntax highlighting             │ keybindings.         │
│            │  9  - Live preview                    │                      │
│            │ 10  - `plugin system`                 │ Features             │
│            │                                       │ ──────────           │
│            │                                       │ • Syntax highlighting│
│            │                                       │ • Live preview       │
│            │                                       │ • plugin system      │
├────────────┴──────────────────────────────────────┴──────────────────────┤
│ NORMAL  README.md                                          Ln 1, Col 1  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Features

- **Vim-like modal editing** — Normal, Insert, and Command modes with familiar keybindings
- **Markdown syntax highlighting** — Headers, bold, italic, code blocks, links, lists, blockquotes, strikethrough
- **lazygit-style 3-panel layout** — File tree | Editor | Live Preview
- **Rendered markdown preview** — ASCII-styled preview with headers, bullets, code boxes, and styled text
- **Mouse support** — Click to position cursor, scroll with mouse wheel, click panels to switch focus
- **Plugin system** — Extensible architecture for community plugins with commands, events, and custom panels
- **Gap buffer** with full undo/redo stack
- **Double-buffered rendering** with diff-based updates for flicker-free display
- **`.rndm` file format** — 100% backward compatible with `.md`
- **Zero external dependencies** — Pure Zig, built on POSIX termios + ANSI escape codes

## Install

Requires [Zig](https://ziglang.org/download/) 0.15.1+.

```bash
git clone https://github.com/user/lazy-md.git
cd lazy-md
zig build
```

The binary is at `zig-out/bin/lazy-md`. Optionally copy it to your PATH:

```bash
cp zig-out/bin/lazy-md /usr/local/bin/
```

Pre-built binaries for Linux and macOS are available on the [Releases](https://github.com/user/lazy-md/releases) page.

## Quick Start

```bash
# Open a file
lazy-md myfile.md

# Open in current directory (shows file tree)
lazy-md

# Create a new file
lazy-md notes.md
```

Once inside:
1. Press `i` to enter Insert mode
2. Type your markdown
3. Press `Escape` to go back to Normal mode
4. Type `:w` + `Enter` to save
5. Type `:q` + `Enter` to quit

## Keybindings

### Normal Mode

| Key | Action |
|-----|--------|
| `h` `j` `k` `l` | Move cursor left/down/up/right |
| `w` `b` `e` | Word forward/backward/end |
| `0` `$` `^` | Line start/end/first non-blank |
| `gg` `G` | Go to top/bottom |
| `{count}{motion}` | Repeat motion (e.g., `5j` = move down 5 lines) |
| `i` `a` `o` `O` | Enter insert mode (before/after/below/above) |
| `I` `A` | Insert at line start/end |
| `x` | Delete character |
| `dd` | Delete line |
| `u` | Undo |
| `Ctrl+R` | Redo |
| `Ctrl+D` `Ctrl+U` | Half-page down/up |
| `Ctrl+S` | Save |
| `:` | Enter command mode |
| `Tab` | Cycle panel focus |
| `Alt+1` | Toggle file tree |
| `Alt+2` | Toggle preview |

### Insert Mode

| Key | Action |
|-----|--------|
| Type normally | Insert text |
| `Escape` | Return to normal mode |
| `Backspace` `Delete` | Delete character |
| `Tab` | Insert 4 spaces |
| Arrow keys | Move cursor |

### Commands

| Command | Action |
|---------|--------|
| `:w` | Save |
| `:q` | Quit (warns on unsaved changes) |
| `:q!` | Force quit |
| `:wq` `:x` | Save and quit |
| `:w <path>` | Save as |
| `:e <path>` | Open file |

### Mouse

| Action | Effect |
|--------|--------|
| Left click (editor) | Position cursor |
| Left click (panel) | Switch focus to panel |
| Scroll wheel | Scroll content up/down |

## Preview Panel

The preview panel renders your markdown in a styled ASCII format:

- **Headers** display as bold text with `═══` (h1) or `───` (h2) underlines
- **Bold** and *italic* text is rendered with ANSI styles (markers stripped)
- `Inline code` appears with a highlighted background
- **Lists** use `•` bullet characters
- **Blockquotes** have `│` borders
- **Code blocks** are enclosed in box-drawing borders with syntax coloring
- **Horizontal rules** render as full-width `─── ` lines
- **Links** show as underlined text

Toggle the preview with `Alt+2`.

## Plugin System

lazy-md supports an extensible plugin architecture. Plugins can:

- Register custom commands
- Hook into editor events (file open/save, buffer changes, mode changes)
- Add custom UI panels
- Extend the editor's functionality

### Creating a Plugin

1. Create a Zig file in `src/plugins/`
2. Implement the plugin interface (see [Plugin Guide](docs/PLUGIN_GUIDE.md))
3. Register with `plugin.makePlugin()` in `main.zig`

See the full [Plugin Development Guide](docs/PLUGIN_GUIDE.md) for examples and API reference.

## Architecture

```
src/
  main.zig               Entry point, CLI args, event loop
  Terminal.zig            Raw mode, ANSI escape codes, colors, mouse
  Input.zig               Key + mouse event parsing, escape sequences
  Buffer.zig              Gap buffer, undo/redo, file I/O
  Editor.zig              Vim modes, cursor, scroll, rendering
  Renderer.zig            Double-buffered cell grid, diff flush
  markdown/syntax.zig     Markdown tokenizer + color theme
  ui/Layout.zig           3-panel layout engine
  ui/Preview.zig          Rendered markdown preview
  plugin.zig              Plugin system (interface, manager, helpers)
```

## Development

```bash
zig build          # Build
zig build run      # Run
zig build test     # Run tests
zig fmt src/       # Format code
```

### CI/CD

The project uses GitHub Actions for:
- **CI** — Runs tests on Linux and macOS, checks formatting
- **Release** — Builds binaries for Linux/macOS on tag push
- **Pages** — Deploys the website from `website/`

## Documentation

- [Website](https://lazymd.com) — Landing page and online docs
- [Plugin Guide](docs/PLUGIN_GUIDE.md) — How to build plugins
- [API Reference](website/docs.html) — Full documentation

## License

MIT
