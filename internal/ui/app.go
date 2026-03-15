package ui

import (
	"fmt"
	"os"
	"strings"
	"time"

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

	// Preview debounce
	previewSeq int // incremented on each buffer change
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

// previewTickMsg fires after a debounce delay to trigger preview re-render.
type previewTickMsg struct {
	seq int
}

func previewDebounceCmd(seq int) tea.Cmd {
	return tea.Tick(250*time.Millisecond, func(time.Time) tea.Msg {
		return previewTickMsg{seq: seq}
	})
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
		m.preview.Invalidate()
		m.previewSeq++
		return m, previewDebounceCmd(m.previewSeq)

	case fileLoadMsg:
		if err := m.editor.OpenFile(msg.path); err != nil {
			m.editor.SetStatus(fmt.Sprintf("Failed to open: %v", err), true)
		} else {
			m.preview.Invalidate()
			m.previewSeq++
			return m, previewDebounceCmd(m.previewSeq)
		}
		return m, nil

	case previewTickMsg:
		// Only re-render if this is the latest debounce
		if msg.seq == m.previewSeq && m.preview.dirty {
			m.preview.RenderNow(m.editor.Buf, m.layout.PreviewRect)
		}
		return m, nil

	case tea.MouseClickMsg:
		return m.handleMouseClick(msg)

	case tea.MouseWheelMsg:
		return m.handleMouseWheel(msg)

	case tea.KeyPressMsg:
		if m.quitting {
			return m, nil
		}

		return m.handleKeyPress(msg)
	}

	return m, nil
}

func (m AppModel) handleMouseClick(msg tea.MouseClickMsg) (tea.Model, tea.Cmd) {
	// Determine which panel was clicked
	panel := m.layout.HitTest(msg.X, msg.Y)
	m.layout.ActivePanel = panel

	switch panel {
	case PanelEditor:
		// Click to place cursor
		bodyY := msg.Y - m.layout.TitleH
		if bodyY >= 0 && bodyY < m.layout.EditorRect.H {
			gutterW := 4
			editorX := msg.X - m.layout.TreeRect.W - gutterW - 1
			if editorX >= 0 {
				row := m.editor.ScrollRow + bodyY
				col := m.editor.ScrollCol + editorX
				if row < m.editor.Buf.LineCount() {
					m.editor.Row = row
					lineLen := m.editor.Buf.LineLen(row)
					if col > lineLen {
						col = lineLen
					}
					if m.editor.Mode() == editor.ModeNormal && col > 0 && col >= lineLen {
						col = lineLen - 1
					}
					m.editor.Col = col
					m.editor.DesiredCol = col
				}
			}
		}

	case PanelFileTree:
		bodyY := msg.Y - m.layout.TitleH
		if bodyY >= 0 && bodyY < m.layout.TreeRect.H {
			idx := m.fileTree.ScrollOff + bodyY
			if idx < len(m.fileTree.Entries) {
				m.fileTree.Cursor = idx
				// Double-click-like: if clicking already selected, open it
				path := m.fileTree.SelectedPath()
				if path != "" && !m.fileTree.Entries[idx].IsDir {
					if err := m.editor.OpenFile(path); err != nil {
						m.editor.SetStatus(fmt.Sprintf("Failed to open: %v", err), true)
					} else {
						m.preview.Invalidate()
						m.previewSeq++
						m.layout.ActivePanel = PanelEditor
						return m, previewDebounceCmd(m.previewSeq)
					}
				}
			}
		}

	case PanelPreview:
		// Just focus — no special click action

	case PanelBrain:
		// Just focus — no special click action
	}

	return m, nil
}

func (m AppModel) handleMouseWheel(msg tea.MouseWheelMsg) (tea.Model, tea.Cmd) {
	panel := m.layout.HitTest(msg.X, msg.Y)
	scrollLines := 3

	switch panel {
	case PanelEditor:
		switch msg.Button {
		case tea.MouseWheelUp:
			m.editor.ScrollRow -= scrollLines
			if m.editor.ScrollRow < 0 {
				m.editor.ScrollRow = 0
			}
		case tea.MouseWheelDown:
			maxScroll := m.editor.Buf.LineCount() - 1
			m.editor.ScrollRow += scrollLines
			if m.editor.ScrollRow > maxScroll {
				m.editor.ScrollRow = maxScroll
			}
		}

	case PanelFileTree:
		switch msg.Button {
		case tea.MouseWheelUp:
			for range scrollLines {
				m.fileTree.MoveUp()
			}
		case tea.MouseWheelDown:
			for range scrollLines {
				m.fileTree.MoveDown()
			}
		}

	case PanelPreview:
		switch msg.Button {
		case tea.MouseWheelUp:
			m.preview.ScrollUp(scrollLines)
		case tea.MouseWheelDown:
			m.preview.ScrollDown(scrollLines)
		}

	case PanelBrain:
		switch msg.Button {
		case tea.MouseWheelUp:
			m.brain.MoveSelection(-1)
		case tea.MouseWheelDown:
			m.brain.MoveSelection(1)
		}
	}

	return m, nil
}

