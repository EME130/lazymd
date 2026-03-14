# LazyMD Go Migration Design Spec

## Overview

Full migration of LazyMD from Zig (~19,700 lines) to Go (~11,500 lines estimated), replacing the hand-rolled TUI with the Charm ecosystem (Bubble Tea v2, Lip Gloss, Bubbles, Glamour) and the hand-rolled MCP protocol with mcp-go.

**Binary name**: `lm` (unchanged)
**CLI interface**: Unchanged — `lm`, `lm --mcp-server`, `lm --web-server`, `lm --agent`
**File format**: `.rndm` / `.md` (unchanged)

## Decision Log

| Decision | Choice | Rationale |
|---|---|---|
| Migration scope | Full port (all 61 plugins, all 4 modes) | Complete feature parity |
| TUI framework | Bubble Tea v2 (`charm.land/bubbletea/v2`) | Latest, declarative View API, Cursed Renderer |
| MCP library | mcp-go (`github.com/mark3labs/mcp-go`) | Type-safe tools, stdio transport built-in |
| Text buffer | Gap buffer (ported from Zig) | Proven, efficient for editing patterns |
| Plugin structure | Single `plugins` package, one file per plugin | Matches current flat layout, simple imports |
| Package layout | `internal/` flat structure | Idiomatic Go, clear boundaries |
| App architecture | Monolithic root model (Approach 1) | Simple focus management, easy cross-panel sync |

## Dependencies

```
module github.com/EME130/lazymd

go 1.23

require (
    charm.land/bubbletea/v2              // Elm Architecture TUI framework
    github.com/charmbracelet/bubbles     // Pre-built components (list, viewport, textarea, help)
    github.com/charmbracelet/lipgloss    // Styling + layout composition
    github.com/charmbracelet/glamour     // Markdown rendering (replaces Preview.zig)
    github.com/charmbracelet/x/ansi      // ANSI escape sequence handling
    github.com/mark3labs/mcp-go          // MCP server (JSON-RPC 2.0 over stdio)
)
```

## Package Structure

```
cmd/
  lm/
    main.go                    # CLI arg parsing, mode dispatch (TUI/MCP/Web/Agent)

internal/
  buffer/
    buffer.go                  # Gap buffer: Insert, Delete, Undo, Redo, line tracking
    buffer_test.go

  editor/
    editor.go                  # EditorModel: vim modes, cursor, keybindings, scroll
    normal.go                  # Normal mode key handling
    insert.go                  # Insert mode key handling
    command.go                 # Command mode (: commands) handling
    motion.go                  # Cursor movement, word motions (w/b/e/$/^/0)
    editor_test.go

  ui/
    app.go                     # Root AppModel (tea.Model): Init/Update/View, focus routing
    layout.go                  # Panel layout computation (rects, visibility, toggle)
    filetree.go                # FileTreeModel (wraps bubbles/list)
    preview.go                 # PreviewModel (wraps glamour)
    brainview.go               # BrainViewModel (force-directed ASCII graph)
    statusbar.go               # Status bar rendering (mode, filename, position)
    commandbar.go              # Command bar rendering (: prompt, status messages)
    styles.go                  # Lip Gloss style definitions for all UI elements

  mcp/
    server.go                  # MCP server using mcp-go, tool registration
    tools_document.go          # open_file, read_document, write_document, etc.
    tools_navigation.go        # read_section, list_tasks, update_task, etc.
    tools_brain.go             # list_links, get_backlinks, get_graph, etc.
    server_test.go

  brain/
    graph.go                   # Knowledge graph: nodes, edges, backlinks, BFS
    scanner.go                 # Recursive vault scanner for [[wiki-links]]
    graph_test.go

  nav/
    navigator.go               # Navigator interface
    builtin.go                 # Built-in implementation: section nav, tasks, breadcrumbs
    builtin_test.go

  highlight/
    highlighter.go             # Highlighter interface
    builtin.go                 # Keyword-based tokenizer
    languages.go               # 16 language definitions
    highlight_test.go

  plugins/
    plugin.go                  # Plugin interface, PluginManager, EventType, CommandDef
    word_count.go              # :wc
    kanban.go                  # :kanban, :kanban.new, :kanban.add
    ... (59 more plugin files)
    plugins_test.go

  themes/
    themes.go                  # 12 themes as Lip Gloss style sets
    themes_test.go

  agent/
    agent.go                   # AgentPlugin interface
    mcp_backend.go             # MCP-based agent backend
    websocket_backend.go       # WebSocket-based agent backend

  web/
    server.go                  # HTTP + WebSocket web server
    websocket.go               # WebSocket protocol handling

  markdown/
    syntax.go                  # Markdown tokenizer (headings, bold, links, code, etc.)
    syntax_test.go
```

