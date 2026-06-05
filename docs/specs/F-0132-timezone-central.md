# F-0132: Change Timezone from Pacific to US Central

**Type:** Enhancement
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-06-04

## Problem

The Cloud Workstation timezone is currently set to Pacific Time (`America/Los_Angeles`). The PO has relocated to the US Central timezone and all system clocks, shell sessions, status bar, and log timestamps should reflect `America/Chicago` (US Central Time) instead.

The timezone is configured in multiple locations (established by F-0069):
1. `sway-desktop.service` — `Environment=TZ=America/Los_Angeles` in `03-sway.sh`
2. `.zshrc` template — `export TZ="America/Los_Angeles"` in `05-shell.sh`
3. `sway-status` script — `export TZ="America/Los_Angeles"` at top of script
4. `cloud-build-setup.sh` — `export TZ="America/Los_Angeles"` in the `initContent` block for home.nix generation
5. `10-tests.sh` — `TZ=America/Los_Angeles` used in date headers and summary line; `check_grep` validates timezone in zshrc source

All five locations must be updated to `America/Chicago` for consistency.

## Requirements

1. The system must set `TZ=America/Chicago` in the `sway-desktop.service` systemd unit so all sway child processes inherit Central Time
2. The system must export `TZ="America/Chicago"` in the `.zshrc` template so interactive shell sessions display Central Time
3. The system must export `TZ="America/Chicago"` in the `sway-status` script so the swaybar clock shows Central Time
4. The `cloud-build-setup.sh` must generate `export TZ="America/Chicago"` in the home.nix `initContent` so fresh setups use Central Time
5. The `10-tests.sh` boot test script must use `TZ=America/Chicago` in its date headers and summary line
6. The `10-tests.sh` timezone check must validate `America/Chicago` instead of `America/Los_Angeles`

## Acceptance Criteria

- [ ] AC1: `workstation-image/boot/03-sway.sh` contains `Environment=TZ=America/Chicago`
- [ ] AC2: `workstation-image/boot/05-shell.sh` contains `export TZ="America/Chicago"`
- [ ] AC3: `workstation-image/configs/swaybar/sway-status` contains `export TZ="America/Chicago"`
- [ ] AC4: `scripts/cloud-build-setup.sh` contains `export TZ="America/Chicago"` in the `initContent` block
- [ ] AC5: `workstation-image/boot/10-tests.sh` uses `TZ=America/Chicago` in all date formatting
- [ ] AC6: `workstation-image/boot/10-tests.sh` `check_grep` validates `America/Chicago` in zshrc source
- [ ] AC7: All changes persist across reboot, teardown+setup, and fresh project setup

## Out of Scope

- Changing the GCP Cloud Scheduler timezone (separate configuration in GCP)
- Changing the system-level `/etc/timezone` (boot scripts use `TZ` env var approach)
- Updating historical documentation references in specs/progress/release notes (those are historical records)

## Dependencies

- F-0069 (original timezone implementation — this feature modifies the same files)

## Open Questions

- None — straightforward find-and-replace across known locations
