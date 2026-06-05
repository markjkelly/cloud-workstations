# F-0122: hub-restart — manual Hub-relaunch utility

**Type:** Enhancement
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-05-29

## Problem

At cold boot the Antigravity Hub's bundled `language_server` sometimes never starts,
leaving workspace 1 blank (root-cause diagnosis ongoing; see F-0117–F-0121). Until
the cold-boot race is fixed the PO needs a reliable one-command workaround to bring
the Hub up without a full reboot.

A script `hub-restart` was created and live-tested directly on the workstation. It
works: kills any running/stuck Hub, clears the Electron singleton lock, relaunches
the Hub from the user's own Wayland/D-Bus session (the warm path that always
succeeds), focuses workspace 1, and polls until `language_server` reports "Port
changed". The script lives at `~/.local/bin/hub-restart` and was confirmed to bring
the Hub up with `language_server` listening.

The problem is that `~/.local/bin/hub-restart` was created live (not via the repo),
so it will be lost on a fresh-project setup (new persistent disk). This feature
persists it.

## Requirements

1. The script at `~/.local/bin/hub-restart` must be captured verbatim into the repo
   at `workstation-image/scripts/hub-restart` (matching where `snippet-picker`,
   `claude-tmux`, and `tmux-debug` live — the existing convention for user-bin
   scripts shipped via `cloud-build-setup.sh`).
2. `scripts/cloud-build-setup.sh` must install `hub-restart` to
   `~/.local/bin/hub-restart` with `chmod +x`, unconditionally (Hub is always
   installed; `hub-restart` is always useful), placed alongside the other desktop
   utility deploys (near the `sway-status` / `snippet-picker` block).
3. The live `~/.local/bin/hub-restart` must be identical (byte-for-byte) to the
   repo copy — reconciled if they ever diverge.
4. `workstation-image/boot/10-tests.sh` must include a static test that verifies
   `~/.local/bin/hub-restart` exists, is executable, and is on PATH.
5. `docs/STARTUP_SCRIPTS.md` must document `hub-restart` in the user tools table.

## Script Behaviour (verbatim — do NOT change)

The tested script (`/home/user/.local/bin/hub-restart`) does the following:

1. Auto-detects session env (`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`,
   `DBUS_SESSION_BUS_ADDRESS`, `SWAYSOCK`) with safe defaults — works whether run
   inside or outside a live Sway session.
2. Kills any running `antigravity` process (SIGTERM then SIGKILL after 1 s).
3. Removes `~/.config/Antigravity-Hub/Singleton*` lock files.
4. Launches the Hub via `setsid … & disown` with the necessary Electron flags
   (`--no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage
   --user-data-dir=~/.config/Antigravity-Hub`), redirecting stdout+stderr to
   `~/logs/hub-launch.log` in append mode with a timestamped marker.
5. Switches Sway to workspace 1.
6. Polls `~/logs/hub-launch.log` every 1 s (up to 20 s) for a "Port changed" line
   logged after the launch marker, printing `UP ✓` with the port and window count
   on success, or a warning with the log path on timeout.

## Acceptance Criteria

- [ ] `workstation-image/scripts/hub-restart` exists in the repo and is byte-identical
      to the finalized live script.
- [ ] `scripts/cloud-build-setup.sh` installs it: `cat … | ws_pipe "… cat > ~/.local/bin/hub-restart && chmod +x …"`.
- [ ] `workstation-image/boot/10-tests.sh` has a test: file exists, is executable, is on PATH.
- [ ] `diff` of repo copy vs live `~/.local/bin/hub-restart` is empty.
- [ ] `bash -n workstation-image/scripts/hub-restart` exits 0 (no syntax errors).
- [ ] `docs/STARTUP_SCRIPTS.md` documents the tool.

## Out of Scope

- Fixing the cold-boot `language_server` race condition (ongoing in F-0117–F-0121).
- Any behavioural changes to the script itself.

## Dependencies

- F-0117 (Hub readiness retry), F-0120 (LS shim), F-0121 (session gate) — context
  only; no code dependency.

## Open Questions

- None.
