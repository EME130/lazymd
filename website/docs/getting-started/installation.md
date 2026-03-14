---
title: Installation
sidebar_position: 1
description: How to install LazyMD, the terminal-based markdown editor with vim keybindings. Build from source with Go or download pre-built binaries for Linux and macOS.
keywords: [LazyMD install, terminal markdown editor install, Go markdown editor, LazyMD setup, build LazyMD]
---

# Installation

## Prerequisites

lm requires [Go](https://go.dev/dl/) version 1.24.2 or later.

## Build from source

```bash
git clone https://github.com/EME130/lazymd.git
cd lazymd
go build -o lm ./cmd/lm
```

Move the binary to your PATH:

```bash
cp lm /usr/local/bin/
```

## Pre-built binaries

Download pre-built binaries from [GitHub Releases](https://github.com/EME130/lazymd/releases). Available for:

- Linux x86_64
- macOS x86_64
- macOS ARM64 (Apple Silicon)
