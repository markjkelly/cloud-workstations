# F-0136: Install Antigravity IDE v2

**Type:** Feature
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-06-04

## Problem

The Antigravity IDE v1 (apt package at `/usr/bin/antigravity`) was removed in F-0116
because it shared `app_id="antigravity"` with the Hub, causing sway placement collisions.
The new Antigravity IDE v2 is a standalone Electron app distributed as a tarball with a
distinct `app_id="antigravity-ide"`, eliminating the collision. The workstation needs the
IDE v2 installed as the primary development environment on workspace 1.

## Requirements

1. The system must download and install Antigravity IDE v2 from the official URL to
   `~/.local/share/antigravity-ide/`.
2. The system must create a symlink at `~/.local/bin/antigravity-ide` pointing to the
   binary inside the install directory.
3. The system must create a `.desktop` file at
   `~/.local/share/applications/antigravity-ide.desktop`.
4. The system must add a sway `for_window` rule for `app_id="antigravity-ide"` to
   assign it to workspace 1.
5. The system must move the Hub's sway `for_window` rule from workspace 1 to workspace 5.
6. The system must auto-launch the IDE v2 on workspace 1 at boot with Electron flags
   (`--ozone-platform=wayland --disable-gpu --disable-dev-shm-usage`).
7. The system must rework the workspace layout:
   - ws1 = Antigravity IDE v2 (auto-launch, focused after boot)
   - ws2 = VS Code
   - ws3 = foot terminal
   - ws4 = Chrome
   - ws5 = Hub (manual start via hub-restart)
8. The system must remove the F-0125 orphaned IDE cleanup block from `07-apps.sh`.
9. Installation must be one-time only (download only if not already present).

## Acceptance Criteria

- [x] `~/.local/share/antigravity-ide/` directory exists with the IDE binary
- [x] `antigravity-ide` binary is on PATH (via `~/.local/bin/antigravity-ide` symlink)
- [x] `.desktop` file exists at `~/.local/share/applications/antigravity-ide.desktop`
- [x] Sway config has `for_window [app_id="antigravity-ide"]` rule for workspace 1
- [x] Sway config has Hub rule (`for_window [app_id="antigravity"]`) pointing to workspace 5
- [x] `08-workspaces.sh` launches IDE v2 on ws1 with correct Electron flags
- [x] The old F-0125 cleanup block is NOT present in `07-apps.sh`
- [x] Boot tests cover all of the above

## Out of Scope

- Keybinding for launching IDE v2 (not requested)
- Auto-update mechanism for IDE v2 (one-time install like Hub)
- IDE v2 extension or settings management

## Dependencies

- F-0116 (IDE v1 removal — completed)
- F-0124 (Hub autostart removal — completed)
- F-0125 (IDE orphan cleanup — to be removed by this feature)

## Open Questions

- None — all design decisions resolved by PO.
