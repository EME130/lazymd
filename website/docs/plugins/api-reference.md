---
title: Plugin API Reference
sidebar_position: 4
description: LazyMD plugin API reference — EventType, PluginInfo, and CommandDef types. Hook into file open, save, buffer changes, mode changes, and cursor events.
keywords: [LazyMD API, plugin API, event types, command definition, plugin info, Go API reference]
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

```go
type PluginInfo struct {
    Name        string
    Version     string
    Author      string
    Description string
}
```

## CommandDef

```go
type CommandDef struct {
    Name        string
    Description string
    Handler     func(Event)
}
```
