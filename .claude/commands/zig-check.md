Run a full project health check for the Zig codebase:

1. Run `zig fmt --check src/` to find formatting issues — report any files that need formatting
2. Run `zig build` to check for compilation errors
3. Run `zig build test` to check for test failures
4. Review build.zig for any dependency or configuration issues
5. Check for common Zig anti-patterns in recently modified files (use `git diff --name-only` to find them)

Report a summary with pass/fail status for each step. Fix any issues found if $ARGUMENTS contains "fix".
