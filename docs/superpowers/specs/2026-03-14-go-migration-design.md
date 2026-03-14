# LazyMD Go Migration Design Spec

## Overview

Full migration of LazyMD from Zig (~19,700 lines) to Go (~11,500 lines estimated), replacing the hand-rolled TUI with the Charm ecosystem (Bubble Tea v2, Lip Gloss, Bubbles, Glamour) and the hand-rolled MCP protocol with mcp-go.

**Binary name**: `lm` (unchanged)
**CLI interface**: Unchanged — `lm`, `lm --mcp-server` (alias: `--mcp`), `lm --web-server [--port N]`, `lm --agent`
**File format**: `.rndm` / `.md` (unchanged)

## Decision Log

| Decision | Choice | Rationale |
|---|---|---|
| Migration scope | Full port (all 66 plugins, all 4 modes) | Complete feature parity |
| TUI framework | Bubble Tea v2 (`charm.land/bubbletea/v2`) | Latest, declarative View API, Cursed Renderer |
| MCP library | mcp-go (`github.com/mark3labs/mcp-go`) | Type-safe tools, stdio transport built-in |
| Text buffer | Gap buffer (ported from Zig) | Proven, efficient for editing patterns |
| Plugin structure | Single `plugins` package, one file per plugin | Matches current flat layout, simple imports |
| Package layout | `internal/` flat structure | Idiomatic Go, clear boundaries |
| App architecture | Monolithic root model | Simple focus management, easy cross-panel sync |

## Dependencies

