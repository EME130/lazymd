Build the project with `zig build` and analyze the output:

1. Run `zig build` (or `zig build $ARGUMENTS` if args provided)
2. If build succeeds, report success and binary location
3. If build fails, analyze the error:
   - Read the failing source file(s)
   - Explain the error in plain language
   - Suggest or apply the fix
   - Re-run the build to confirm

For release builds, use: /zig-build -Doptimize=ReleaseSafe
