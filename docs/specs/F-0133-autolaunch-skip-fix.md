# F-0133: Fix Autolaunch Idempotent Check — Count App Windows, Not PIDs

**Type:** Bug
**Priority:** P0 (critical)
**Status:** Done
**Requested by:** PO
**Date:** 2026-06-04

## Problem

The idempotent check in `workstation-image/boot/08-workspaces.sh` (lines 112-117)
counts ALL `"pid"` entries in the sway tree JSON and skips autolaunch if the count
exceeds 1. This is too aggressive — on the CRD session, background processes like
swaybar, Xwayland, and other compositor internals already produce PID entries in the
tree, causing the check to fire even when no user applications (VS Code, Chrome,
foot terminals) have been launched.

**Observed failure from journal:**
```
[08-workspaces] Windows already open (2 found) — skipping
```
The 2 PIDs were background processes (swaybar, etc.), not user application windows.

**Impact:** After every reboot, autolaunch skips and the user gets an empty desktop
with no apps launched. The user must manually start VS Code, Chrome, and terminals.

## Root Cause

The existing check uses `grep -o '"pid"' | wc -l` which counts every node in the
sway tree that has a PID — including swaybar, Xwayland server, and other non-window
containers. The sway tree always has at least 1-2 PID entries for background
processes even with zero application windows.

## Requirements

1. The idempotent check MUST count only actual application **windows** (containers
   with `app_id` set for Wayland apps, or `window_properties.class` set for X11 apps,
   and `type == "con"`), not raw PID entries.
2. The check MUST use `jq` or `python3` to parse the sway tree JSON properly instead
   of grepping for `"pid"`.
3. Threshold: skip autolaunch if ANY real app windows exist (count > 0).
4. Swaybar, Xwayland server processes, and other compositor background processes
   MUST NOT count as windows.
5. The fix MUST be backward compatible — all existing app launch behavior preserved.

## Acceptance Criteria

- [x] AC1: `08-workspaces.sh` idempotent check uses `python3` to parse sway tree JSON
  and counts only containers with `app_id` or `window_properties.class` set and
  `type == "con"`.
- [x] AC2: The old `grep -o '"pid"' | wc -l` check is completely removed.
- [x] AC3: On a fresh boot with no apps launched (but swaybar and Xwayland running),
  the check does NOT skip autolaunch.
- [x] AC4: On a boot with apps already launched (e.g., Chrome, VS Code), the check
  correctly detects them and skips autolaunch.
- [x] AC5: Boot test in `10-tests.sh` verifies the new check uses `app_id` /
  `window_properties` counting (not raw PID counting) via static grep.
- [x] AC6: Boot test in `10-tests.sh` verifies the old `grep -o '"pid"'` pattern is
  absent from `08-workspaces.sh`.

## Out of Scope

- Changing workspace assignments or app launch order
- Modifying the `count_windows_on_ws` helper (which already uses python3)
- Changes to the gnome-keyring or Xwayland blocks

## Dependencies

- F-0029 (original auto-launch 4 workspaces)
- F-0124 (Hub autostart removal — current script baseline)

## Open Questions

- None — fix is straightforward.
