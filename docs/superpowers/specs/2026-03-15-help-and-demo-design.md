# Help Command & Demo Mode Design

## Overview

Two new features for LazyMD:

1. **`:help` command** — Scoped help system with topic subcommands. Each topic loads a focused markdown file into the editor buffer.
2. **`--demo` flag** — Launches LazyMD with a pre-built sample vault showcasing all major features (brain graph, plugins, navigation, MCP).

## Architecture

### New Packages

```
internal/
  help/
    help.go              # Topic registry, GetTopic() + GetDynamicTopic()
    content/             # Embedded markdown files (//go:embed)
      overview.md        # :help
      keys.md            # :help keys
      brain.md           # :help brain
      commands.md        # :help commands
      mcp.md             # :help mcp
      panels.md          # :help panels
  demo/
    demo.go              # CreateVault() / CleanupVault()
    vault/               # Embedded sample vault (//go:embed)
      welcome.md
      project-plan.md
      knowledge/
        golang.md
        markdown.md
        wiki-links.md
        zettelkasten.md
      daily-notes/
        2026-03-15.md
      kanban.md
```

### Modified Files

- `cmd/lm/main.go` — Add `--demo` flag, call `demo.CreateVault()` before TUI launch, cleanup on exit.
- `internal/editor/command.go` — Add `help` case in `executeCommand()`, placed after built-in commands but before the `default` case that delegates to plugins.
- `internal/buffer/buffer.go` — Add `SetContent(text string)` method that resets the gap buffer from a string (same logic as `LoadFile` but without disk I/O: clears gap, rebuilds line starts, resets undo/redo, sets `dirty = false`).
- `internal/editor/editor.go` — Add `PluginSummary`/`CommandSummary` DTO types, extend `CommandExecutor` interface with `ListPlugins()`/`ListCommands()`, and add `LoadContent(name string, content string)` method to `EditorModel` that calls `e.Buf.SetContent(content)` and sets `e.File = name`.
- `internal/plugins/plugin.go` — Add `ListPlugins()` and `ListCommands()` methods to `PluginManager` that return editor DTO types.

No changes to: plugin system, UI layout, brain, buffer, or MCP.

## Help System

### Topic Registry

`help.go` uses `//go:embed content/*.md` to bundle all static help files. Exposes:

```go
// GetTopic returns the markdown content for a help topic.
// Returns content and true if found, empty string and false if not.
func GetTopic(name string) (string, bool)

// Topics returns all available topic names.
func Topics() []string
```

Available topics:
| Command | Topic File | Description |
|---------|-----------|-------------|
| `:help` | `overview.md` | Welcome + topic listing |
| `:help keys` | `keys.md` | Keybindings reference |
| `:help brain` | `brain.md` | Knowledge graph & wiki-links |
| `:help plugins` | (dynamic) | All plugins + their commands |
| `:help commands` | `commands.md` | Built-in editor commands |
| `:help mcp` | `mcp.md` | MCP server setup & tools |
| `:help panels` | `panels.md` | Panel usage guide |

### Dynamic Plugin Help

`:help plugins` is generated at runtime by iterating the plugin registry. To avoid circular imports (`plugins` imports `editor`, so `editor` cannot import `plugins`), we define simple DTO types in the `editor` package:

```go
// In editor.go — simple types for plugin info (avoids circular import)
type PluginSummary struct {
    Name        string
    Version     string
    Description string
}

type CommandSummary struct {
    Name        string
    Description string
    PluginName  string
}
```

The `CommandExecutor` interface is extended with methods that return these DTOs:

```go
type CommandExecutor interface {
    ExecuteCommand(name string, ed PluginEditor, args string) bool
    Broadcast(eventType string, ed PluginEditor)
    ListPlugins() []PluginSummary
    ListCommands() []CommandSummary
}
```

`PluginManager` implements the new methods by converting its internal `Plugin`/`CommandDef` types to the editor DTOs. The editor's `executeCommand()` calls `e.CmdExec.ListPlugins()` and `e.CmdExec.ListCommands()`, generates a markdown string, and loads it into the buffer via `e.LoadContent()`.

### Integration Flow

1. User types `:help brain` in command mode
2. `executeCommand()` matches `strings.HasPrefix(cmd, "help")`
3. Extracts topic name (or defaults to "overview")
4. For static topics: calls `help.GetTopic(topic)`
5. For "plugins": builds content dynamically from plugin registry via `e.CmdExec.ListPlugins()` and `e.CmdExec.ListCommands()`
6. Checks `e.Buf.IsDirty()` — if unsaved changes exist, shows status warning "Unsaved changes! Save with :w first" and aborts
7. Loads content via `e.LoadContent("[help:brain]", content)` which sets buffer text directly without file I/O
8. User sees help content in editor, can toggle Preview (Alt+2) for rendered view

### Help Content Outline

**`overview.md`**
- "Welcome to LazyMD" heading
- One-line project description
- Table of help topics with descriptions
- Quick start tips

