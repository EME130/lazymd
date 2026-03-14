package ui

import (
	"github.com/EME130/lazymd/internal/themes"
	"github.com/charmbracelet/lipgloss"
)

// Styles holds all UI styles derived from the current theme.
type Styles struct {
	TitleBar    lipgloss.Style
	StatusBar   lipgloss.Style
	CommandBar  lipgloss.Style
	EditorPane  lipgloss.Style
	LineNumber  lipgloss.Style
	LineNumberActive lipgloss.Style
	Cursor      lipgloss.Style
	ModeNormal  lipgloss.Style
	ModeInsert  lipgloss.Style
	ModeCommand lipgloss.Style
	ErrorText   lipgloss.Style
	MutedText   lipgloss.Style
}

// NewStyles creates styles from the current theme colors.
func NewStyles() Styles {
	c := themes.CurrentColors()
	return Styles{
		TitleBar:    lipgloss.NewStyle().Foreground(lipgloss.Color(c.TitleFg)).Background(lipgloss.Color(c.TitleBg)).Bold(true),
		StatusBar:   lipgloss.NewStyle().Foreground(lipgloss.Color(c.StatusFg)).Background(lipgloss.Color(c.StatusBg)),
		CommandBar:  lipgloss.NewStyle().Foreground(lipgloss.Color(c.Text)),
		EditorPane:  lipgloss.NewStyle(),
		LineNumber:  lipgloss.NewStyle().Foreground(lipgloss.Color(c.Gutter)),
		LineNumberActive: lipgloss.NewStyle().Foreground(lipgloss.Color(c.GutterActive)),
		Cursor:      lipgloss.NewStyle().Reverse(true),
		ModeNormal:  lipgloss.NewStyle().Foreground(lipgloss.Color("#000000")).Background(lipgloss.Color(c.ModeNormalBg)).Bold(true).Padding(0, 1),
		ModeInsert:  lipgloss.NewStyle().Foreground(lipgloss.Color("#000000")).Background(lipgloss.Color(c.ModeInsertBg)).Bold(true).Padding(0, 1),
		ModeCommand: lipgloss.NewStyle().Foreground(lipgloss.Color("#000000")).Background(lipgloss.Color(c.ModeCommandBg)).Bold(true).Padding(0, 1),
		ErrorText:   lipgloss.NewStyle().Foreground(lipgloss.Color(c.ErrColor)),
		MutedText:   lipgloss.NewStyle().Foreground(lipgloss.Color(c.TextMuted)),
	}
}
