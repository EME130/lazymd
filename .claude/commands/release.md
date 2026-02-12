Prepare a release for the project. Version: $ARGUMENTS

Steps:
1. Check current version/tags: `git tag --sort=-v:refname | head -10`
2. If no version arg given, suggest the next version based on commits since last tag
3. Generate changelog from commits since last tag using conventional commit format
4. Check that `zig build` and `zig build test` pass
5. Show the release summary and wait for approval before:
   - Creating the git tag
   - Creating a GitHub release with `gh release create` including the changelog

Do NOT push or create the release without explicit user confirmation.
