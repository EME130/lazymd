---
title: Plugin System Overview
sidebar_position: 1
description: How the lazy-md plugin system works
---

# Plugin System Overview

lazy-md has an extensible plugin architecture that lets you:

- Register custom commands
- Hook into editor events (file open/save, buffer changes, mode changes)
- Add custom UI panels
- Extend the status bar

Plugins are Zig modules that implement the `Plugin` interface using a vtable pattern.
