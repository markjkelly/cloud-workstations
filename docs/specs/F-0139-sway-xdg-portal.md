# F-0139: Fix XDG Desktop Portal failure (Sway XDG Desktop Portal Integration)

**Type:** Bug
**Priority:** P1 (important)
**Status:** In Progress
**Requested by:** PO
**Date:** 2026-06-08

## Problem

On system boot, `xdg-desktop-portal-gtk` and `xdg-desktop-portal` services fail or timeout. This happens because:
1. No Wayland-native portal backend (`xdg-desktop-portal-wlr`) is installed.
2. There is no `portals.conf` configuration defining the preferred portal backends.
3. The systemd user services timeout waiting for the GTK backend, which crashes because `DISPLAY` and `WAYLAND_DISPLAY` are not exported to systemd.

This leads to a degraded systemd session and broken file pickers or screen sharing in Chrome/Electron apps.

## Requirements

1. Install `xdg-desktop-portal-wlr` package.
2. Configure `~/.config/xdg-desktop-portal/portals.conf` to set preferred portals to `wlr` and `gtk`.
3. Export `WAYLAND_DISPLAY`, `DISPLAY`, and `XDG_CURRENT_DESKTOP=sway` from Sway config to systemd using `dbus-update-activation-environment`.
4. Ensure configuration is persistent across reboots, clean installs (Cloud Build), and home-manager updates.

## Acceptance Criteria

- [ ] `xdg-desktop-portal-wlr` binary is on PATH.
- [ ] `~/.config/xdg-desktop-portal/portals.conf` exists and contains `default=wlr;gtk`.
- [ ] Sway config (`workstation-image/configs/sway/config` and active `~/.config/sway/config`) includes `exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP=sway`.
- [ ] `xdg-desktop-portal.service` is active/running in systemd user session.
- [ ] `xdg-desktop-portal-gtk.service` is active/running in systemd user session.
- [ ] Integration tests verify portal setup.

## Out of Scope

- Setting up portals for other desktop environments besides Sway.
- Debugging general GTK application styling issues.

## Dependencies

- None.

## Open Questions

- None.
