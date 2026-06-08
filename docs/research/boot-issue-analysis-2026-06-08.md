# Boot Issue Analysis — 2026-06-08 Reboot

**Boot time:** 08:08 CDT → tests completed 08:10 CDT  
**Test results:** 190 total | 188 PASS | 0 FAIL | 1 WARN | 1 SKIP

---

## Issue 1: `.env` missing (WARN)
- **Root cause:** `~/.env` is opt-in for secrets. Sourced by `05-shell.sh` and `06a-tailscale.sh` if present.
- **Impact:** None (expected if no secrets configured).
- **Action:** None.

## Issue 2: Tailscale not configured (SKIP)
- **Root cause:** No `TAILSCALE_AUTHKEY` in `~/.env`.
- **Impact:** None (opt-in VPN).
- **Action:** None.

## Issue 3: `ws-app-updates.service` still running at test time (SKIP)
- **Root cause:** Asynchronous service start; tests ran before it finished. Completed successfully ~2 min later.
- **Impact:** None.
- **Action:** None.

## Issue 4: `xdg-desktop-portal-gtk` + `xdg-desktop-portal` failure (Failed/Timeout)
- **Root cause:** No Wayland portal backend (`xdg-desktop-portal-wlr` missing) and no `portals.conf` config. Services timeout waiting for GTK backend which crashes because no DISPLAY/WAYLAND_DISPLAY is exported to systemd.
- **Impact:** Broken file picker and screen sharing in Chrome/Electron apps. Systemd session is degraded.
- **Action:** Install `xdg-desktop-portal-wlr`, configure `portals.conf`, and export variables using `dbus-update-activation-environment` in Sway config.

## Issue 5: Chrome video capture bind errors
- **Root cause:** Headless container with no camera hardware.
- **Impact:** None (cosmetic logs only).
- **Action:** None.

## Issue 6: Swaybar tray icon errors (Get IconThemePath/IconName failed)
- **Root cause:** Antigravity Hub Electron app registers as SNI tray icon but has no `.desktop` file matching its app name and icon is not extracted on disk.
- **Impact:** Tray icon is blank/missing; cosmetic logs.
- **Action:** Extract `icon.png` from `app.asar` and deploy a matching `antigravity.desktop` file.
