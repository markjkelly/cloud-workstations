# F-0140: Fix Antigravity Hub tray icon/desktop file

**Type:** Bug
**Priority:** P1 (important)
**Status:** In Progress
**Requested by:** PO
**Date:** 2026-06-08

## Problem

The Antigravity Hub Electron application registers as a StatusNotifierItem (SNI) tray icon, but its tray icon is blank or missing, and there are warning logs in swaybar. This happens because:
1. The app does not have a registered `.desktop` file matching its application name.
2. The application's icon is not extracted/available on the disk at a path swaybar/system can resolve.

This causes a degraded user experience (missing/blank icon in swaybar) and cosmetic warning logs.

## Requirements

1. Extract the `assets/icon.png` from the Antigravity Hub `app.asar` file to `$HUB_INSTALL_DIR/icon.png` during boot setup (specifically `07-apps.sh`).
2. Deploy a desktop entry file at `~/.local/share/applications/antigravity.desktop` containing the correct path to the extracted icon, app execution command, and other standard desktop fields.
3. Verify the desktop file and icon path exist, and that swaybar/tray displays or logs no missing icon errors for it.

## Acceptance Criteria

- [ ] `/home/user/.local/share/applications/antigravity.desktop` exists and contains standard fields including the correct Icon path.
- [ ] `/home/user/.local/share/antigravity-hub/icon.png` is successfully extracted from `app.asar`.
- [ ] Integration tests verify the existence of the icon and desktop files.

## Out of Scope

- Fixing upstream SNI tray support in Electron or Swaybar itself.

## Dependencies

- F-0106 (Antigravity Hub desktop app)

## Open Questions

- None.
