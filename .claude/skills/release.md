# /release — Cut a new release

## Trigger

User invokes `/release` with a version number (e.g., `/release v0.5.0`).

## Instructions

1. **Determine the version** — Use the version number provided by the user. If none is provided, read `docs/RELEASENOTES.md` to find the latest version and suggest the next patch/minor/major bump
2. **Update release notes** — Edit `docs/RELEASENOTES.md` and add a new version entry at the top (below the header) following Keep a Changelog format:
   - `## [vX.Y.Z] — YYYY-MM-DD`
   - Sections: `### Added`, `### Changed`, `### Fixed` (only include sections with content)
   - Summarize changes since the last release by reading recent git commits
3. **Commit the release** — Stage and commit all pending changes:
   ```
   git -c user.name="Ameer Abbas" -c user.email="ameer00@gmail.com" commit -am "Release vX.Y.Z: summary"
   ```
   Include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` in the commit message
4. **Create an annotated git tag:**
   ```
   git -c user.name="Ameer Abbas" -c user.email="ameer00@gmail.com" tag -a vX.Y.Z -m "Release vX.Y.Z: summary"
   ```
5. **Push the commit and tag:**
   ```
   git push origin main && git push origin vX.Y.Z
   ```
6. **Report back** — Confirm the release was created, tagged, and pushed

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Ameer Abbas (ameer00@gmail.com)
- **Release notes:** `docs/RELEASENOTES.md`
