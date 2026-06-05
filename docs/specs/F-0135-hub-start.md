# F-0135: hub-start — Minimal Hub Launch Script

**Type:** Feature
**Priority:** P2 (nice to have)
**Status:** Done
**Requested by:** PO
**Date:** 2026-06-04

## Problem

The existing `hub-restart` script (F-0122) does too much for situations where
the user simply wants to fire-and-forget a Hub launch:

- Kills existing Hub processes (pkill -x antigravity)
- Removes stale Singleton locks
- Waits up to 20 seconds for the Hub's language_server to report readiness
- Exits non-zero if the Hub doesn't become ready within the timeout

For common use cases — especially launching Hub from a sway keybinding or
startup script — the user just wants to launch the Hub and move on immediately.
The kill/cleanup/wait logic is unnecessary overhead and delay.

## Requirements

1. Create `workstation-image/scripts/hub-start` — a minimal script that ONLY
   launches the Antigravity Hub with no kill/cleanup/wait logic.
2. Auto-detect session environment: `SWAYSOCK`, `WAYLAND_DISPLAY`,
   `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS` (same pattern as hub-restart).
3. Launch Hub with flags: `--no-sandbox --ozone-platform=wayland --disable-gpu
   --disable-dev-shm-usage --user-data-dir=$HOME/.config/Antigravity-Hub`.
4. Unset `LD_LIBRARY_PATH` before launching (prevents EGL crash, same pattern
   used by VS Code in sway config).
5. Redirect Hub stdout/stderr to `~/logs/hub-launch.log`.
6. Use `setsid` + `disown` so the Hub fully detaches from the calling terminal.
7. Switch to workspace 1 after launching.
8. Print a one-line message and exit immediately (no waiting, no readiness
   checks).
9. Deploy to `~/.local/bin/hub-start` via `scripts/cloud-build-setup.sh`
   (same pattern as hub-restart).
10. Add boot tests to verify the script exists and is executable.

## Acceptance Criteria

- [x] `hub-start` script exists at `workstation-image/scripts/hub-start`
- [x] Script launches Hub and returns immediately (< 1 second)
- [x] Hub output redirected to `~/logs/hub-launch.log`
- [x] Hub detaches from terminal (setsid + disown)
- [x] LD_LIBRARY_PATH unset before Hub exec
- [x] Workspace 1 focused after launch
- [x] `cloud-build-setup.sh` deploys to `~/.local/bin/hub-start`
- [x] Boot tests verify presence, executable bit, and PATH discoverability

## Out of Scope

- Killing existing Hub processes (use hub-restart for that)
- Removing stale Singleton locks (use hub-restart for that)
- Readiness checks or waiting for the Hub
- Sway keybinding changes (existing `$mod+h` can be updated separately if needed)

## Dependencies

- F-0122 (hub-restart — established the pattern)
- F-0106 (Hub install — provides the binary at ~/.local/bin/antigravity-hub)

## Open Questions

- None
