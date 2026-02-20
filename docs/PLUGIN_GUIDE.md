# lazy-md Plugin Development Guide

Build plugins to extend lazy-md with custom commands, UI panels, and editor integrations.

## Overview

lazy-md's plugin system uses a vtable-based interface pattern. Plugins are Zig modules that implement the `Plugin` interface and register with the `PluginManager`.

## Quick Start

### 1. Create Your Plugin File

Create a new file in `src/plugins/` (e.g., `src/plugins/my_plugin.zig`):

```zig
const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");

const Self = @This();

// Plugin state
message: []const u8 = "Hello from my plugin!",

// ── Plugin Interface Implementation ─────────────────────────────

pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{
        .name = "my-plugin",
        .version = "0.1.0",
        .author = "Your Name",
        .description = "A sample lazy-md plugin",
    };
}

pub fn pluginInit(self: *Self, editor: *Editor) void {
    _ = self;
    editor.status.set("My plugin loaded!", false);
}

pub fn pluginDeinit(self: *Self) void {
    _ = self;
}

pub fn onEvent(self: *Self, event: *plugin.PluginEvent) void {
    _ = self;
    switch (event.type) {
        .file_save => {
            // React to file saves
        },
        .buffer_changed => {
            // React to content changes
        },
        else => {},
    }
}

pub fn getCommands(self: *Self) []const plugin.CommandDef {
    _ = self;
    return &[_]plugin.CommandDef{
        .{
            .name = "hello",
            .description = "Display a greeting",
            .handler = &helloCommand,
        },
    };
}

fn helloCommand(event: *plugin.PluginEvent) void {
    event.editor.status.set("Hello from my plugin!", false);
}
```

### 2. Register Your Plugin

In `src/main.zig`, create an instance and register it:

```zig
var my_plugin = MyPlugin{};
const p = plugin.makePlugin(MyPlugin, &my_plugin);
try plugin_mgr.register(p, &editor);
```

### 3. Build and Test

```bash
zig build test
zig build run
```

## Plugin Interface

Every plugin must implement these methods:

### `pluginInfo() -> PluginInfo`

Return metadata about your plugin:

```zig
pub const PluginInfo = struct {
    name: []const u8,        // Unique identifier (e.g., "word-count")
    version: []const u8,     // Semantic version (e.g., "1.0.0")
    author: []const u8,      // Author name
    description: []const u8, // Short description
};
```

### `pluginInit(editor: *Editor) -> void`

Called when the plugin is registered. Use this to:
- Set initial state
- Display a loading message
- Read configuration

### `pluginDeinit() -> void`

Called when the editor shuts down. Clean up any resources.

### `onEvent(event: *PluginEvent) -> void`

Called when editor events occur. Handle the events you care about:

```zig
pub const EventType = enum {
    file_open,       // A file was opened
    file_save,       // A file was saved
    file_close,      // A file was closed
    buffer_changed,  // Buffer content changed
    mode_changed,    // Vim mode changed (normal/insert/command)
    cursor_moved,    // Cursor position changed
    command,         // A plugin command was invoked
    render,          // Render cycle (for UI plugins)
};
```

### `getCommands() -> []const CommandDef`

Return the commands your plugin provides. Users invoke them with `:pluginname.command` syntax:

```zig
pub const CommandDef = struct {
    name: []const u8,
    description: []const u8,
    handler: *const fn (*PluginEvent) void,
};
```

## Event System

### Event Flow

1. User action triggers an event (keystroke, save, etc.)
2. `PluginManager.broadcast()` sends the event to all plugins
3. Each plugin's `onEvent()` is called in registration order
4. Plugins can modify editor state via the `event.editor` pointer

### Accessing Editor State

The `PluginEvent` struct gives you access to the editor:

```zig
pub fn onEvent(self: *Self, event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Read cursor position
    const row = editor.cursor_row;
    const col = editor.cursor_col;

    // Read current line
    const line = editor.buffer.getLine(row);

    // Set status message
    editor.status.set("Plugin message", false);

    // Check current mode
    if (editor.mode == .insert) {
        // Handle insert mode
    }
}
```

## Examples

### Word Count Plugin

```zig
pub fn onEvent(self: *Self, event: *plugin.PluginEvent) void {
    if (event.type != .buffer_changed) return;

    var count: usize = 0;
    const editor = event.editor;
    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        var in_word = false;
        for (line) |c| {
            if (c == ' ' or c == '\t' or c == '\n') {
                in_word = false;
            } else if (!in_word) {
                in_word = true;
                count += 1;
            }
        }
    }
    self.word_count = count;
}
```

### Auto-save Plugin

```zig
pub fn onEvent(self: *Self, event: *plugin.PluginEvent) void {
    if (event.type != .buffer_changed) return;
    self.changes += 1;
    if (self.changes >= 100) {
        if (event.editor.file_path) |path| {
            event.editor.buffer.saveFile(path) catch return;
            event.editor.status.set("Auto-saved", false);
            self.changes = 0;
        }
    }
}
```

## Best Practices

1. **Keep plugins focused** - One plugin, one responsibility
2. **Handle errors gracefully** - Never crash the editor
3. **Be event-efficient** - Return quickly from `onEvent()`, skip events you don't need
4. **Document your commands** - Use clear descriptions in `CommandDef`
5. **Clean up resources** - Free allocations in `pluginDeinit()`
6. **Use status messages** - Communicate plugin state to the user via `editor.status`

## Plugin Directory Structure

```
src/plugins/
  my_plugin.zig      # Plugin implementation
  another_plugin.zig  # Another plugin
```

## API Reference

See `src/plugin.zig` for the complete type definitions and `PluginManager` API.