```
module github.com/EME130/lazymd

go 1.23

require (
    charm.land/bubbletea/v2              // Elm Architecture TUI framework (v2.0.2+)
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
    layout.go                  # Panel layout computation (widths, heights, visibility)
    filetree.go                # FileTreeModel (wraps bubbles/list) + directory scanning
    preview.go                 # PreviewModel (wraps glamour)
    brainview.go               # BrainViewModel (force-directed ASCII graph)
    statusbar.go               # Status bar rendering (mode, filename, position)
    commandbar.go              # Command bar rendering (: prompt, status messages)
    styles.go                  # Lip Gloss style definitions for all UI elements

  mcp/
    server.go                  # MCP server using mcp-go, tool registration
    tools_document.go          # open_file, read_document, write_document, etc.
    tools_navigation.go        # read_section, list_tasks, update_task, etc.
    tools_brain.go             # list_links, get_backlinks, get_graph, find_path, etc.
    server_test.go

  brain/
    graph.go                   # Knowledge graph: nodes, edges, backlinks, BFS, FindPath
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
    ... (64 more plugin files, 66 total)
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
| `Input.zig` (269 lines) | **Eliminated** | Bubble Tea provides KeyPressMsg/MouseClickMsg |
| `frontend/*.zig` (581 lines) | **Eliminated** | Bubble Tea is the frontend (Surface, events, TuiFrontend, Frontend) |
| `mcp/Server.zig` (1,333 lines) | `internal/mcp/*.go` (~400 lines) | mcp-go handles protocol |
| `ui/Preview.zig` (790 lines) | `internal/ui/preview.go` (~100 lines) | Glamour replaces hand-rolled rendering |
| `ui/Layout.zig` (212 lines) | `internal/ui/layout.go` (~200 lines) | Computes widths/heights; panels enforce via lipgloss |
| `ui/BrainView.zig` (401 lines) | `internal/ui/brainview.go` (~200 lines) | Same force-directed layout |
| `nav/*.zig` (603 lines) | `internal/nav/*.go` (~450 lines) | Go strings simplify parsing |
| `brain/*.zig` (480 lines) | `internal/brain/*.go` (~380 lines) | Go maps, filepath.WalkDir, includes FindPath |
| `plugin.zig` + 66 plugins (~9,500 lines) | `internal/plugins/*.go` (~7,000 lines) | Interface less verbose than vtable |
| `highlight/*.zig` (1,115 lines) | `internal/highlight/*.go` (~800 lines) | Same tokenizer logic |
| `themes.zig` (498 lines) | `internal/themes/themes.go` (~300 lines) | Lip Gloss color literals |
| `markdown/syntax.zig` (471 lines) | `internal/markdown/syntax.go` (~350 lines) | Same tokenizer |
| `web/*.zig` (504 lines) | `internal/web/*.go` (~300 lines) | Go net/http is concise |
| `agent/*.zig` (958 lines) | `internal/agent/*.go` (~300 lines) | Go interfaces |
| `main.zig` (430 lines) | `cmd/lm/main.go` (~80 lines) | flag parsing + dispatch |
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

Bubble Tea v2 `View()` returns `tea.View` (not `string`), allowing declarative metadata (alt-screen, mouse mode, window title) to be set per frame.

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

**Note on v2 API stability**: If `tea.View` is not yet available in the shipped v2 release, fall back to `View() string` with `tea.WithAltScreen()` and `tea.WithMouseCellMotion()` set as program options at startup.

### Layout Model

`layout.go` still computes widths and heights (same algorithm as `Layout.zig`). Each panel's `View()` receives a `Rect` with its allocated `W` and `H`, and uses `lipgloss.NewStyle().Width(rect.W).Height(rect.H).Render(...)` to enforce exact dimensions before joining. Lip Gloss replaces the manual cell-grid positioning, but rect math stays.

```go
type Rect struct {
    W, H int  // no X/Y needed — position is implicit in JoinHorizontal/Vertical order
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

**Performance note on `Line()`**: Returns a `string` (copy). The Zig version returns a zero-copy slice into the gap buffer. In Go, this means one allocation per `Line()` call. For rendering (~50 visible lines at 60fps = 3,000 allocs/sec), this is acceptable — Go's small-string optimization and GC handle it well. If profiling shows GC pressure, add a `LineBytes(row int) []byte` method that returns a slice valid until the next mutation, with a "borrow" contract documented.

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

**`server.go`** — `New(buf)`, creates `server.MCPServer`, calls `registerDocumentTools()`, `registerNavigationTools()`, `registerBrainTools()`. `Run()` calls `server.ServeStdio()`. Protocol version negotiation is handled by mcp-go.

**`tools_document.go`** (~150 lines) — 9 tools: `open_file`, `read_document`, `write_document`, `list_headings`, `edit_section`, `insert_text`, `delete_lines`, `search_content`, `get_structure`. Each is an `s.mcpServer.AddTool()` call + handler function.

**`tools_navigation.go`** (~120 lines) — 6 tools: `read_section`, `list_tasks`, `update_task`, `get_breadcrumb`, `move_section`, `read_section_range`. Delegates to `nav.Navigator` interface.

**`tools_brain.go`** (~130 lines) — 7 tools: `list_links`, `get_backlinks`, `get_graph`, `get_neighbors`, `find_path`, `get_orphans`, `get_hub_notes`. `find_path` calls `graph.FindPath()` (BFS with parent-tracking for path reconstruction). Lazy vault scan on first brain tool call.

**Concurrency**: The mcp-go `server.ServeStdio()` processes requests sequentially on a single goroutine, matching the Zig server's synchronous behavior. The shared `Buffer` does not need mutex protection — tool handlers run one at a time. If mcp-go adds concurrent dispatch in the future, wrap `Buffer` access in a `sync.Mutex`.

### Brain (`internal/brain/`)

**`graph.go`** — `Node` (ID, Name, Path, OutLinks, InLinks), `Edge` (From, To), `Graph` struct with `nameToID` map. Methods:
- `AddNode`, `AddEdge`, `Resolve` (wiki-link → node ID, case-insensitive, handles `|` aliases and `/` paths)
- `BuildLinks` — populate in/out link arrays from edges
- `GetBacklinks`, `GetOrphans`, `GetNeighbors` (BFS with depth limit)
- `FindPath(from, to uint16) ([]uint16, bool)` — BFS shortest path with parent-tracking and path reconstruction (~40 lines). Currently inline in `Server.zig` (lines 914-960), moved to `Graph` as a proper method in Go.

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

`BuiltinNavigator` implements this with the same heading-path resolution (`/`-separated, case-insensitive), section-bounds detection, task checkbox parsing, and breadcrumb building as the Zig version. `ReadSectionRange` returns numbered lines (e.g., `L5: content`), same format as Zig.

### Plugin System (`internal/plugins/`)

```go
type Plugin interface {
    Info() PluginInfo
    Init(editor PluginEditor)
    OnEvent(event *PluginEvent)
    Commands() []CommandDef
    // Optional panel rendering — return empty string if not used
    RenderPanel(ctx *RenderContext) string
}
```

```go
type PluginEditor interface {
    // Read access
    Buffer() *buffer.Buffer    // full buffer access (read + write)
    CursorRow() int
    CursorCol() int
    FilePath() string
    Mode() editor.Mode

    // Write access
    SetStatus(msg string, isError bool)
    SetCursorRow(row int)
    SetCursorCol(col int)
}

type RenderContext struct {
    Width  int
    Height int
}
```

`PluginManager` holds `[]Plugin` and `map[string]commandEntry`. Methods: `Register`, `Broadcast`, `ExecuteCommand`. 66 plugins, one file each.

**Note**: Plugins get direct `*buffer.Buffer` access for mutations (inserting templates, transforming text). This matches the Zig design where plugins receive `*Editor` with full buffer access.

### Themes (`internal/themes/`)

12 themes as `ThemeColors` structs with `lipgloss.Color` values: default, dracula, gruvbox, nord, solarized, monokai, catppuccin, tokyo-night, one-dark, rose-pine, kanagawa, everforest.

Global `currentIndex` with `Current()`, `Cycle()`, `SetByName(name) bool`, `FindByName(name) (int, bool)`.

Theme state is process-global (same as Zig). No config file — theme resets to default on launch. Config file support may be added later but is out of scope for this migration.

### Highlight (`internal/highlight/`)

```go
type HighlightState struct {
    InBlockComment    bool
    InMultilineString bool
}

type Highlighter interface {
    Tokenize(line string, langName string, state *HighlightState) []Span
    SupportsLanguage(langName string) bool
}
```

`BuiltinHighlighter` with keyword-based tokenizer. `languages.go` defines 16 languages. Spans carry `TokenKind` (keyword, type_name, builtin, string, number, comment, operator, punctuation, annotation, normal) that map to Lip Gloss styles via the active theme.

### Web & Agent

**`internal/web/`** — Go `net/http` server + WebSocket. Same HTTP + WS architecture as Zig version.
**`internal/agent/`** — `AgentBackend` interface with MCP and WebSocket implementations. `AgentPlugin` integrates with plugin system.

### File Tree Scanning

Directory scanning logic (walk current directory, filter hidden files, detect `.md`/`.rndm`, sort dirs-first then alphabetical) lives in `internal/ui/filetree.go` alongside the `FileTreeModel`. In Zig this was a standalone function in `main.zig`.

## Error Handling Strategy

- **MCP tool handlers**: Return `(*mcp.CallToolResult, error)`. Use `mcp.NewToolResultError(msg)` for user-visible errors (file not found, invalid arguments). Return Go `error` only for unexpected failures (I/O errors). mcp-go translates these into proper JSON-RPC error responses.
- **TUI errors**: File open/save failures set `editor.Status` with `isError=true`. The editor never panics on user actions — all buffer operations return `error` which is handled gracefully (e.g., status message "Failed to save").
- **Startup errors**: `main.go` returns errors to the OS. `tea.Program.Run()` returns an error on failure.
- **Panics**: Do NOT use `tea.WithoutCatchPanics()` — let Bubble Tea recover and restore the terminal on panic. Log the panic to stderr after cleanup.

## Testing Strategy

Port all existing tests. Run with `go test ./...`.

| Package | Tests Ported | Source |
|---|---|---|
| `buffer` | 4 (insert/read, delete, undo, position) | `Buffer.zig` |
| `editor` | 2 (init+insert, cursor movement) | `Editor.zig` |
| `nav` | 7 (heading path, section read, tasks, breadcrumb, range) | `BuiltinNavigator.zig` |
| `brain` | 5 + FindPath (nodes+edges, resolve, duplicates, orphans, BFS, path) | `Graph.zig` + `Server.zig` |
| `mcp` | Tool handler unit tests (direct function calls) | `Server.zig` |
| `plugins` | Plugin info + command tests per plugin | Various |
| `ui` | 2 (layout computation, toggle) | `Layout.zig` |
| `markdown` | Syntax tokenizer tests | `syntax.zig` |
| `highlight` | Highlighter tests | Various |
| `themes` | Theme tests | `themes.zig` |

## Migration Order

### Phase 1: Foundation
- `go.mod`, `cmd/lm/main.go` (skeleton with flag parsing for `--mcp-server`/`--mcp`, `--web-server`, `--port`, `--agent`)
- `internal/buffer/` — gap buffer + tests
- `internal/markdown/syntax` — tokenizer + tests
- **Deliverable**: `go test ./internal/buffer/ ./internal/markdown/` passes

### Phase 2: Navigation & Brain
- `internal/nav/` — Navigator interface + BuiltinNavigator + tests
- `internal/brain/` — Graph (including `FindPath`) + Scanner + tests
- `internal/highlight/` — Highlighter + BuiltinHighlighter + tests
- **Deliverable**: `go test ./internal/...` passes
- **Note**: `FindPath` BFS (currently in `Server.zig`) is ported to `graph.go` here, not deferred to Phase 3.

### Phase 3: MCP Server
- `internal/mcp/` — mcp-go server + all 22 tool handlers + tests
- Wire into `cmd/lm/main.go` for `--mcp-server` / `--mcp` flag
- **Deliverable**: `lm --mcp-server` works, all 22 tools functional via Claude Code / Gemini CLI

### Phase 4: Plugin System + Editor Core
- `internal/plugins/plugin.go` — interface + manager
- `internal/plugins/*.go` — all 66 plugins
- `internal/editor/` — all 5 files (editor, normal, insert, command, motion)
- `internal/themes/` — 12 themes as Lip Gloss styles
- **Deliverable**: Plugin system + editor compile and pass tests

Phases 4 and 5 were merged because: (a) plugins require `PluginEditor` interface which needs the editor to exist, (b) the editor needs `PluginManager` for command dispatch and event broadcasting, (c) testing plugins meaningfully requires at least the editor struct. Tests use real `EditorModel` instances (not mocks) since the editor is being built in the same phase.

### Phase 5: TUI Shell
- `internal/ui/app.go` — root AppModel
- `internal/ui/layout.go` — panel layout
- `internal/ui/statusbar.go`, `commandbar.go`, `styles.go`
- Add Bubble Tea + Lip Gloss dependencies
- **Deliverable**: `lm` launches TUI, basic editing works with editor + status bar + command bar

### Phase 6: TUI Panels
- `internal/ui/filetree.go` — bubbles/list integration + directory scanning
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
- Update `CLAUDE.md` — Go build commands (`go build`, `go run`, `go test`), new project structure, update hooks
- Update `README.md` — installation, usage
- Delete `src/` directory (all Zig source)
- Delete `build.zig`, `build.zig.zon`
- Update `.claude/hooks/` — replace `zig fmt` hook with `gofmt`
- Update the `website` with go instead of zig
- **Deliverable**: Clean Go-only repository

## Line Count Summary

| Component | Zig Lines | Go Lines (est.) | Reduction |
|---|---|---|---|
| Buffer | 375 | ~300 | 20% |
| Editor | 776 | ~360 | 54% |
| Terminal + Renderer + Input + Frontend | 1,281 | 0 | 100% (Bubble Tea) |
| MCP Server | 1,333 | ~400 | 70% (mcp-go) |
| Preview | 790 | ~100 | 87% (Glamour) |
| Layout + BrainView | 613 | ~400 | 35% |
| Navigation | 603 | ~450 | 25% |
| Brain | 480 | ~380 | 21% |
| Plugins (system + 66) | ~9,500 | ~7,000 | 26% |
| Highlight + languages | 1,115 | ~800 | 28% |
| Themes | 498 | ~300 | 40% |
| Syntax | 471 | ~350 | 26% |
| Web + Agent | 1,462 | ~600 | 59% |
| main.go | 430 | ~80 | 81% |
| **Total** | **~19,700** | **~11,500** | **~42%** |

Major reductions come from: eliminating terminal/renderer/input/frontend (Bubble Tea), MCP protocol handling (mcp-go), and markdown preview rendering (Glamour).
