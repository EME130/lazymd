# LazyMD Roadmap

## What's Shipped

### Editor Core
- Vim-like modal editing (Normal, Insert, Command modes)
- lazygit-style 3-panel layout (file tree | editor | live preview)
- Markdown syntax highlighting (headers, bold, italic, code blocks, links, lists, blockquotes, strikethrough)
- Rendered markdown preview with ASCII styling
- Gap buffer with full undo/redo stack
- Double-buffered rendering with diff-based updates
- Mouse support (click to position, scroll, panel switching)
- Syntax highlighting for 16+ languages
- 12 built-in color themes (Dracula, Gruvbox, Nord, Catppuccin, Tokyo Night, etc.)
- `.rndm` file format (100% backward compatible with `.md`)
- Zero external dependencies (pure Zig, POSIX termios + ANSI escape codes)

### MCP Server
- 22 tools over JSON-RPC 2.0 (stdio)
- Document tools: `open_file`, `read_document`, `write_document`, `list_headings`, `edit_section`, `insert_text`, `delete_lines`, `search_content`, `get_structure`
- Navigation tools: `read_section`, `list_tasks`, `update_task`, `get_breadcrumb`, `move_section`, `read_section_range`
- Brain tools: `list_links`, `get_backlinks`, `get_graph`, `get_neighbors`, `find_path`, `get_orphans`, `get_hub_notes`
- Works with Claude Code, Gemini CLI, and any MCP-compatible client

### Brain (Knowledge Graph)
- `[[wiki-link]]` scanning across vaults
- Backlink discovery
- Force-directed ASCII graph visualization
- BFS path finding between notes
- Hub detection, orphan detection

### Plugin System
- 62 built-in plugins (zettelkasten, kanban, pomodoro, daily notes, templates, etc.)
- vtable-based interface for custom plugins
- Event hooks (file open/save, buffer changes, mode changes, cursor events)
- Custom commands and UI panels

---

## In Progress

### Web Editor
- Browser-based editing with WebSocket MCP bridge
- Same keybindings and editing experience as the terminal
- Real-time document sync

### Interfaces
- Terminal TUI (shipped)
- Web editor (in progress)
- Native desktop apps (planned)
- Embedded/IoT (planned) -- e-ink tablets, smart displays, embedded systems

---

## Planned

### Distribution
- Homebrew tap (`brew install lazymd`)
- AUR package
- Nix flake
- Pre-built binaries for Linux, macOS, Windows

### Editor Features
- Full-text search across vault
- Split panes / multi-buffer editing
- Fuzzy file finder
- Visual selection mode (`v`, `V`)
- Registers and yank/paste
- Macros

### AI / MCP
- ACP agent mode (host LazyMD as an agent in Zed/JetBrains)
- AI-assisted writing within the editor
- Context-aware tool suggestions

### Collaboration (LazyMD Cloud)
- Real-time multiplayer editing (collaboration)
- Shared vaults with role-based access
- Rankings and contribution leaderboards
- Built-in time tracking per file/project
- Multi-tenancy for teams and organizations
- Audit logs and compliance-ready infrastructure

### Version Control
- Built-in git integration
- Git-based sync between devices (free alternative to Obsidian Sync)
- Branch-based collaboration workflows

### Plugin Ecosystem
- Plugin marketplace / registry
- Third-party plugin loading
- Plugin API stabilization
