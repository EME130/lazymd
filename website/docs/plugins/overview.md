---
title: Plugin System Overview
sidebar_position: 1
description: "lazy-md's extensible plugin system — register custom commands, hook into editor events, add custom panels, and extend the status bar using Zig vtable interfaces."
keywords: [lazy-md plugins, plugin system, editor plugins, zig plugin, extensible editor, custom commands]
---

# Plugin System Overview

lazy-md has an extensible plugin architecture that lets you:

- Register custom commands
- Hook into editor events (file open/save, buffer changes, mode changes)
- Add custom UI panels
- Extend the status bar

Plugins are Zig modules that implement the `Plugin` interface using a vtable pattern.
