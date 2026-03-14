package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type SlidesPlugin struct{}

func (p *SlidesPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "slides",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Terminal presentation slides",
	}
}

func (p *SlidesPlugin) Init(ed editor.PluginEditor) {}

func (p *SlidesPlugin) OnEvent(event *PluginEvent) {}

func (p *SlidesPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "slides", Description: "Count slides in presentation", Handler: slidesHandler},
		{Name: "slides.next", Description: "Go to next slide", Handler: slidesNextHandler},
		{Name: "slides.prev", Description: "Go to previous slide", Handler: slidesPrevHandler},
		{Name: "slides.new", Description: "Insert new slide", Handler: slidesNewHandler},
	}
}

func slidesHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	slideCount := 0

	for i := 0; i < buf.LineCount(); i++ {
		line := strings.TrimSpace(buf.Line(i))
		if line == "---" {
			slideCount++
		}
	}

	// Add 1 for the first slide before the first separator
	if slideCount > 0 || buf.LineCount() > 0 {
		slideCount++
	}

	msg := fmt.Sprintf("Presentation: %d slides", slideCount)
	ed.SetStatus(msg, false)
}

func slidesNextHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	currentRow := ed.CursorRow()

	for i := currentRow + 1; i < buf.LineCount(); i++ {
		line := strings.TrimSpace(buf.Line(i))
		if line == "---" {
			ed.SetCursorRow(i)
			ed.SetStatus("Next slide", false)
			return
		}
	}

	ed.SetStatus("Already on last slide", false)
}

func slidesPrevHandler(ed editor.PluginEditor, args string) {
	currentRow := ed.CursorRow()
	buf := ed.Buffer()

	for i := currentRow - 1; i >= 0; i-- {
		line := strings.TrimSpace(buf.Line(i))
		if line == "---" {
			ed.SetCursorRow(i)
			ed.SetStatus("Previous slide", false)
			return
		}
	}

	ed.SetStatus("Already on first slide", false)
}

func slidesNewHandler(ed editor.PluginEditor, args string) {
	buf := ed.Buffer()
	offset := buf.PosToOffset(ed.CursorRow(), ed.CursorCol())

	template := "---\n\n# Slide Title\n\nContent\n\n"
	buf.InsertString(offset, template)

	ed.SetStatus("New slide inserted", false)
}
