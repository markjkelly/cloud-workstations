# /regenerate — Regenerate project files from settings

## Trigger

User invokes `/regenerate` to regenerate CLAUDE.md and all agent/skill files from saved settings.

## Instructions

1. **Verify settings exist** — Check that `.appteam/settings.json` exists in the project root. If it does not exist, inform the user that no saved settings were found and suggest running `appteam` interactively first
2. **Run regeneration** — Execute:
   ```
   appteam -r
   ```
   This reads `.appteam/settings.json` and regenerates all files (CLAUDE.md, agent definitions, skill files, docs templates)
3. **Restore tracking files** — After regeneration, restore project-specific tracking files from git so they are not overwritten:
   ```
   git checkout -- docs/BACKLOG.md docs/PROGRESS.md docs/RELEASENOTES.md
   ```
   If any of these files have uncommitted changes, warn the user before restoring
4. **Report results** — List all files that were regenerated and confirm the tracking files were preserved

## Project Context

- **Project:** Cloud Workstation
- **Settings file:** `.appteam/settings.json`