### Zig-to-Go Mapping

| Zig Source | Go Destination | Notes |
|---|---|---|
| `Buffer.zig` (375 lines) | `internal/buffer/buffer.go` (~300 lines) | GC removes allocator boilerplate |
| `Editor.zig` (776 lines) | `internal/editor/*.go` (~360 lines) | Split into 5 files by mode |
| `Terminal.zig` (274 lines) | **Eliminated** | Bubble Tea handles terminal I/O |
| `Renderer.zig` (157 lines) | **Eliminated** | Bubble Tea diff-renders from View() |
| `Surface.zig` (231 lines) | **Eliminated** | Lip Gloss strings replace cell grid |
| `Input.zig` (269 lines) | **Eliminated** | Bubble Tea provides KeyPressMsg/MouseClickMsg |
| `frontend/*.zig` (431 lines) | **Eliminated** | Bubble Tea is the frontend |
| `mcp/Server.zig` (1,333 lines) | `internal/mcp/*.go` (~400 lines) | mcp-go handles protocol |
| `ui/Preview.zig` (790 lines) | `internal/ui/preview.go` (~100 lines) | Glamour replaces hand-rolled rendering |
| `ui/Layout.zig` (212 lines) | `internal/ui/layout.go` (~200 lines) | JoinHorizontal/JoinVertical replaces rect math |
| `ui/BrainView.zig` (401 lines) | `internal/ui/brainview.go` (~200 lines) | Same force-directed layout |
| `nav/*.zig` (603 lines) | `internal/nav/*.go` (~450 lines) | Go strings simplify parsing |
| `brain/*.zig` (480 lines) | `internal/brain/*.go` (~350 lines) | Go maps, filepath.WalkDir |
| `plugin.zig` + 61 plugins (~9,500 lines) | `internal/plugins/*.go` (~7,000 lines) | Interface less verbose than vtable |
| `highlight/*.zig` (1,115 lines) | `internal/highlight/*.go` (~800 lines) | Same tokenizer logic |
| `themes.zig` (498 lines) | `internal/themes/themes.go` (~300 lines) | Lip Gloss color literals |
| `markdown/syntax.zig` (471 lines) | `internal/markdown/syntax.go` (~350 lines) | Same tokenizer |
| `web/*.zig` (504 lines) | `internal/web/*.go` (~300 lines) | Go net/http is concise |
| `agent/*.zig` (958 lines) | `internal/agent/*.go` (~300 lines) | Go interfaces |
| `main.zig` (430 lines) | `cmd/lm/main.go` (~80 lines) | cobra/flag parsing |
| **Total: ~19,700 lines** | **~11,500 lines** | **~42% reduction** |

## Architecture

### Bubble Tea Data Flow

```
┌───────────────────────────────────────────────────────────┐
│                      tea.Program                           │
│                                                            │
│  Terminal Events ──▶ AppModel.Update() ──▶ tea.View{}      │
│  (KeyPress, Mouse,   Routes to focused     Composed via    │
│   WindowSize)        panel sub-model       LipGloss Join   │
│                                                            │
│  Sub-models (NOT tea.Model — plain structs with methods):  │
│  ├── EditorModel    (vim modes, cursor, buffer)            │
│  ├── FileTreeModel  (wraps bubbles/list)                   │
│  ├── PreviewModel   (wraps glamour)                        │
│  ├── BrainViewModel (force-directed ASCII graph)           │
│  ├── StatusBar      (mode indicator, filename, position)   │
│  └── CommandBar     (: prompt, status messages)            │
└───────────────────────────────────────────────────────────┘
```

### Root AppModel

```go
type AppModel struct {
    editor    *editor.EditorModel
    fileTree  FileTreeModel
    preview   PreviewModel
    brain     BrainViewModel
    layout    LayoutState
    width     int
    height    int
    pluginMgr *plugins.PluginManager
    quitting  bool
}
```

