package ui

import (
	"fmt"
	"os"
	"strings"

	tea "charm.land/bubbletea/v2"
	"github.com/EME130/lazymd/internal/buffer"
	"github.com/EME130/lazymd/internal/editor"
	"github.com/EME130/lazymd/internal/plugins"
	"github.com/EME130/lazymd/internal/themes"
	"github.com/charmbracelet/lipgloss"
)

// AppModel is the root Bubble Tea model.
type AppModel struct {
	editor    *editor.EditorModel
	fileTree  FileTreeModel
	preview   PreviewModel
	brain     BrainViewModel
	layout    LayoutState
	styles    Styles
	width     int
	height    int
	pluginMgr *plugins.PluginManager
	quitting  bool
	initFile  string
}

// NewApp creates a new AppModel for the TUI.
func NewApp(filePath string) AppModel {
	buf := buffer.New()
	ed := editor.New(buf)
	pm := plugins.NewManager()
	plugins.RegisterAll(pm, ed)
	ed.CmdExec = pm

	cwd, _ := os.Getwd()

	m := AppModel{
		editor:    ed,
		fileTree:  NewFileTree(cwd),
		preview:   NewPreview(),
		brain:     NewBrainView(),
		layout:    NewLayout(),
		styles:    NewStyles(),
		pluginMgr: pm,
		initFile:  filePath,
	}
	return m
}

// Init implements tea.Model.
func (m AppModel) Init() tea.Cmd {
	if m.initFile != "" {
		return func() tea.Msg {
			return fileLoadMsg{path: m.initFile}
		}
	}
	return nil
}

type fileLoadMsg struct {
	path string
}

// Update implements tea.Model.
func (m AppModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.layout.Compute(m.width, m.height)
		m.editor.ViewWidth = m.layout.EditorRect.W
		m.editor.ViewHeight = m.layout.EditorRect.H
		return m, nil

	case fileLoadMsg:
		if err := m.editor.OpenFile(msg.path); err != nil {
			m.editor.SetStatus(fmt.Sprintf("Failed to open: %v", err), true)
		}
		return m, nil

	case tea.KeyPressMsg:
		if m.quitting {
			return m, nil
		}

		// Global keys (only in normal mode on editor panel)
		if m.layout.ActivePanel == PanelEditor && m.editor.Mode() == editor.ModeNormal {
			switch msg.String() {
			case "alt+1":
				m.layout.TogglePanel(PanelFileTree)
				m.layout.Compute(m.width, m.height)
				m.editor.ViewWidth = m.layout.EditorRect.W
				m.editor.ViewHeight = m.layout.EditorRect.H
				return m, nil
			case "alt+2":
				m.layout.TogglePanel(PanelPreview)
				m.layout.Compute(m.width, m.height)
				m.editor.ViewWidth = m.layout.EditorRect.W
				m.editor.ViewHeight = m.layout.EditorRect.H
				return m, nil
			case "alt+3":
				m.layout.TogglePanel(PanelBrain)
				m.layout.Compute(m.width, m.height)
				m.editor.ViewWidth = m.layout.EditorRect.W
				m.editor.ViewHeight = m.layout.EditorRect.H
				return m, nil
			}
		}

		// Global Tab for all panels when not in insert/command mode
		if m.layout.ActivePanel != PanelEditor || m.editor.Mode() == editor.ModeNormal {
			if msg.String() == "tab" {
				m.layout.CyclePanel()
				return m, nil
			}
		}

		// Route input to focused panel
		switch m.layout.ActivePanel {
		case PanelEditor:
			key := teaKeyToEditorKey(msg)
			m.editor.HandleKey(key)

			if m.editor.ShouldQuit {
				m.quitting = true
				return m, tea.Quit
			}

			// Invalidate preview on buffer change
			if m.editor.BufferChanged() {
				m.preview.Invalidate()
			}

			// Refresh styles if theme changed
			m.styles = NewStyles()

		case PanelFileTree:
			switch msg.String() {
			case "j", "down":
				m.fileTree.MoveDown()
			case "k", "up":
				m.fileTree.MoveUp()
			case "enter":
				path := m.fileTree.SelectedPath()
				if path != "" {
					if err := m.editor.OpenFile(path); err != nil {
						m.editor.SetStatus(fmt.Sprintf("Failed to open: %v", err), true)
					} else {
						m.preview.Invalidate()
						m.layout.ActivePanel = PanelEditor
					}
				}
			case "r":
				m.fileTree.Scan()
			}

		case PanelPreview:
			switch msg.String() {
			case "j", "down":
				m.preview.ScrollDown(1)
			case "k", "up":
				m.preview.ScrollUp(1)
			case "d":
				m.preview.ScrollDown(10)
			case "u":
				m.preview.ScrollUp(10)
			}

		case PanelBrain:
			switch msg.String() {
			case "j", "down":
				m.brain.MoveSelection(1)
			case "k", "up":
				m.brain.MoveSelection(-1)
			case "f":
				m.brain.LocalMode = !m.brain.LocalMode
			case "+", "=":
				m.brain.zoom = min(m.brain.zoom+0.2, 3.0)
			case "-":
				m.brain.zoom = max(m.brain.zoom-0.2, 0.3)
			case "h":
				m.brain.viewportX -= 3
			case "l":
				m.brain.viewportX += 3
			}
		}

		return m, nil
	}

	return m, nil
}

