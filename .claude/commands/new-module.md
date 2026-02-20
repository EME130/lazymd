Create a new Zig module at `src/$ARGUMENTS.zig` following codebase conventions:

1. Check existing files in `src/` for naming and style patterns
2. Create the module with:
   - `const std = @import("std");` at the top
   - PascalCase filename if the module defines a primary struct (e.g., `Buffer.zig`)
   - Proper pub declarations for the public interface
   - A `test` block at the bottom with at least one basic test
3. Wire the module into relevant imports (e.g., `main.zig` or other modules that need it)
4. Run `zig build` to verify it compiles
