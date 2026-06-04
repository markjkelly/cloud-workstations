# F-0134: Sync sway-status to ~/.local/bin on every boot

**Type:** Bug
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-06-04

## Problem

`~/.local/bin/sway-status` is only deployed by `scripts/cloud-build-setup.sh` during
initial project provisioning. The `09-sync.sh` boot script syncs boot scripts and sway
config from the git repo on every boot, but does NOT sync `sway-status`. This means any
changes to `sway-status` in the repo (like the timezone change in F-0132) don't take
effect until a full `ws.sh teardown && ws.sh setup` rebuild.

The F-0132 timezone fix changed `TZ=America/Los_Angeles` → `TZ=America/Chicago` in
`workstation-image/configs/swaybar/sway-status`, but the live `~/.local/bin/sway-status`
still has the old timezone because 09-sync.sh never copies it.

## Requirements

1. `workstation-image/boot/09-sync.sh` must copy `$REPO_DIR/workstation-image/configs/swaybar/sway-status` to `$HOME_DIR/.local/bin/sway-status` on every boot.
2. The copy must preserve executable permissions (`chmod +x`).
3. The copy must only occur if the repo source file exists (graceful skip if missing).
4. The sync must follow the existing pattern in 09-sync.sh (guard, copy, chown, log).
5. Ownership must be restored to uid 1000 (user) after copy (script runs as root).

## Acceptance Criteria

- [ ] AC1: `09-sync.sh` contains a block that copies `sway-status` from repo to `~/.local/bin/sway-status`
- [ ] AC2: The copy is guarded by a file-existence check (`[[ -f ... ]]`)
- [ ] AC3: The copied file is executable and owned by user (1000:1000)
- [ ] AC4: A boot test in `10-tests.sh` verifies that `09-sync.sh` contains the sway-status sync
- [ ] AC5: Changes survive reboot (09-sync.sh itself is synced by the existing boot-script sync loop)

## Out of Scope

- Syncing other `~/.local/bin` scripts (hub-restart, snippet-picker, etc.) — those have their own deployment mechanisms
- Changing the sway-status script content itself

## Dependencies

- F-0108 (boot sync from repo — the script this builds on)
- F-0132 (timezone change — the motivating bug)

## Open Questions

- None — straightforward addition following existing pattern.
