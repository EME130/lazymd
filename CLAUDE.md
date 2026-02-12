# lazy-md

Terminal-based markdown editor written in Zig. Inspired by lazygit/lazydocker.

## Tech Stack

- Language: Zig (0.13.0+)
- File format: `.rndm` (100% backward compatible with `.md`)

## Build Commands

```bash
zig build        # Build the project
zig build run    # Run the editor
zig build test   # Run tests
```

## Project Structure

```
src/
  main.zig       # Entry point
build.zig        # Build configuration
build.zig.zon    # Package manifest
```

## Planned Features

- TUI editor with vim-like navigation
- Syntax highlighting
- Built-in version control support
- Markdown preview
- Extensible plugin system
- MCP connector for AI agent integration

## Slash Commands

Zig dev: `/zig-test`, `/zig-check`, `/zig-build`, `/zig-debug`
OSS: `/release`, `/changelog`, `/issue-triage`, `/contrib-guide`

## Hooks

- `PostToolUse` on `Edit|Write`: auto-runs `zig fmt` on `.zig` files via `.claude/hooks/zig-fmt.sh`

## Reference Projects

- [lazygit](https://github.com/jesseduffield/lazygit)
- [lazydocker](https://github.com/jesseduffield/lazydocker)