**`keys.md`**
- Normal mode: vim motions (h/j/k/l, w/b/e, 0/$, gg/G, d/c/y operators)
- Insert mode: typing, Esc to exit
- Command mode: `:` prefix
- Panel toggles: Alt+1 (files), Alt+2 (preview), Alt+3 (brain), Tab (cycle)
- Panel-specific keys (brain zoom/pan, preview scroll)
- Mouse: click to focus/place cursor, scroll wheels

**`brain.md`**
- What wiki-links are: `[[note-name]]` syntax
- How the knowledge graph is built (scanner, nodes, edges)
- Brain panel keybindings: j/k (select), f (local mode), +/- (zoom), h/l (pan)
- MCP brain tools: list_links, get_backlinks, get_graph, get_neighbors, find_path, get_orphans, get_hub_notes

**`plugins.md`** (dynamic)
- Generated list of all registered plugins
- Each entry: plugin name, version, description
- Each plugin's commands with descriptions

**`commands.md`**
- File: `:w`, `:q`, `:wq`, `:q!`, `:e <path>`, `:w <path>`
- Theme: `:theme`, `:theme.cycle`, `:theme.list`, `:theme <name>`
- Help: `:help`, `:help <topic>`
- Note: plugin commands listed under `:help plugins`

**`mcp.md`**
- Starting MCP server: `lm --mcp-server`, `lm --mcp-server file.md`
- Tool categories and full tool list (document, navigation, brain)
- Claude Code config: `claude mcp add LazyMD -- /path/to/lm --mcp-server`
- Gemini CLI config: JSON snippet for `~/.gemini/settings.json`

**`panels.md`**
- File Tree (Alt+1): browse files, j/k navigate, Enter to open, r to refresh
- Editor: vim modal editing, line numbers, cursor, syntax awareness
- Preview (Alt+2): glamour-rendered markdown, j/k/d/u scroll
- Brain (Alt+3): force-directed ASCII graph, wiki-link visualization, local mode

## Demo Mode

### CreateVault / CleanupVault

```go
// CreateVault extracts the embedded demo vault to a temp directory.
// Returns the path to the created vault directory.
func CreateVault() (string, error)

// CleanupVault removes a previously created demo vault.
func CleanupVault(path string)
```

Uses `//go:embed vault` (without glob — this recursively embeds all subdirectories) to bundle all demo files. `CreateVault()` writes them to `os.MkdirTemp("", "lm-demo-*")`, recreating the directory structure. The caller (main.go) is responsible for calling `CleanupVault()` via `defer`.

### CLI Integration

```go
// In main.go
demoMode := flag.Bool("demo", false, "Launch with demo vault")

// In default (TUI) case:
if *demoMode {
    vaultPath, err := demo.CreateVault()
    if err != nil { ... }
    defer demo.CleanupVault(vaultPath)
    os.Chdir(vaultPath)
    filePath = "welcome.md"
}
```

Note: the flag variable is named `demoMode` (not `demo`) to avoid shadowing the `demo` package import.

### Demo Vault Content

8 files, ~15+ wiki-link edges for a visually interesting Brain graph.

**`welcome.md`**
```markdown
# Welcome to LazyMD

Your terminal-native markdown editor. This demo vault showcases the core features.

## Quick Start

- Press `Alt+3` to open the **Brain** panel and see the knowledge graph
- Press `Alt+2` to toggle **Preview** for rendered markdown
- Press `Alt+1` to toggle the **File Tree**
- Type `:help` for the built-in help system

## Explore This Vault

- [[project-plan]] — A sample project roadmap with tasks
- [[golang]] — Knowledge base: Go programming
- [[markdown]] — Knowledge base: Markdown syntax
- [[wiki-links]] — Knowledge base: How wiki-links work
- [[zettelkasten]] — Knowledge base: The Zettelkasten method
- [[kanban]] — A kanban board with task columns

## Try These Commands

- `:kanban` — View kanban board summary
- `:help plugins` — See all available plugins
- `:theme.cycle` — Cycle through color themes
```

**`project-plan.md`**
```markdown
# LazyMD Roadmap

A sample project plan demonstrating headings, tasks, and navigation.

## Phase 1: Core Editor

- [x] Gap buffer implementation
- [x] Vim modal editing
- [x] Syntax-aware line rendering
- [ ] Multi-cursor support

## Phase 2: Knowledge Graph

- [x] [[wiki-links]] parser
- [x] Backlink indexing
- [ ] Graph clustering
- [ ] See [[zettelkasten]] for methodology

## Phase 3: Integrations

- [x] MCP server (22 tools)
- [ ] Plugin marketplace
- [ ] Web publishing
- [ ] See [[golang]] for implementation notes
```

**`knowledge/golang.md`**
```markdown
# Go Programming

Notes on Go as used in LazyMD.

## Why Go?

- Fast compilation, single binary output
- Excellent concurrency primitives
- Strong standard library

## Key Packages

- `bubbletea` — Terminal UI framework
- `lipgloss` — Style definitions
- `glamour` — Markdown rendering

## Code Example

```go
func main() {
    p := tea.NewProgram(model{})
    if _, err := p.Run(); err != nil {
        log.Fatal(err)
    }
}
```

## Related

- [[markdown]] — The file format we edit
- [[wiki-links]] — How notes connect
```

