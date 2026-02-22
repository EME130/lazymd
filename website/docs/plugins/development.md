---
title: Developing Plugins
sidebar_position: 3
description: How to create custom plugins for lazy-md in Zig. Step-by-step guide with a Hello World example using the plugin vtable interface.
keywords: [lazy-md plugin development, zig plugin, create plugin, plugin tutorial, vtable interface, editor plugin guide]
---

# Developing Plugins

See the full [Plugin Development Guide](https://github.com/user/lazy-md/blob/main/docs/PLUGIN_GUIDE.md) for detailed instructions.

## Quick overview

1. Create a Zig file in `src/plugins/`
2. Implement the plugin interface methods: `pluginInfo()`, `pluginInit()`, `pluginDeinit()`, `onEvent()`, `getCommands()`
3. Register your plugin in `main.zig` with `plugin.makePlugin()`
4. Build and test

## Example: Hello World Plugin

```zig
const plugin = @import("../plugin.zig");

const Self = @This();

pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{
        .name = "hello",
        .version = "0.1.0",
        .author = "You",
        .description = "Says hello",
    };
}

pub fn pluginInit(self: *Self, editor: *Editor) void {
    _ = self;
    editor.status.set("Hello plugin loaded!", false);
}

pub fn pluginDeinit(self: *Self) void { _ = self; }
pub fn onEvent(self: *Self, event: *plugin.PluginEvent) void { _ = self; _ = event; }
pub fn getCommands(self: *Self) []const plugin.CommandDef { _ = self; return &.{}; }
```
