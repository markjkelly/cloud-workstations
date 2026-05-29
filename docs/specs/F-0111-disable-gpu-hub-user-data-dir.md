# F-0111: Disable GPU and fix Hub user-data-dir for GPU-less workstation

**Type:** Bug Fix
**Priority:** P0 (critical)
**Status:** Done
**Requested by:** PO
**Date:** 2026-05-29

## Problem

The workstation has NO GPU. The Antigravity Hub (`antigravity-hub`, ws5) launches with `--use-gl=swiftshader` but this flag still spins up a GPU child process which immediately crashes in a tight loop:

```
drmGetDevices2() has not found any devices: No such file or directory (2)
gl_factory.cc: Requested GL implementation (gl=none,angle=none) not found
viz_main_impl.cc: Exiting GPU process due to errors during initialization
```

The GPU process restarts repeatedly, consuming CPU and causing the Hub's renderer process to never initialize, so the ws5 window is blank.

A second distinct bug makes the Hub window not appear at all: `antigravity-hub` defaults to `~/.config/Antigravity` as its userData directory — the same directory used by the IDE binary at `/usr/bin/antigravity` on ws2. Electron's `ProcessSingleton` (SingletonLock/SingletonSocket) only allows one window per userData directory. The IDE wins the lock (it boots first), so the Hub never opens its own window. The Hub process runs silently with no visible window on ws5.

## Requirements

1. Replace `--use-gl=swiftshader` with `--disable-gpu` for the ws5 Hub launch in `08-workspaces.sh` to prevent the GPU child process from starting entirely.
2. Replace `--use-gl=swiftshader` with `--disable-gpu` for the ws2 IDE launch in `08-workspaces.sh` for consistency and correctness on a GPU-less host.
3. Add `--user-data-dir=/home/user/.config/Antigravity-Hub` to the ws5 Hub launch only. The IDE (ws2) retains its default `~/.config/Antigravity` userData dir (where its auth tokens are stored).
4. The ws5 Hub must open a non-blank window within the existing 90s timeout after these changes.
5. Keep `--no-sandbox`, `--ozone-platform=wayland`, and `--disable-dev-shm-usage` unchanged — they are still needed.
6. Add `--disable-gpu` to Chrome (ws1) launch for consistency on a GPU-less host. Chrome currently works, but this is safer and removes the hidden GPU process from Chrome too.
7. All three-places-rule files must be updated: repo script, `~/boot/` live copy, `cloud-build-setup.sh` verified (deploys whole boot dir via tar — no embedded change needed).

## Acceptance Criteria

- [ ] `08-workspaces.sh` Hub launch uses `--disable-gpu` (not `--use-gl=swiftshader`)
- [ ] `08-workspaces.sh` Hub launch includes `--user-data-dir=/home/user/.config/Antigravity-Hub`
- [ ] `08-workspaces.sh` IDE launch uses `--disable-gpu` (not `--use-gl=swiftshader`)
- [ ] `bash -n workstation-image/boot/08-workspaces.sh` passes
- [ ] Live test: Hub window appears on ws5 within 15s with new flags (confirmed before commit)
- [ ] Live test: No "Exiting GPU process due to errors during initialization" in Hub log with `--disable-gpu` (confirmed before commit)
- [ ] `~/boot/08-workspaces.sh` updated to match repo (three-places rule)
- [ ] `10-tests.sh` updated: grepping for `--disable-gpu` on Hub line; grepping for `--user-data-dir=/home/user/.config/Antigravity-Hub`; old `--use-gl=swiftshader` test removed/updated
- [ ] `docs/STARTUP_SCRIPTS.md` updated to reflect the GPU flag change

## Out of Scope

- Adding GPU hardware to the workstation
- Changing the Antigravity userData directory for the IDE (ws2)
- Changing Hub auth state or user profile

## Dependencies

- F-0110 (Hub ws5 auth-friendly launch — already merged)
- F-0107 (Hub workspace auto-launch — already merged)

## Open Questions

None — live validation completed before commit.
