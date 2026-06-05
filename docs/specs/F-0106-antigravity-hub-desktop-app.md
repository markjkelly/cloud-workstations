# F-0106: Antigravity 2.0 Desktop App (Hub)

**Type:** Feature  
**Priority:** P1 (important)  
**Status:** Done
**Requested by:** PO  
**Date:** 2026-05-29

## Problem

Antigravity 2.0 comes with a new **Desktop App** (codenamed "antigravity-hub"), a separate product from the existing Antigravity IDE (apt package) and CLI. The desktop app provides a graphical launcher and project hub interface.

The desktop app is not included in the standard apt package — it must be downloaded and extracted separately. Users currently have no way to access it on the cloud workstation.

## Requirements

1. The system must download the Antigravity 2.0 Desktop App (antigravity-hub) from the Google Cloud Storage bucket
2. The system must extract the app to a persistent disk location (`~/.local/share/antigravity-hub/`)
3. The system must create a launcher symlink (`~/.local/bin/antigravity-hub`) for easy invocation
4. The system must support launching the app via a sway keybinding (`$mod+h`)
5. The system must survive reboots, teardown+setup, and fresh-project deployments

## Acceptance Criteria

- [ ] Download URL is correct and returns HTTP 200 (version 2.0.10)
- [ ] `07-apps.sh` idempotently downloads, extracts, and symlinks on first boot
- [ ] Symlink at `~/.local/bin/antigravity-hub` points to the correct binary inside the extracted directory
- [ ] `$mod+h` keybinding is present in both `workstation-image/configs/sway/config` and `~/.config/home-manager/sway-config`
- [ ] Sway keybinding uses correct Electron launch flags (`--no-sandbox`, `--ozone-platform=wayland`, etc.)
- [ ] Boot test added to `10-tests.sh` verifying directory and symlink existence
- [ ] Boot test added to `10-tests.sh` verifying keybinding in sway config
- [ ] App survives reboot, `ws.sh teardown && ws.sh setup`, and fresh project setup
- [ ] No regressions: existing Antigravity IDE (`$mod+n`) and CLI (`$mod+g`) still work

## Out of Scope

- Upstream changes to the download URL or app name
- Distribution channels other than direct download from GCS
- Alternative installation methods (e.g., snap, flatpak)
- Deep configuration of the desktop app itself (launch parameters beyond Wayland flags)

## Dependencies

- F-0087 (foot terminal keybinding standardization — ensures keybinding style consistency)
- F-0088 through F-0092 (Antigravity 2.0 + CLI — existing desktop app keybindings and architecture)

## Open Questions

- What is the exact binary name inside the tar.gz? Likely `antigravity-hub`, `Antigravity`, or the root binary of an Electron app structure. Will need to inspect the archive structure (may require downloading if not documented).
- Will future versions require updating the hardcoded URL? (Yes — comment in the code noting this.)
