---
title: API Reference
sidebar_position: 4
description: Plugin API types and events
---

# Plugin API Reference

## EventType

| Event | Description |
|-------|-------------|
| `file_open` | A file was opened |
| `file_save` | A file was saved |
| `file_close` | A file was closed |
| `buffer_changed` | Buffer content changed |
| `mode_changed` | Vim mode changed |
| `cursor_moved` | Cursor position changed |
| `command` | A plugin command was invoked |
| `render` | Render cycle |

## PluginInfo

```zig
pub const PluginInfo = struct {
    name: []const u8,
    version: []const u8,
    author: []const u8,
    description: []const u8,
};
```

## CommandDef

```zig
pub const CommandDef = struct {
    name: []const u8,
    description: []const u8,
    handler: *const fn (*PluginEvent) void,
};
```