// View implements tea.Model.
func (m AppModel) View() tea.View {
	if m.quitting {
		return tea.NewView("")
	}

	if m.width == 0 || m.height == 0 {
		return tea.NewView("Loading...")
	}

	// Title bar
	title := m.renderTitleBar()

	// Editor panel
	editorView := m.renderEditor()

	// Body: join panels horizontally
	var panels []string
	if m.layout.ShowFileTree {
		panels = append(panels, m.fileTree.View(m.layout.TreeRect))
	}
	panels = append(panels, editorView)
	if m.layout.ShowBrain {
		panels = append(panels, m.brain.View(m.layout.BrainRect))
	} else if m.layout.ShowPreview {
		panels = append(panels, m.preview.View(m.editor.Buf, m.layout.PreviewRect))
	}

	body := lipgloss.JoinHorizontal(lipgloss.Top, panels...)

	// Status bar + command bar
	statusBar := RenderStatusBar(m.editor, m.width, m.styles)
	commandBar := RenderCommandBar(m.editor, m.width, m.styles)

	screen := lipgloss.JoinVertical(lipgloss.Left,
		title, body, statusBar, commandBar)

	var v tea.View
	v.SetContent(screen)
	v.AltScreen = true
	return v
}

func (m AppModel) renderTitleBar() string {
	t := themes.Current()
	title := fmt.Sprintf(" LazyMD — %s ", t.Name)
	padW := m.width - lipgloss.Width(title)
	if padW < 0 {
		padW = 0
	}
	return m.styles.TitleBar.Width(m.width).Render(title + strings.Repeat(" ", padW))
}

func (m AppModel) renderEditor() string {
	ed := m.editor
	rect := m.layout.EditorRect
	gutterW := 4 // line number width
	contentW := rect.W - gutterW - 1
	if contentW < 1 {
		contentW = 1
	}

	var lines []string
	for row := 0; row < rect.H; row++ {
		bufRow := ed.ScrollRow + row
		if bufRow >= ed.Buf.LineCount() {
			// Empty line with tilde
			gutter := m.styles.MutedText.Render(fmt.Sprintf("%*s", gutterW, "~"))
			lines = append(lines, gutter+strings.Repeat(" ", contentW+1))
			continue
		}

		// Line number
		var gutter string
		if bufRow == ed.Row {
			gutter = m.styles.LineNumberActive.Render(fmt.Sprintf("%*d", gutterW, bufRow+1))
		} else {
			gutter = m.styles.LineNumber.Render(fmt.Sprintf("%*d", gutterW, bufRow+1))
		}

		// Line content
		line := ed.Buf.Line(bufRow)
		// Handle horizontal scroll
		if ed.ScrollCol > 0 && ed.ScrollCol < len(line) {
			line = line[ed.ScrollCol:]
		} else if ed.ScrollCol >= len(line) {
			line = ""
		}

		// Truncate to content width
		if len(line) > contentW {
			line = line[:contentW]
		}

		// Render cursor on current line
		if bufRow == ed.Row {
			cursorCol := ed.Col - ed.ScrollCol
			if cursorCol >= 0 && cursorCol < len(line) {
				before := line[:cursorCol]
				cursor := m.styles.Cursor.Render(string(line[cursorCol]))
				after := ""
				if cursorCol+1 < len(line) {
					after = line[cursorCol+1:]
				}
				line = before + cursor + after
			} else if cursorCol == len(line) {
				line += m.styles.Cursor.Render(" ")
			}
		}

		// Pad to width
		displayW := lipgloss.Width(line)
		pad := contentW - displayW
		if pad < 0 {
			pad = 0
		}

		lines = append(lines, gutter+" "+line+strings.Repeat(" ", pad))
	}

	return strings.Join(lines, "\n")
}

// teaKeyToEditorKey converts a Bubble Tea key message to an editor Key.
func teaKeyToEditorKey(msg tea.KeyPressMsg) editor.Key {
	s := msg.String()

	// Check for ctrl combinations
	if len(s) > 5 && s[:5] == "ctrl+" {
		ch := rune(s[5])
		return editor.CtrlKey(ch)
	}

	// Special keys
	switch s {
	case "esc":
		return editor.SpecialKey(editor.KeyEscape)
	case "enter":
		return editor.SpecialKey(editor.KeyEnter)
	case "backspace":
		return editor.SpecialKey(editor.KeyBackspace)
	case "delete":
		return editor.SpecialKey(editor.KeyDelete)
	case "tab":
		return editor.SpecialKey(editor.KeyTab)
	case "up":
		return editor.SpecialKey(editor.KeyUp)
	case "down":
		return editor.SpecialKey(editor.KeyDown)
	case "left":
		return editor.SpecialKey(editor.KeyLeft)
	case "right":
		return editor.SpecialKey(editor.KeyRight)
	case "home":
		return editor.SpecialKey(editor.KeyHome)
	case "end":
		return editor.SpecialKey(editor.KeyEnd)
	case "pgup":
		return editor.SpecialKey(editor.KeyPageUp)
	case "pgdown":
		return editor.SpecialKey(editor.KeyPageDown)
	case "space":
		return editor.CharKey(' ')
	}

	// Regular character
	runes := []rune(s)
	if len(runes) == 1 {
		return editor.CharKey(runes[0])
	}

	// Unknown key — ignore
	return editor.Key{}
}
