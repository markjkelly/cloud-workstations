# F-0137: Automatic CRD Resolution Setup

**Type:** Feature
**Priority:** P1 (important)
**Status:** In Progress
**Requested by:** PO
**Date:** 2026-06-04

## Problem

Currently, the virtual display resolution of the Cloud Workstation accessed via Chrome Remote Desktop (CRD) defaults to a low/arbitrary resolution on initial boot. The user must manually run `crd-resize 2560 1440` to change the nested Sway desktop output and virtual X11 resolution to a standard high-definition resolution of 2560x1440. Automatically configuring this on boot provides a seamless out-of-the-box desktop experience.

## Requirements

1. Once Sway is detected as ready during the autolaunch sequence in `08-workspaces.sh`, the system must check if Chrome Remote Desktop is enabled or active.
2. If CRD is enabled or active, the system must automatically execute `crd-resize 2560 1440`.
3. The execution must run specifically as user `user`, invoking `/home/user/.local/bin/crd-resize 2560 1440`.
4. Outputs (stdout and stderr) of the resize command must be redirected to `/home/user/logs/crd-resize-boot.log` to track execution and help debug any startup issues.
5. The implementation must check for the presence and executability of `/home/user/.local/bin/crd-resize` before running it to avoid boot-time failures on minimal profiles or configurations where the tool is missing.

## Acceptance Criteria

- [ ] `08-workspaces.sh` contains the check for Chrome Remote Desktop active/enabled state.
- [ ] `08-workspaces.sh` contains the execution of `/home/user/.local/bin/crd-resize 2560 1440` redirected to `/home/user/logs/crd-resize-boot.log`.
- [ ] The command runs as user `user` with correct PATH environment variable pointing to the user's nix-profile and standard system binaries.
- [ ] File existence and executability of `/home/user/.local/bin/crd-resize` is verified before execution.
- [ ] Boot test suite `10-tests.sh` contains tests verifying that the auto-resize logic is correctly set up inside `08-workspaces.sh`.
- [ ] The modified boot scripts verify successfully with `bash -n`.

## Out of Scope

- Custom/user-configurable auto-resolutions on boot (hardcoded to 2560x1440 is sufficient for now).
- Automatic resizing in headless Sway sessions (only applies to Chrome Remote Desktop).

## Dependencies

- F-0033 (Persistent bootstrap architecture)
- F-0009 (Chrome Remote Desktop setup)
- F-0112 (Autostart/Autolaunch workspace config)

## Open Questions

- None.
