# Contributing to lazy-md

Thank you for your interest in contributing to lazy-md!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/lazy-md.git`
3. Install [Zig](https://ziglang.org/download/) 0.15.1+

## Development Workflow

```bash
zig build          # Build
zig build run      # Run the editor
zig build test     # Run all tests
zig fmt src/       # Format code
```

## Making Changes

1. Create a branch: `git checkout -b feature/my-feature`
2. Make your changes
3. Ensure tests pass: `zig build test`
4. Ensure code is formatted: `zig fmt src/`
5. Commit with a clear message
6. Push and open a pull request

## Code Style

- Follow Zig standard conventions
- Use `zig fmt` for formatting (enforced by CI)
- Keep functions focused and small
- Add tests for new functionality

## Project Structure

```
src/
  main.zig               Entry point, event loop
  Terminal.zig            Raw mode, ANSI codes, colors, mouse
  Input.zig               Key + mouse event parsing
  Buffer.zig              Gap buffer, undo/redo, file I/O
  Editor.zig              Vim modes, cursor, rendering
  Renderer.zig            Double-buffered cell grid
  markdown/syntax.zig     Markdown tokenizer + theme
  ui/Layout.zig           3-panel layout
  ui/Preview.zig          Markdown preview renderer
  plugin.zig              Plugin system
  plugins/                Community plugins
```

## Adding a Plugin

See the [Plugin Development Guide](docs/PLUGIN_GUIDE.md) for how to create plugins.

## Reporting Issues

- Use GitHub Issues
- Include your OS, Zig version, and terminal emulator
- Provide steps to reproduce

## Pull Request Guidelines

- Keep PRs focused on a single change
- Add tests for new features
- Update documentation if needed
- Ensure CI passes
