# LazyMD

A terminal-based markdown editor written in Zig. Inspired by [lazygit](https://github.com/jesseduffield/lazygit) and [lazydocker](https://github.com/jesseduffield/lazydocker).

![Zig](https://img.shields.io/badge/Zig-0.15.1-f7a41d?logo=zig&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)
![Zero Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)
[![CI](https://github.com/EME130/lazymd/actions/workflows/ci.yml/badge.svg)](https://github.com/EME130/lazymd/actions/workflows/ci.yml)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ LazyMD v0.1.0                         Tab:panels  1:tree  2:preview    │
├────────────┬──────────────────────────────────────┬──────────────────────┤
│ Files      │  1  # Welcome to LazyMD             │ Preview              │
│            │  2                                    │                      │
│  📁 src    │  3  A **fast** terminal editor        │ Welcome to LazyMD   │
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

## Install

**Linux:**

```bash
git clone https://github.com/EME130/lazymd.git
cd lazymd
zig build
```

The binary is at `zig-out/bin/lm`. Optionally copy it to your PATH:

```bash
cp zig-out/bin/lm /usr/local/bin/
```

Pre-built binaries are available on the [Releases](https://github.com/EME130/lazymd/releases) page.

## Quick Start

```bash
lm myfile.md       # Open a file
lm                  # Open current directory (file tree)
lm notes.md        # Create a new file
```

Press `i` to insert, `Escape` to return to normal mode, `:w` to save, `:q` to quit.

## MCP Server

LazyMD is an [MCP](https://modelcontextprotocol.io/) server with 22 built-in tools. AI agents connect over stdio to read, navigate, and edit markdown documents.

```bash
lm --mcp-server              # Start MCP server
lm --mcp-server myfile.md    # With a file preloaded
```

```bash
# Claude Code
claude mcp add LazyMD -- /path/to/lm --mcp-server
```

```json
// Gemini CLI (~/.gemini/settings.json)
{ "mcpServers": { "LazyMD": { "command": "/path/to/lm", "args": ["--mcp-server"] } } }
```

## Documentation

- [Website](https://lazymd.com)
- [Plugin Guide](docs/PLUGIN_GUIDE.md)
- [Roadmap](ROADMAP.md)

## Development

```bash
zig build          # Build
zig build run      # Run
zig build test     # Run tests
zig fmt src/       # Format code
```

## :smoking: Buy Me a Cigarette

If LazyMD saves you time, send some Monero:

```
84Jd3E44j54ZpmH2xAnJ6qJstnDtaJEmvK4pmvR78i5xcLGADnviwDpSa1uZMzCcrkVqH2u8E8hbBU4g4bn9sfB14t5Yjoi
```

## License

MIT
