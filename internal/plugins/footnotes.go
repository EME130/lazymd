package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type FootnotesPlugin struct{}

func (p *FootnotesPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "footnotes",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Markdown footnote management",
	}
}

func (p *FootnotesPlugin) Init(ed editor.PluginEditor) {}

func (p *FootnotesPlugin) OnEvent(event *PluginEvent) {}

func (p *FootnotesPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "fn.add", Description: "Add footnote", Handler: fnAddHandler},
		{Name: "fn.list", Description: "List footnotes", Handler: fnListHandler},
	}
}

func fnAddHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()

	// Count existing footnotes
	maxNum := 0
	for i := 0; i < buf.LineCount(); i++ {
		line := buf.Line(i)
		if strings.Contains(line, "[^") {
			// Simple parsing - just count occurrences
			count := strings.Count(line, "[^")
			if count > maxNum {
				maxNum = count
			}
		}
	}

	nextNum := maxNum + 1

	// Insert reference at cursor
	row := ed.CursorRow()
	col := ed.CursorCol()
	offset := buf.PosToOffset(row, col)
	ref := fmt.Sprintf("[^%d]", nextNum)
	buf.InsertString(offset, ref)

	// Append definition at end
	endOffset := buf.Length()
	definition := fmt.Sprintf("\n[^%d]: ", nextNum)
	buf.InsertString(endOffset, definition)

	ed.SetStatus(fmt.Sprintf("Added footnote %d", nextNum), false)
}

func fnListHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	count := 0

	for i := 0; i < buf.LineCount(); i++ {
		line := buf.Line(i)
		count += strings.Count(line, "[^")
	}

	ed.SetStatus(fmt.Sprintf("Found %d footnote(s) in document", count), false)
}
