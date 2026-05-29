# F-0108: Automatic Boot Script Sync from Git Repo

**Type:** Feature
**Priority:** P1 (important)
**Status:** In Progress
**Requested by:** PO
**Date:** 2026-05-29

## Problem

Currently, after merging a change to the boot scripts or sway config in the repo, the user must manually run git pull and copy files to persist updates on the live workstation:
```bash
git pull
cp workstation-image/boot/07-apps.sh ~/boot/07-apps.sh
cp workstation-image/configs/sway/config ~/.config/home-manager/sway-config
# etc.
```

This is error-prone and easy to forget, leading to version drift between the repo and the live workstation. Changes intended to be automatic on next boot stay stale until manually synced.

## Requirements

1. New boot script `06-sync.sh` runs early in the boot sequence (before 07-apps.sh, 08-workspaces.sh, 10-tests.sh).
2. Must check if the repo directory exists (`/home/user/dev/git/cloud-workstations`). If missing, log a warning and exit gracefully (do not fail the boot sequence).
3. Must run `git pull --ff-only` in the repo (as the user, not root). Log success or failure.
4. Must copy all boot scripts from `workstation-image/boot/*.sh` to `~/boot/` (as the user).
5. Must copy the sway config from `workstation-image/configs/sway/config` to `~/.config/home-manager/sway-config` (as the user).
6. Must log all operations to `~/logs/sync.log` (consistent with other boot script convention).
7. Must NOT fail the boot sequence if git pull fails (e.g., network down, merge conflict). Use error-tolerant patterns like `|| true` or `|| echo "error" >> log`.
8. Must NOT update itself mid-run (this is expected behavior; updated script takes effect on next boot).

## Acceptance Criteria

- [ ] `06-sync.sh` exists and is executable in `workstation-image/boot/06-sync.sh`
- [ ] Script checks for repo directory and logs gracefully if missing
- [ ] Script runs `git pull --ff-only` with proper error handling (non-fatal)
- [ ] Script copies all `workstation-image/boot/*.sh` files to `~/boot/` and logs each
- [ ] Script copies sway config to `~/.config/home-manager/sway-config` and logs
- [ ] Boot sequence continues successfully even if git pull or copy fails
- [ ] `~/logs/sync.log` contains detailed operation log
- [ ] Boot tests in `10-tests.sh` verify `~/boot/06-sync.sh` exists
- [ ] Boot tests verify repo path constant in 06-sync.sh is correct
- [ ] `docs/STARTUP_SCRIPTS.md` updated with 06-sync.sh entry
- [ ] Script survives reboot, teardown+setup, and fresh project setup

## Out of Scope

- Automatic rerun of `home-manager switch` after copying sway config (user explicitly runs `swaymsg reload` or reboots)
- Conflict resolution for merge conflicts during git pull (logged; user must resolve manually)
- Syncing files outside of `workstation-image/boot/` and `workstation-image/configs/sway/config`

## Dependencies

- F-0033 (boot script architecture)
- F-0025 (Sway auto-start on boot)
- F-0102 (sway config deployment via boot scripts)

## Open Questions

None at this stage. PO decision: implement as specified, bootstrap via manual copy on first deployment.
