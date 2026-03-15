package plugins

import (
	"github.com/EME130/lazymd/internal/editor"
)

// PluginInfo describes a plugin.
type PluginInfo struct {
	Name        string
	Version     string
	Author      string
	Description string
}

// EventType identifies the type of editor event.
type EventType string

const (
	EventFileOpen      EventType = "file_open"
	EventFileSave      EventType = "file_save"
	EventFileClose     EventType = "file_close"
	EventBufferChanged EventType = "buffer_changed"
	EventModeChanged   EventType = "mode_changed"
	EventCursorMoved   EventType = "cursor_moved"
	EventCommand       EventType = "command"
	EventRender        EventType = "render"
	EventAgentCommand  EventType = "agent_command"
)

// PluginEvent is passed to plugins on events.
type PluginEvent struct {
	Type        EventType
	Editor      editor.PluginEditor
	CommandName string
	CommandArgs string
}

// CommandHandler is the function signature for plugin command handlers.
type CommandHandler func(ed editor.PluginEditor, args string)

// CommandDef defines a plugin command.
type CommandDef struct {
	Name        string
	Description string
	Handler     CommandHandler
}

// Plugin is the interface all plugins implement.
type Plugin interface {
	Info() PluginInfo
	Init(ed editor.PluginEditor)
	OnEvent(event *PluginEvent)
	Commands() []CommandDef
}

// PluginManager manages all registered plugins.
type PluginManager struct {
	plugins    []Plugin
	commandMap map[string]commandEntry
}

type commandEntry struct {
	plugin  Plugin
	handler CommandHandler
}

// NewManager creates a new PluginManager.
func NewManager() *PluginManager {
	return &PluginManager{
		commandMap: make(map[string]commandEntry),
	}
}

// Register adds a plugin and initializes it.
func (pm *PluginManager) Register(p Plugin, ed editor.PluginEditor) {
	pm.plugins = append(pm.plugins, p)
	p.Init(ed)

	for _, cmd := range p.Commands() {
		pm.commandMap[cmd.Name] = commandEntry{
			plugin:  p,
			handler: cmd.Handler,
		}
	}
}

// Broadcast sends an event to all plugins.
func (pm *PluginManager) Broadcast(eventType string, ed editor.PluginEditor) {
	event := &PluginEvent{
		Type:   EventType(eventType),
		Editor: ed,
	}
	for _, p := range pm.plugins {
		p.OnEvent(event)
	}
}

// ExecuteCommand runs a plugin command by name. Returns true if handled.
func (pm *PluginManager) ExecuteCommand(name string, ed editor.PluginEditor, args string) bool {
	entry, ok := pm.commandMap[name]
	if !ok {
		return false
	}
	entry.handler(ed, args)
	return true
}

// PluginCount returns the number of registered plugins.
func (pm *PluginManager) PluginCount() int {
	return len(pm.plugins)
}

// Plugins returns all registered plugins.
func (pm *PluginManager) Plugins() []Plugin {
	return pm.plugins
}

// AllCommands returns all registered command names.
func (pm *PluginManager) AllCommands() []CommandDef {
	var cmds []CommandDef
	for _, p := range pm.plugins {
		cmds = append(cmds, p.Commands()...)
	}
	return cmds
}

// ListPlugins returns plugin summaries as editor DTOs.
func (pm *PluginManager) ListPlugins() []editor.PluginSummary {
	summaries := make([]editor.PluginSummary, len(pm.plugins))
	for i, p := range pm.plugins {
		info := p.Info()
		summaries[i] = editor.PluginSummary{
			Name:        info.Name,
			Version:     info.Version,
			Description: info.Description,
		}
	}
	return summaries
}

// ListCommands returns command summaries as editor DTOs.
func (pm *PluginManager) ListCommands() []editor.CommandSummary {
	var cmds []editor.CommandSummary
	for _, p := range pm.plugins {
		info := p.Info()
		for _, cmd := range p.Commands() {
			cmds = append(cmds, editor.CommandSummary{
				Name:        cmd.Name,
				Description: cmd.Description,
				PluginName:  info.Name,
			})
		}
	}
	return cmds
}

// RegisterAll registers all built-in plugins.
func RegisterAll(pm *PluginManager, ed editor.PluginEditor) {
	for _, p := range AllPlugins() {
		pm.Register(p, ed)
	}
}