func (m AppModel) handleKeyPress(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	key := msg.String()

	// Global panel toggles (work from any panel in normal mode or non-editor panels)
	if m.layout.ActivePanel != PanelEditor || m.editor.Mode() == editor.ModeNormal {
		switch key {
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
			m.preview.Invalidate()
			m.previewSeq++
			return m, previewDebounceCmd(m.previewSeq)
		case "alt+3":
			m.layout.TogglePanel(PanelBrain)
			m.layout.Compute(m.width, m.height)
			m.editor.ViewWidth = m.layout.EditorRect.W
			m.editor.ViewHeight = m.layout.EditorRect.H
			return m, nil
		case "tab":
			m.layout.CyclePanel()
			return m, nil
		}
	}

	// Route input to focused panel
	var cmd tea.Cmd
	switch m.layout.ActivePanel {
	case PanelEditor:
		edKey := teaKeyToEditorKey(msg)
		m.editor.HandleKey(edKey)
		m.editor.UpdateScroll()

		if m.editor.ShouldQuit {
			m.quitting = true
			return m, tea.Quit
		}

		// Debounced preview invalidation on buffer change
		if m.editor.BufferChanged() {
			m.preview.Invalidate()
			m.previewSeq++
			cmd = previewDebounceCmd(m.previewSeq)
		}

		// Refresh styles if theme changed
		m.styles = NewStyles()

	case PanelFileTree:
		switch key {
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
					m.previewSeq++
					m.layout.ActivePanel = PanelEditor
					cmd = previewDebounceCmd(m.previewSeq)
				}
			}
		case "r":
			m.fileTree.Scan()
		case "esc":
			m.layout.ActivePanel = PanelEditor
		}

	case PanelPreview:
		switch key {
		case "j", "down":
			m.preview.ScrollDown(1)
		case "k", "up":
			m.preview.ScrollUp(1)
		case "d":
			m.preview.ScrollDown(10)
		case "u":
			m.preview.ScrollUp(10)
		case "esc":
			m.layout.ActivePanel = PanelEditor
		}

	case PanelBrain:
		switch key {
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
		case "esc":
			m.layout.ActivePanel = PanelEditor
		}
	}

	return m, cmd
}

