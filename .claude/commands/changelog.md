Generate a changelog from git history.

1. Get commits since last tag (or all commits if no tags): `git log --oneline`
2. Categorize commits into:
   - **Added** - New features
   - **Changed** - Changes to existing functionality
   - **Fixed** - Bug fixes
   - **Removed** - Removed features
   - **Infrastructure** - CI, build, tooling changes
3. Format as Keep a Changelog style (https://keepachangelog.com)
4. If $ARGUMENTS contains a range (e.g., "v0.1.0..v0.2.0"), use that range
5. Output the formatted changelog

Do not create/write files unless the user explicitly asks.
