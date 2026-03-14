---
title: Developing Plugins
sidebar_position: 3
description: How to create custom plugins for LazyMD in Go. Step-by-step guide with a Hello World example using the plugin interface.
keywords: [LazyMD plugin development, Go plugin, create plugin, plugin tutorial, interface, editor plugin guide]
---

# Developing Plugins

See the full [Plugin Development Guide](https://github.com/EME130/lazymd/blob/main/docs/PLUGIN_GUIDE.md) for detailed instructions.

## Quick overview

1. Create a Go file in `internal/plugins/`
2. Implement the `Plugin` interface methods: `Info()`, `Init()`, `Deinit()`, `OnEvent()`, `Commands()`
3. Register your plugin in the plugin manager
4. Build and test

## Example: Hello World Plugin

```go
package plugins

type HelloPlugin struct{}

func (p *HelloPlugin) Info() PluginInfo {
    return PluginInfo{
        Name:        "hello",
        Version:     "0.1.0",
        Author:      "You",
        Description: "Says hello",
    }
}

func (p *HelloPlugin) Init(ed PluginEditor) {
    ed.SetStatus("Hello plugin loaded!", false)
}

func (p *HelloPlugin) Deinit()                {}
func (p *HelloPlugin) OnEvent(event Event)     {}
func (p *HelloPlugin) Commands() []CommandDef  { return nil }
```
