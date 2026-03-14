# LazyMD

A terminal-based markdown editor written in Go. Inspired by [lazygit](https://github.com/jesseduffield/lazygit) and [lazydocker](https://github.com/jesseduffield/lazydocker).

![Go](https://img.shields.io/badge/Go-1.24-00ADD8?logo=go&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)
[![CI](https://github.com/EME130/lazymd/actions/workflows/ci.yml/badge.svg)](https://github.com/EME130/lazymd/actions/workflows/ci.yml)

```
+---------------------------------------------------------------------------+
| LazyMD v0.1.0                         Tab:panels  1:tree  2:preview      |
+------------+--------------------------------------+----------------------+
| Files      |  1  # Welcome to LazyMD             | Preview              |
|            |  2                                    |                      |
|  src       |  3  A **fast** terminal editor        | Welcome to LazyMD   |
|  README    |  4  with *vim* keybindings.           | ==================  |
|  main      |  5                                    |                      |
|            |  6  ## Features                       | A fast terminal      |
|            |  7                                    | editor with vim      |
|            |  8  - Syntax highlighting             | keybindings.         |
|            |  9  - Live preview                    |                      |
|            | 10  - `plugin system`                 | Features             |
|            |                                       | --------             |
|            |                                       | - Syntax highlighting|
|            |                                       | - Live preview       |
|            |                                       | - plugin system      |
+------------+--------------------------------------+----------------------+
| NORMAL  README.md                                          Ln 1, Col 1   |
|                                                                           |
+---------------------------------------------------------------------------+
```

## Install

```bash
git clone https://github.com/EME130/lazymd.git
cd lazymd
go build -o lm ./cmd/lm
```

Optionally copy the binary to your PATH:

```bash
cp lm /usr/local/bin/
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
go build ./cmd/lm    # Build
go run ./cmd/lm      # Run
go test ./...        # Run tests
gofmt -w .           # Format code
```

## :smoking: Buy Me a Cigarette

If **LazyMD** saves you time, send some Material Love:

Donate with Bitcoin: `bitcoin:bc1qzauvea9urya5r087n6mp69jwy5uchmynqcl74l?message=Donations`

Donate with Monero: `monero:84Jd3E44j54ZpmH2xAnJ6qJstnDtaJEmvK4pmvR78i5xcLGADnviwDpSa1uZMzCcrkVqH2u8E8hbBU4g4bn9sfB14t5Yjoi?recipient_name=EME130`

## License

MIT