Single `tea.Model`. Owns all state. Sub-models are plain structs — not independent `tea.Model` implementations. The root:

1. Handles global keys (Tab to cycle panels, Alt+1/2/3 to toggle)
2. Routes input to the focused panel's `HandleKey()` method
3. Checks for cross-panel sync (editor change → preview invalidate)
4. Composes all panel views via Lip Gloss in `View()`

### Update Routing

```go
func (m AppModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width, m.height = msg.Width, msg.Height
        m.layout.Compute(m.width, m.height)
    case tea.KeyPressMsg:
        if cmd := m.handleGlobalKey(msg); cmd != nil {
            return m, cmd
        }
        switch m.layout.ActivePanel {
        case PanelEditor:
            cmd := m.editor.HandleKey(msg)
            if m.editor.BufferChanged() {
                m.preview.Invalidate()
            }
            return m, cmd
        case PanelFileTree:
            return m, m.fileTree.HandleKey(msg)
        case PanelPreview:
            return m, m.preview.HandleKey(msg)
        case PanelBrain:
            return m, m.brain.HandleKey(msg)
        }
    case tea.MouseClickMsg:
        m.layout.ActivePanel = m.layout.HitTest(msg.X, msg.Y)
    }
    return m, nil
}
```

### View Composition

```go
func (m AppModel) View() tea.View {
    panels := []string{}
    if m.layout.ShowFileTree {
        panels = append(panels, m.fileTree.View(m.layout.TreeRect))
    }
    panels = append(panels, m.editor.View(m.layout.EditorRect))
    if m.layout.ShowBrain {
        panels = append(panels, m.brain.View(m.layout.BrainRect))
    } else if m.layout.ShowPreview {
        panels = append(panels, m.preview.View(m.layout.PreviewRect))
    }
    body := lipgloss.JoinHorizontal(lipgloss.Top, panels...)
    screen := lipgloss.JoinVertical(lipgloss.Left,
        m.renderTitleBar(), body, m.renderStatusBar(), m.renderCommandBar())
    return tea.NewView(screen).AltScreen(true).MouseCellMotion(true)
}
```

## Component Details

### Buffer (`internal/buffer/`)

Gap buffer with undo/redo. Direct port from Zig.

```go
type Buffer struct {
    data       []byte
    gapStart   int
    gapEnd     int
    lineStarts []int
    dirty      bool
    undoStack  []undoOp
    redoStack  []undoOp
}

// Constants
const initialGap = 1024
const minGap = 256
```

Public API:
- `New() *Buffer`
- `LoadFile(path string) error` / `SaveFile(path string) error`
- `Length() int` / `LineCount() int` / `Line(row int) string` / `LineLen(row int) int`
- `ByteAt(pos int) byte` / `Content() string`
- `InsertString(pos int, text string) error` / `InsertByte(pos int, ch byte) error`
- `DeleteRange(pos, length int) error` / `DeleteByte(pos int) error`
- `Undo() error` / `Redo() error`
- `PosToOffset(row, col int) int` / `OffsetToPos(offset int) Position`
- `IsDirty() bool`

Key Go differences: `Line()` returns a `string` copy (safe from gap moves), GC handles undo stack cleanup, no allocator parameter.

### Editor (`internal/editor/`)

Split across 5 files:

**`editor.go`** — Struct definition, `HandleKey()` dispatcher, `View()` renderer, file operations (save, open), `BufferChanged()` for cross-panel sync.

**`normal.go`** — Normal mode: Ctrl shortcuts (Ctrl+S/U/D/R), count prefix (e.g. `5j`), pending operators (`dd`), movement (hjkl, w/b/e, 0/$, ^, g/G), mode switches (i/I/a/A/o/O, :), editing (x, u, p), arrow keys, page up/down.

**`insert.go`** — Insert mode: Escape → normal, Ctrl+S save, character input, Enter/Backspace/Delete/Tab, arrow keys.

**`command.go`** — Command mode: Escape → normal, Enter → execute, Backspace, character append. Commands: `:q`, `:q!`, `:w`, `:wq`, `:x`, `:w <path>`, `:e <path>`, `:theme*`. Falls through to plugin manager.

**`motion.go`** — Cursor movement functions: `MoveCursorUp/Down/Left/Right`, `WordForward/Backward/End`, `CursorToLineEnd/FirstNonBlank`, `UpdateScroll`, `ClampCursor`, `DeleteLine`.

