package ui

import (
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

// RenderCommandBar renders the command bar (: prompt or status message).
func RenderCommandBar(ed *editor.EditorModel, width int, styles Styles) string {
	var content string

	if ed.Mode() == editor.ModeCommand {
		content = ":" + ed.CmdBuf
	} else if ed.Status.Text != "" {
		if ed.Status.IsError {
			content = styles.ErrorText.Render(ed.Status.Text)
		} else {
			content = ed.Status.Text
		}
	}

	// Pad to full width
	contentW := len(content)
	if contentW < width {
		content += strings.Repeat(" ", width-contentW)
	}

	return styles.CommandBar.Width(width).Render(content)
}
