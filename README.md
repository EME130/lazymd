# lazy-md

A terminal-based markdown editor written in Zig. Inspired by [lazygit](https://github.com/jesseduffield/lazygit) and [lazydocker](https://github.com/jesseduffield/lazydocker).

![Zig](https://img.shields.io/badge/Zig-0.15.1-f7a41d?logo=zig&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)
![Zero Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)

## Features

- **Vim-like modal editing** - Normal, Insert, and Command modes with familiar keybindings
- **Markdown syntax highlighting** - Headers, bold, italic, code blocks, links, lists, blockquotes, strikethrough
- **lazygit-style 3-panel layout** - File tree | Editor | Preview
- **Gap buffer** with undo/redo stack
- **Double-buffered rendering** with diff-based updates for flicker-free display
- **`.rndm` file format** - 100% backward compatible with `.md`
- **Zero external dependencies** - Pure Zig, built on POSIX termios + ANSI escape codes

## Install

Requires [Zig](https://ziglang.org/download/) 0.15.1+.

```bash
git clone https://github.com/user/lazy-md.git
cd lazy-md
zig build
```

The binary is at `zig-out/bin/lazy-md`.

## Usage

```bash
# Open a file
lazy-md myfile.md

# Open in current directory (shows file tree)
lazy-md
```

### Keybindings

#### Normal Mode

| Key | Action |
|-----|--------|
| `h` `j` `k` `l` | Move cursor left/down/up/right |
| `w` `b` `e` | Word forward/backward/end |
| `0` `$` `^` | Line start/end/first non-blank |
| `gg` `G` | Go to top/bottom |
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

#### Insert Mode

| Key | Action |
|-----|--------|
| Type normally | Insert text |
| `Escape` | Return to normal mode |
| `Backspace` `Delete` | Delete character |
| `Tab` | Insert 4 spaces |
| Arrow keys | Move cursor |

#### Commands

| Command | Action |
|---------|--------|
| `:w` | Save |
| `:q` | Quit (warns on unsaved changes) |
| `:q!` | Force quit |
| `:wq` `:x` | Save and quit |
| `:w <path>` | Save as |
| `:e <path>` | Open file |

## Architecture

```
src/
  main.zig             Entry point, CLI args, event loop
  Terminal.zig          Raw mode, ANSI escape codes, colors
  Input.zig             Key reading, escape sequence decoding
  Buffer.zig            Gap buffer, undo/redo, file I/O
  Editor.zig            Vim modes, cursor, scroll, rendering
  Renderer.zig          Double-buffered cell grid, diff flush
  markdown/syntax.zig   Markdown tokenizer + color theme
  ui/Layout.zig         3-panel layout engine
```

## Development

```bash
zig build          # Build
zig build run      # Run
zig build test     # Run tests (19 tests)
```

## License

MIT