View renders via Lip Gloss — line numbers, syntax-highlighted content, cursor highlight (reverse video). Returns styled string, no Surface calls.

### MCP Server (`internal/mcp/`)

Uses mcp-go. `LazyMDServer` struct holds buffer, navigator, graph, file path.

**`server.go`** — `New(buf)`, creates `server.MCPServer`, calls `registerDocumentTools()`, `registerNavigationTools()`, `registerBrainTools()`. `Run()` calls `server.ServeStdio()`.

**`tools_document.go`** (~150 lines) — 9 tools: `open_file`, `read_document`, `write_document`, `list_headings`, `edit_section`, `insert_text`, `delete_lines`, `search_content`, `get_structure`. Each is an `s.mcpServer.AddTool()` call + handler function.

**`tools_navigation.go`** (~120 lines) — 6 tools: `read_section`, `list_tasks`, `update_task`, `get_breadcrumb`, `move_section`, `read_section_range`. Delegates to `nav.Navigator` interface.

**`tools_brain.go`** (~130 lines) — 7 tools: `list_links`, `get_backlinks`, `get_graph`, `get_neighbors`, `find_path`, `get_orphans`, `get_hub_notes`. Lazy vault scan on first call.

### Brain (`internal/brain/`)

**`graph.go`** — `Node` (ID, Name, Path, OutLinks, InLinks), `Edge` (From, To), `Graph` struct with `nameToID` map. Methods: `AddNode`, `AddEdge`, `Resolve` (wiki-link → node ID, case-insensitive, handles `|` aliases and `/` paths), `BuildLinks`, `GetBacklinks`, `GetOrphans`, `GetNeighbors` (BFS).

**`scanner.go`** — `Scan(dir string) (*Graph, error)`. Walks with `filepath.WalkDir`, filters `.md`/`.rndm`, parses `[[wiki-links]]` with regex, builds graph.

### Navigation (`internal/nav/`)

```go
type Navigator interface {
    ReadSection(headingPath string) (*SectionContent, error)
    ListTasks(section *string, status TaskStatus) ([]TaskItem, error)
    UpdateTask(line int, done bool) (string, error)
    GetBreadcrumb(line int) (string, error)
    MoveSection(heading, target string, before bool) (string, error)
    ReadSectionRange(headingPath string, startOff, endOff *int) (string, error)
}
```

`BuiltinNavigator` implements this with the same heading-path resolution (`/`-separated, case-insensitive), section-bounds detection, task checkbox parsing, and breadcrumb building as the Zig version.

### Plugin System (`internal/plugins/`)

```go
type Plugin interface {
    Info() PluginInfo
    Init(editor PluginEditor)
    OnEvent(event *PluginEvent)
    Commands() []CommandDef
}

type PluginEditor interface {
    GetBuffer() BufferReader
    SetStatus(msg string, isError bool)
    CursorRow() int
    CursorCol() int
    FilePath() string
}
```

`PluginManager` holds `[]Plugin` and `map[string]commandEntry`. Methods: `Register`, `Broadcast`, `ExecuteCommand`. 61 plugins, one file each.

### Themes (`internal/themes/`)

12 themes as `ThemeColors` structs with `lipgloss.Color` values: default, dracula, gruvbox, nord, solarized, monokai, catppuccin, tokyo-night, one-dark, rose-pine, kanagawa, everforest.

Global `currentIndex` with `Current()`, `Cycle()`, `SetByName(name) bool`, `FindByName(name) (int, bool)`.

### Highlight (`internal/highlight/`)

```go
type Highlighter interface {
    Tokenize(line string, ctx *LineContext) []Span
}
```

`BuiltinHighlighter` with keyword-based tokenizer. `languages.go` defines 16 languages. Spans carry token types that map to Lip Gloss styles.

### Web & Agent

**`internal/web/`** — Go `net/http` server + WebSocket. Same HTTP + WS architecture as Zig version.
**`internal/agent/`** — `AgentBackend` interface with MCP and WebSocket implementations. `AgentPlugin` integrates with plugin system.

## Testing Strategy

Port all existing tests. Run with `go test ./...`.