**`knowledge/markdown.md`**
```markdown
# Markdown Syntax

LazyMD is a markdown-native editor. Here's a quick syntax reference.

## Text Formatting

- **Bold** with `**text**`
- *Italic* with `*text*`
- ~~Strikethrough~~ with `~~text~~`
- `Code` with backticks

## Block Elements

> Blockquotes use `>` prefix

- Unordered lists with `-`
1. Ordered lists with numbers

## Task Lists

- [x] Completed task
- [ ] Pending task

## Links

- Standard: [text](url)
- Wiki-link: [[note-name]]

## Related

- [[wiki-links]] — Deep dive on wiki-link syntax
- [[golang]] — The language LazyMD is built with
```

**`knowledge/wiki-links.md`**
```markdown
# Wiki-Links

Wiki-links are the backbone of LazyMD's knowledge graph.

## Syntax

Use double brackets to link notes:

    [[note-name]]

LazyMD resolves links by filename (case-insensitive, ignores path prefixes).

## How It Works

1. The scanner finds all `[[...]]` patterns in your vault
2. Each unique note becomes a node in the graph
3. Each wiki-link becomes a directed edge
4. The Brain panel (Alt+3) visualizes the result

## Features

- **Backlinks**: See what links TO a note
- **Neighbors**: Find connected notes within N hops
- **Path finding**: Shortest path between any two notes
- **Orphan detection**: Notes with zero connections
- **Hub notes**: Most connected notes ranked by link count

## Related

- [[zettelkasten]] — The method behind linked notes
- [[markdown]] — Base syntax for everything
- [[welcome]] — Back to the start
```

**`knowledge/zettelkasten.md`**
```markdown
# Zettelkasten Method

A note-taking method based on atomic, interconnected notes.

## Principles

1. **One idea per note** — Keep notes focused and atomic
2. **Link liberally** — Connect related ideas with [[wiki-links]]
3. **Use your own words** — Restate ideas to deepen understanding
4. **Let structure emerge** — Don't force hierarchy, let links create it

## In LazyMD

LazyMD's Brain panel visualizes your Zettelkasten as a force-directed graph.
Try pressing `Alt+3` to see how this demo vault's notes connect.

The MCP tools let AI agents traverse your graph:
- `get_neighbors` — explore nearby notes
- `find_path` — discover connections between distant ideas
- `get_hub_notes` — find your most central ideas

## Related

- [[wiki-links]] — The linking mechanism
- [[golang]] — Implementation language
```

**`daily-notes/2026-03-15.md`**
```markdown
# Daily Note — 2026-03-15

## Tasks

- [x] Review the [[project-plan]] roadmap
- [ ] Explore the [[wiki-links]] knowledge base
- [ ] Try the `:kanban` command
- [ ] Toggle Brain panel with Alt+3

## Notes

Today I'm exploring LazyMD's demo vault. The knowledge graph
shows how notes connect through wiki-links.

## Ideas

- Could use [[zettelkasten]] method for research notes
- Check [[markdown]] reference for table syntax
```

**`kanban.md`**
```markdown
# Kanban Board

Try `:kanban` to see a summary of this board.

## Backlog

- [ ] Add table of contents plugin
- [ ] Implement split-pane editing
- [ ] Add [[markdown]] table support

## In Progress

- [ ] Knowledge graph clustering
- [ ] Review [[project-plan]] milestones

## Done

- [x] Core editor with vim bindings
- [x] Brain panel with [[wiki-links]]
- [x] MCP server with 22 tools
- [x] Plugin system with 50+ plugins
```

## Testing

- **Help system**: Unit test that all static topics load, dynamic plugins topic generates valid markdown, unknown topic returns false.
- **Demo mode**: Unit test that `CreateVault()` produces expected file structure, `CleanupVault()` removes it.
- **Integration**: Manual test — run `lm --demo`, verify Brain graph shows nodes, `:help` loads content, `:help plugins` lists all plugins.

## Summary of Changes

| File | Change |
|------|--------|
| `internal/help/help.go` | New — topic registry with `//go:embed` |
| `internal/help/content/*.md` | New — 6 static help markdown files |
| `internal/demo/demo.go` | New — vault creation/cleanup with `//go:embed` |
| `internal/demo/vault/**` | New — 8 demo vault markdown files |
| `cmd/lm/main.go` | Add `--demo` flag, wire up demo vault |
| `internal/editor/command.go` | Add `help` command routing (before `default` case), dirty-buffer guard |
| `internal/buffer/buffer.go` | Add `SetContent(text string)` method (reset gap buffer from string, no disk I/O) |
| `internal/editor/editor.go` | Add `PluginSummary`/`CommandSummary` DTOs, extend `CommandExecutor` with `ListPlugins()`/`ListCommands()`, add `LoadContent()` method |
| `internal/plugins/plugin.go` | Implement `ListPlugins()` and `ListCommands()` on `PluginManager` (returns editor DTOs) |
