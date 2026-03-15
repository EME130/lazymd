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

	// Line count
	lines := fmt.Sprintf("%d lines", ed.Buf.LineCount())

	// Compose: mode | filename ... lines | position
	modeW := lipgloss.Width(mode)
	posW := lipgloss.Width(pos)
	linesW := lipgloss.Width(lines)
	fileW := width - modeW - posW - linesW - 5
	if fileW < 0 {
		fileW = 0
	}

	// Truncate filename if needed
	if lipgloss.Width(file) > fileW {
		if fileW > 3 {
			file = "..." + file[len(file)-fileW+3:]
		} else {
			file = file[:fileW]
		}
	}

	gap := fileW - lipgloss.Width(file)
	if gap < 0 {
		gap = 0
	}

	bar := mode + " " + file + strings.Repeat(" ", gap) + " " + lines + " " + pos + " "

	// Pad to full width
	barW := lipgloss.Width(bar)
	if barW < width {
		bar += strings.Repeat(" ", width-barW)
	}

	return styles.StatusBar.Width(width).Render(bar)
}
