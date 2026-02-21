---
title: Installation
sidebar_position: 1
description: How to install lazy-md on your system
---

# Installation

## Prerequisites

lazy-md requires [Zig](https://ziglang.org/download/) version 0.15.1 or later.

## Build from source

```bash
git clone https://github.com/user/lazy-md.git
cd lazy-md
zig build
```

The compiled binary is at `zig-out/bin/lazy-md`. Move it to your PATH:

```bash
cp zig-out/bin/lazy-md /usr/local/bin/
```

## Pre-built binaries

Download pre-built binaries from [GitHub Releases](https://github.com/user/lazy-md/releases). Available for:

- Linux x86_64
- macOS x86_64
- macOS ARM64 (Apple Silicon)
