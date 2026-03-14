package plugins

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type EmojiPlugin struct{}

var emojiTable = map[string]string{
	"smile":     "😊",
	"heart":     "❤️",
	"fire":      "🔥",
	"thumbsup":  "👍",
	"check":     "✅",
	"cross":     "❌",
	"star":      "⭐",
	"rocket":    "🚀",
	"warning":   "⚠️",
	"info":      "ℹ️",
	"bulb":      "💡",
	"book":      "📚",
	"pen":       "✏️",
	"computer":  "💻",
	"folder":    "📁",
	"clock":     "🕐",
	"calendar":  "📅",
	"tada":      "🎉",
	"thinking":  "🤔",
	"muscle":    "💪",
	"brain":     "🧠",
	"target":    "🎯",
	"chart":     "📊",
	"lock":      "🔒",
	"key":       "🔑",
	"email":     "📧",
	"phone":     "📱",
	"earth":     "🌍",
	"sun":       "☀️",
	"moon":      "🌙",
}

func (p *EmojiPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "emoji",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Emoji shortcode insertion",
	}
}

func (p *EmojiPlugin) Init(ed editor.PluginEditor) {}

func (p *EmojiPlugin) OnEvent(event *PluginEvent) {}

func (p *EmojiPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "emoji", Description: "Insert emoji by shortcode", Handler: emojiHandler},
		{Name: "emoji.list", Description: "List all emoji shortcodes", Handler: emojiListHandler},
	}
}

func emojiHandler(ed editor.PluginEditor, args string) {
	shortcode := strings.ToLower(strings.TrimSpace(args))
	if shortcode == "" {
		ed.SetStatus("Usage: emoji <shortcode>", true)
		return
	}

	if emoji, found := emojiTable[shortcode]; found {
		buf := ed.Buffer()
		row := ed.CursorRow()
		col := ed.CursorCol()
		offset := buf.PosToOffset(row, col)
		buf.InsertString(offset, emoji)
		ed.SetStatus(fmt.Sprintf("Inserted emoji: %s", emoji), false)
	} else {
		ed.SetStatus(fmt.Sprintf("Emoji not found: %s", shortcode), true)
	}
}

func emojiListHandler(ed editor.PluginEditor, args string) {
	shortcodes := []string{}
	for code := range emojiTable {
		shortcodes = append(shortcodes, code)
	}
	ed.SetStatus(fmt.Sprintf("Available emojis (%d): %s", len(shortcodes), strings.Join(shortcodes, ", ")), false)
}
