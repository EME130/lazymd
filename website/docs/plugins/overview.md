---
title: Plugin System Overview
sidebar_position: 1
description: "LazyMD's extensible plugin system — register custom commands, hook into editor events, add custom panels, and extend the status bar using Go interfaces."
keywords: [LazyMD plugins, plugin system, editor plugins, Go plugin, extensible editor, custom commands]
---

# Plugin System Overview

lm has an extensible plugin architecture that lets you:

- Register custom commands
- Hook into editor events (file open/save, buffer changes, mode changes)
- Add custom UI panels
- Extend the status bar

Plugins are Go types that implement the `Plugin` interface.