// View implements tea.Model.
func (m AppModel) View() tea.View {
	if m.quitting {
		return tea.NewView("")
	}

	if m.width == 0 || m.height == 0 {
		return tea.NewView("Loading...")
	}

	c := themes.CurrentColors()

	// Title bar with panel indicators
	title := m.renderTitleBar(c)

	// Editor panel (always visible)
	editorView := m.renderEditor()

	// Compose body panels horizontally
	var panels []string
	if m.layout.ShowFileTree {
		focused := m.layout.ActivePanel == PanelFileTree
		panels = append(panels, m.renderPanelBox("Files", m.fileTree.View(m.layout.TreeRect), m.layout.TreeRect, focused, c, false))
	}

	editorFocused := m.layout.ActivePanel == PanelEditor
	panels = append(panels, m.renderPanelBox(m.editorTitle(), editorView, m.layout.EditorRect, editorFocused, c, true))

	if m.layout.ShowBrain {
		focused := m.layout.ActivePanel == PanelBrain
		panels = append(panels, m.renderPanelBox("Brain", m.brain.View(m.layout.BrainRect), m.layout.BrainRect, focused, c, false))
	} else if m.layout.ShowPreview {
		focused := m.layout.ActivePanel == PanelPreview
		panels = append(panels, m.renderPanelBox("Preview", m.preview.View(m.editor.Buf, m.layout.PreviewRect), m.layout.PreviewRect, focused, c, false))
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
	v.MouseMode = tea.MouseModeCellMotion
	return v
}

func (m AppModel) editorTitle() string {
	file := m.editor.File
	if file == "" {
		return "Editor"
	}
	// Show just the filename
	parts := strings.Split(file, "/")
	name := parts[len(parts)-1]
	if m.editor.Buf.IsDirty() {
		name += " [+]"
	}
	return name
}

func (m AppModel) renderTitleBar(c *themes.ThemeColors) string {
	t := themes.Current()

	// Left: app name
	logo := lipgloss.NewStyle().
		Foreground(lipgloss.Color(c.BorderActive)).
		Bold(true).
		Render(" lm")

	sep := lipgloss.NewStyle().
		Foreground(lipgloss.Color(c.TextMuted)).
		Render(" | ")

	themeName := lipgloss.NewStyle().
		Foreground(lipgloss.Color(c.Text)).
		Render(t.Name)

	// Right: panel indicators
	indicators := m.renderPanelIndicators(c)

	left := logo + sep + themeName
	leftW := lipgloss.Width(left)
	rightW := lipgloss.Width(indicators)
	gap := m.width - leftW - rightW
	if gap < 0 {
		gap = 0
	}

	bar := left + strings.Repeat(" ", gap) + indicators
	return m.styles.TitleBar.Width(m.width).Render(bar)
}

func (m AppModel) renderPanelIndicators(c *themes.ThemeColors) string {
	active := lipgloss.NewStyle().Foreground(lipgloss.Color(c.BorderActive)).Bold(true)
	inactive := lipgloss.NewStyle().Foreground(lipgloss.Color(c.TextMuted))
	sep := lipgloss.NewStyle().Foreground(lipgloss.Color(c.TextMuted)).Render(" ")

	fileTreeInd := inactive.Render("[1]Files")
	previewInd := inactive.Render("[2]Preview")
	brainInd := inactive.Render("[3]Brain")

	if m.layout.ShowFileTree {
		fileTreeInd = active.Render("[1]Files")
	}
	if m.layout.ShowPreview {
		previewInd = active.Render("[2]Preview")
	}
	if m.layout.ShowBrain {
		brainInd = active.Render("[3]Brain")
	}

	return fileTreeInd + sep + previewInd + sep + brainInd + " "
}

func (m AppModel) renderPanelBox(title, content string, rect Rect, focused bool, c *themes.ThemeColors, isEditor bool) string {
	_ = isEditor

	// Panel header
	headerStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color(c.TextMuted)).
		Bold(false)
	if focused {
		headerStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(c.BorderActive)).
			Bold(true)
	}

	indicator := " "
	if focused {
		indicator = lipgloss.NewStyle().
			Foreground(lipgloss.Color(c.BorderActive)).
			Render("▌")
	}

	headerText := indicator + headerStyle.Render(title)
	headerW := lipgloss.Width(headerText)
	padW := rect.W - headerW
	if padW < 0 {
		padW = 0
	}
	header := headerText + strings.Repeat(" ", padW)

	// Reduce content height by 1 for header
	contentH := rect.H - 1
	if contentH < 0 {
		contentH = 0
	}

	// Truncate content to fit
	lines := strings.Split(content, "\n")
	if len(lines) > contentH {
		lines = lines[:contentH]
	}
	for len(lines) < contentH {
		lines = append(lines, strings.Repeat(" ", rect.W))
	}

	return header + "\n" + strings.Join(lines, "\n")
}

func (m AppModel) renderEditor() string {
	ed := m.editor
	rect := m.layout.EditorRect
	gutterW := 4
	contentW := rect.W - gutterW - 1
	if contentW < 1 {
		contentW = 1
	}

	// Account for panel header in available height
	availH := rect.H - 1
	if availH < 1 {
		availH = 1
	}

	var lines []string
	for row := 0; row < availH; row++ {
		bufRow := ed.ScrollRow + row
		if bufRow >= ed.Buf.LineCount() {
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
		if ed.ScrollCol > 0 && ed.ScrollCol < len(line) {
			line = line[ed.ScrollCol:]
		} else if ed.ScrollCol >= len(line) {
			line = ""
		}

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

	if len(s) > 5 && s[:5] == "ctrl+" {
		ch := rune(s[5])
		return editor.CtrlKey(ch)
	}

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

	runes := []rune(s)
	if len(runes) == 1 {
		return editor.CharKey(runes[0])
	}

	return editor.Key{}
}
