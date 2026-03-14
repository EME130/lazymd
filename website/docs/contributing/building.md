---
title: Building from Source
sidebar_position: 2
description: Build LazyMD from source with Go — debug builds, release builds, and running directly.
keywords: [build LazyMD, go build, compile from source, go project]
---

# Building from Source

```bash
# Build
go build -o lm ./cmd/lm

# Build with optimizations
go build -ldflags="-s -w" -o lm ./cmd/lm

# Run directly
go run ./cmd/lm -- myfile.md
```