| Package | Tests Ported | Source |
|---|---|---|
| `buffer` | 4 (insert/read, delete, undo, position) | `Buffer.zig` |
| `editor` | 2 (init+insert, cursor movement) | `Editor.zig` |
| `nav` | 7 (heading path, section read, tasks, breadcrumb, range) | `BuiltinNavigator.zig` |
| `brain` | 5 (nodes+edges, resolve, duplicates, orphans, BFS) | `Graph.zig` |
| `mcp` | Tool handler unit tests (direct function calls) | `Server.zig` |
| `plugins` | Plugin info + command tests per plugin | Various |
| `ui` | 2 (layout computation, toggle) | `Layout.zig` |
| `markdown` | Syntax tokenizer tests | `syntax.zig` |
| `highlight` | Highlighter tests | Various |
| `themes` | Theme tests | `themes.zig` |

## Migration Order

### Phase 1: Foundation
- `go.mod`, `cmd/lm/main.go` (skeleton with flag parsing)
- `internal/buffer/` — gap buffer + tests
- `internal/markdown/syntax` — tokenizer + tests
- **Deliverable**: `go test ./internal/buffer/ ./internal/markdown/` passes

### Phase 2: Navigation & Brain
- `internal/nav/` — Navigator interface + BuiltinNavigator + tests
- `internal/brain/` — Graph + Scanner + tests
- `internal/highlight/` — Highlighter + BuiltinHighlighter + tests
- **Deliverable**: `go test ./internal/...` passes

### Phase 3: MCP Server
- `internal/mcp/` — mcp-go server + all 22 tool handlers + tests
- Wire into `cmd/lm/main.go` for `--mcp-server` flag
- **Deliverable**: `lm --mcp-server` works, all 22 tools functional via Claude Code / Gemini CLI

### Phase 4: Plugin System
- `internal/plugins/plugin.go` — interface + manager
- `internal/plugins/*.go` — all 61 plugins + tests
- **Deliverable**: Plugin system compiles and passes tests

### Phase 5: TUI Core
- `internal/themes/` — 12 themes as Lip Gloss styles
- `internal/editor/` — all 5 files (editor, normal, insert, command, motion)
- `internal/ui/app.go` — root AppModel
- `internal/ui/layout.go` — panel layout
- `internal/ui/statusbar.go`, `commandbar.go`, `styles.go`
- Add Bubble Tea + Lip Gloss dependencies
- **Deliverable**: `lm` launches TUI, basic editing works

### Phase 6: TUI Panels
- `internal/ui/filetree.go` — bubbles/list integration
- `internal/ui/preview.go` — Glamour markdown rendering
- `internal/ui/brainview.go` — force-directed ASCII graph
- Add Glamour + Bubbles dependencies
- **Deliverable**: Full TUI with all 4 panels

### Phase 7: Web & Agent
- `internal/web/` — HTTP + WebSocket server
- `internal/agent/` — Agent backends
- Wire `--web-server` and `--agent` flags
- **Deliverable**: All 4 modes working

### Phase 8: Cleanup
- Update `CLAUDE.md` — Go build commands, new project structure
- Update `README.md` — installation, usage
- Delete `src/` directory (all Zig source)
- Delete `build.zig`, `build.zig.zon`
- Update `.claude/hooks/` — replace `zig fmt` hook with `gofmt`
- **Deliverable**: Clean Go-only repository

## Line Count Summary

| Component | Zig Lines | Go Lines (est.) | Reduction |
|---|---|---|---|
| Buffer | 375 | ~300 | 20% |
| Editor | 776 | ~360 | 54% |
| Terminal + Renderer + Surface + Input + Frontend | 1,012 | 0 | 100% (Bubble Tea) |
| MCP Server | 1,333 | ~400 | 70% (mcp-go) |
| Preview | 790 | ~100 | 87% (Glamour) |
| Layout + BrainView | 613 | ~400 | 35% |
| Navigation | 603 | ~450 | 25% |
| Brain | 480 | ~350 | 27% |
| Plugins (system + 61) | ~9,500 | ~7,000 | 26% |
| Highlight + languages | 1,115 | ~800 | 28% |
| Themes | 498 | ~300 | 40% |
| Syntax | 471 | ~350 | 26% |
| Web + Agent | 1,098 | ~600 | 45% |
| main.go | 430 | ~80 | 81% |
| **Total** | **~19,700** | **~11,500** | **~42%** |

Major reductions come from: eliminating terminal/renderer/surface/input (Bubble Tea), MCP protocol handling (mcp-go), and markdown preview rendering (Glamour).
