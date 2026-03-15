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
	lastWidth int
	renderer  *glamour.TermRenderer
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

// RenderNow performs the glamour render immediately (called from Update on debounce tick).
func (p *PreviewModel) RenderNow(buf *buffer.Buffer, rect Rect) {
	if buf.Length() == 0 {
		p.rendered = ""
		p.dirty = false
		return
	}

	wrapWidth := rect.W - 4
	if wrapWidth < 20 {
		wrapWidth = 20
	}

	// Recreate renderer if width changed or first use
	if p.renderer == nil || p.lastWidth != wrapWidth {
		r, err := glamour.NewTermRenderer(
			glamour.WithAutoStyle(),
			glamour.WithWordWrap(wrapWidth),
		)
		if err == nil {
			p.renderer = r
			p.lastWidth = wrapWidth
		}
	}

	content := buf.Content()
	if p.renderer != nil {
		rendered, err := p.renderer.Render(content)
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

// View renders the markdown preview panel.
func (p *PreviewModel) View(buf *buffer.Buffer, rect Rect) string {
	c := themes.CurrentColors()

	if buf.Length() == 0 {
		style := lipgloss.NewStyle().
			Width(rect.W).Height(rect.H).
			Foreground(lipgloss.Color(c.TextMuted))
		return style.Render("  No content to preview")
	}

	if p.dirty && p.rendered == "" {
		style := lipgloss.NewStyle().
			Width(rect.W).Height(rect.H).
			Foreground(lipgloss.Color(c.TextMuted))
		return style.Render("  Rendering...")
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

	contentH := rect.H - 1 // account for panel header
	if contentH < 1 {
		contentH = 1
	}

	var visible []string
	for i := 0; i < contentH; i++ {
		idx := p.scrollOff + i
		if idx >= len(lines) {
			visible = append(visible, "")
			continue
		}
		line := lines[idx]
		if lipgloss.Width(line) > rect.W-2 {
			runes := []rune(line)
			if len(runes) > rect.W-2 {
				line = string(runes[:rect.W-2])
			}
		}
		visible = append(visible, line)
	}

	return strings.Join(visible, "\n")
}
