package ui

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
	"github.com/charmbracelet/lipgloss"
)

// RenderStatusBar renders the status bar with mode indicator, filename, and cursor position.
func RenderStatusBar(ed *editor.EditorModel, width int, styles Styles) string {
	// Mode indicator
	modeStr := ed.Mode().String()
	var modeStyle lipgloss.Style
	switch ed.Mode() {
	case editor.ModeInsert:
		modeStyle = styles.ModeInsert
	case editor.ModeCommand:
		modeStyle = styles.ModeCommand
	default:
		modeStyle = styles.ModeNormal
	}
	mode := modeStyle.Render(modeStr)

	// Filename
	file := ed.File
	if file == "" {
		file = "[No File]"
	}
	if ed.Buf.IsDirty() {
		file += " [+]"
	}

	// Position
	pos := fmt.Sprintf("Ln %d, Col %d", ed.Row+1, ed.Col+1)

	// Compose: mode | filename ... position
	modeW := lipgloss.Width(mode)
	posW := len(pos)
	fileW := width - modeW - posW - 3 // 3 for separators/padding
	if fileW < 0 {
		fileW = 0
	}

	// Truncate filename if needed
	if len(file) > fileW {
		if fileW > 3 {
			file = "..." + file[len(file)-fileW+3:]
		} else {
			file = file[:fileW]
		}
	}

	gap := fileW - len(file)
	if gap < 0 {
		gap = 0
	}

	bar := mode + " " + file + strings.Repeat(" ", gap) + " " + pos

	// Pad to full width
	if lipgloss.Width(bar) < width {
		bar += strings.Repeat(" ", width-lipgloss.Width(bar))
	}

	return styles.StatusBar.Width(width).Render(bar)
}
