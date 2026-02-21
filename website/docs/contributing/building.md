---
title: Building from Source
sidebar_position: 2
description: Build instructions for lazy-md
---

# Building from Source

```bash
# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseSafe

# Run directly
zig build run -- myfile.md
```
