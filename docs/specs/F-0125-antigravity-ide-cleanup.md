# F-0125: Clean up orphaned Antigravity IDE remnants

**Type:** Refactor / Cleanup
**Priority:** P2 (nice to have — reclaims ~200 MB disk, removes dead config)
**Status:** In Progress
**Requested by:** PO
**Date:** 2026-05-29

## Problem

After F-0116 removed the Antigravity IDE apt package (`/usr/bin/antigravity`), four
orphaned directories that belonged exclusively to the IDE remain on the persistent disk:

| Path | Size | Origin |
|------|------|--------|
| `~/.config/Antigravity` | ~30 MB | IDE userData (Electron `--user-data-dir`) |
| `~/.config/Antigravity.bak.1780085055` | ~72 MB | Backup of above, created during IDE setup |
| `~/.antigravity` | ~91 MB | IDE extensions / local state dir |
| `~/.cache/antigravity` | ~8 KB | IDE cache |

These are distinct from, and must not be confused with, the Hub and CLI directories
which are current and working:
- `~/.config/Antigravity-Hub` — Hub userData (**KEEP**)
- `~/.local/share/antigravity-hub/` — Hub binary (**KEEP**)
- `~/.gemini/antigravity-cli/` — Antigravity CLI install (**KEEP**)
- `~/.gemini/antigravity/` — Antigravity CLI state (**KEEP**)
- `~/.antigravitycli/` — Symlinks into `~/.gemini/config/projects/`; confirmed CLI project
  state (not IDE). (**KEEP**)

Additionally, the sway config carries a now-dead comment block and `for_window` rule
installed by F-0116:

```
# F-0116: Pin the Antigravity Hub to workspace 1.
# ...  (The Antigravity IDE (the only other app that shared app_id="antigravity")
# has been removed, so this rule is unambiguous ...)
for_window [app_id="antigravity"] move container to workspace number 1
```

Since F-0124 **removed Hub autostart entirely**, the Hub is now launched manually via
`hub-restart`. The `for_window` placement rule that was needed when the Hub was
auto-launched at boot is now dead: `hub-restart` already includes an explicit
`swaymsg workspace 1` call before launching the Hub, making the sway rule redundant.
The comment block references the IDE removal context from F-0116, which is no longer
helpful now that both IDE and Hub autostart are gone.

Leaving this dead rule causes minor confusion (the comment says the IDE "has been
removed" — past tense, context no longer needed) and adds unnecessary surface area.

## Requirements

1. The cleanup of orphaned IDE dirs MUST be idempotent and run on every boot AND on
   fresh project setup (satisfying the persistence rules: reboot, teardown+setup,
   fresh-project setup).
2. The cleanup MUST only remove the four specific orphaned IDE directories listed
   above, never Hub or CLI dirs.
3. The cleanup function MUST include an explicit guard: if any Hub or CLI directory
   would be matched by the rm call, the implementation is wrong.
4. The dead `for_window [app_id="antigravity"]` rule and its explanatory comment
   block MUST be removed from all three sway config locations:
   - `workstation-image/configs/sway/config` (repo source of truth)
   - `~/.config/home-manager/sway-config` (must match repo exactly)
   - `scripts/cloud-build-setup.sh` deploys repo → home-manager, so it does not
     need a separate change as long as the repo config is updated.
5. The `10-tests.sh` boot test suite MUST be updated:
   - Assert each orphaned IDE dir is absent after cleanup runs.
   - Assert Hub dir (`~/.config/Antigravity-Hub`) is still present (over-deletion guard).
   - Assert CLI dir (`~/.gemini/antigravity-cli`) is still present (over-deletion guard).
   - Assert the dead `for_window [app_id="antigravity"]` rule is absent from the sway config.
   - Retain the existing F-0116 test asserting `/usr/bin/antigravity` is absent.
   - Remove the now-stale F-0116 Hub-placement-rule positive-presence test
     (since we are removing that rule, the test must be removed too).

## Acceptance Criteria

- [ ] `~/.config/Antigravity` does not exist after a boot or fresh setup.
- [ ] `~/.config/Antigravity.bak.1780085055` does not exist after a boot or fresh setup.
- [ ] `~/.antigravity` does not exist after a boot or fresh setup.
- [ ] `~/.cache/antigravity` does not exist after a boot or fresh setup.
- [ ] `~/.config/Antigravity-Hub` (Hub userData) still exists after cleanup runs.
- [ ] `~/.gemini/antigravity-cli` (CLI install) still exists after cleanup runs.
- [ ] `~/.antigravitycli` (CLI project state) still exists after cleanup runs.
- [ ] `for_window [app_id="antigravity"]` and its comment block are absent from
  `workstation-image/configs/sway/config`.
- [ ] `~/.config/home-manager/sway-config` exactly matches the repo sway config
  (no diff on the relevant lines).
- [ ] All `10-tests.sh` assertions pass (both new and retained).
- [ ] `bash -n` passes on all modified shell scripts.

## Out of Scope

- `~/.antigravitycli/` — confirmed CLI project state (symlinks into
  `~/.gemini/config/projects/`). This dir is owned by the Antigravity CLI, not the
  IDE. No action.
- `~/.gemini/antigravity/` — CLI state. No action.
- Any cleanup of the Hub or its userData. Hub cleanup is handled by F-0114's stale
  lock removal (which remains operational via `hub-restart`).
- Raising the F-0121 `wait_for_user_session` timeout (that is tracked separately as
  F-0123).

## Dependencies

- F-0116 (removed the IDE — this spec cleans up what F-0116 left behind)
- F-0124 (removed Hub autostart — makes the `for_window` rule redundant)

## Open Questions

- None. `~/.antigravitycli` investigated and confirmed CLI project state; KEEP.
