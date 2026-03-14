package ui

import (
	"strings"

	"github.com/EME130/lazymd/internal/buffer"
	"github.com/EME130/lazymd/internal/themes"
	"github.com/charmbracelet/glamour"
	"github.com/charmbracelet/lipgloss"
)

// PreviewModel renders a markdown preview using Glamour.
type PreviewModel struct {
	rendered  string
	dirty     bool
	scrollOff int
}

// NewPreview creates a new preview model.
func NewPreview() PreviewModel {
	return PreviewModel{dirty: true}
}

// Invalidate marks the preview as needing re-render.
func (p *PreviewModel) Invalidate() {
	p.dirty = true
}

// ScrollUp scrolls the preview up.
func (p *PreviewModel) ScrollUp(n int) {
	p.scrollOff -= n
	if p.scrollOff < 0 {
		p.scrollOff = 0
	}
}

// ScrollDown scrolls the preview down.
func (p *PreviewModel) ScrollDown(n int) {
	p.scrollOff += n
}

// View renders the markdown preview panel.
func (p *PreviewModel) View(buf *buffer.Buffer, rect Rect) string {
	c := themes.CurrentColors()

	if buf.Length() == 0 {
		style := lipgloss.NewStyle().
			Width(rect.W).Height(rect.H).
			Foreground(lipgloss.Color(c.TextMuted))
		return style.Render("  No content to preview")
	}

	// Re-render markdown if dirty
	if p.dirty {
		content := buf.Content()
		r, err := glamour.NewTermRenderer(
			glamour.WithAutoStyle(),
			glamour.WithWordWrap(rect.W-4),
		)
		if err == nil {
			rendered, err := r.Render(content)
			if err == nil {
				p.rendered = rendered
			} else {
				p.rendered = content
			}
		} else {
			p.rendered = content
		}
		p.dirty = false
	}

	// Split into lines and apply scrolling
	lines := strings.Split(p.rendered, "\n")

	// Clamp scroll
	if p.scrollOff > len(lines)-1 {
		p.scrollOff = len(lines) - 1
	}
	if p.scrollOff < 0 {
		p.scrollOff = 0
	}

	var visible []string
	for i := 0; i < rect.H; i++ {
		idx := p.scrollOff + i
		if idx >= len(lines) {
			visible = append(visible, "")
			continue
		}
		line := lines[idx]
		// Truncate to width
		if lipgloss.Width(line) > rect.W-2 {
			// Simple truncation — glamour output may have ANSI codes
			runes := []rune(line)
			if len(runes) > rect.W-2 {
				line = string(runes[:rect.W-2])
			}
		}
		visible = append(visible, line)
	}

	content := strings.Join(visible, "\n")
	border := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(lipgloss.Color(c.Border)).
		Width(rect.W).Height(rect.H)
	return border.Render(content)
}
