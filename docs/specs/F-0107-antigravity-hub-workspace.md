# F-0107: Antigravity 2.0 Hub as Workspace 5

**Type:** Feature
**Priority:** P1 (important)
**Status:** In Progress
**Requested by:** PO
**Date:** 2026-05-29

## Problem

Antigravity 2.0 Desktop App (Hub) is installed but not auto-launching on boot. Users must manually start it via sway keybinding. Adding Hub as workspace 5 with auto-launch ensures all primary development tools (Chrome, Antigravity IDE, terminals, Hub) are ready at boot.

## Requirements

1. Hub must auto-launch in workspace 5 on boot, with 30s timeout (longer initialization than terminals)
2. `$mod+h` keybinding must switch to workspace 5 (not launch Hub directly)
3. Hub launch must guard against missing binary — skip if `~/.local/bin/antigravity-hub` does not exist
4. Correct Electron flags must be used: `--no-sandbox --ozone-platform=wayland --use-gl=swiftshader --disable-dev-shm-usage`
   - **NOT `--disable-gpu`** — causes blank window; use `--use-gl=swiftshader` instead
5. Fix existing ws2 Antigravity IDE to also use `--use-gl=swiftshader` instead of `--disable-gpu`
6. All sway config sources (repo, home-manager, cloud-build-setup.sh) must stay in sync (three-places rule)

## Acceptance Criteria

- [ ] `workstation-image/boot/08-workspaces.sh` updated: ws5 Hub launch after ws4 terminals, header updated to "5 workspaces"
- [ ] `workstation-image/boot/08-workspaces.sh` ws2 Antigravity IDE: `--use-gl=swiftshader` replaces `--disable-gpu`
- [ ] `workstation-image/configs/sway/config`: `$mod+h` keybinding removed from line 110 (exec Hub), leaving only line 179 (workspace number 5)
- [ ] No duplicate `$mod+h` bindings in sway config (checked via grep)
- [ ] `~/.config/home-manager/sway-config`: same sway config fix applied (if file exists on live workstations)
- [ ] `workstation-image/boot/10-tests.sh`: test added asserting `$mod+h` in sway config maps ONLY to `workspace number 5`
- [ ] Boot test suite runs without regression (existing tests still pass)
- [ ] Reboot + `ws.sh teardown && ws.sh setup` + fresh-project setup all verify Hub launches in ws5 and `$mod+h` switches to ws5 (manual PO verification pending)

## Out of Scope

- Windsurf or other new apps
- Additional workspace modifications beyond ws5 Hub + ws2 GPU flag fix
- Changes to any boot scripts other than 08-workspaces.sh and 10-tests.sh

## Dependencies

- F-0106 (Antigravity Hub installed at `~/.local/bin/antigravity-hub`)
- F-0087 (Sway config with keybindings)
- F-0029 (Auto-launch workspace architecture)

## Open Questions

- None
