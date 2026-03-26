# F-0011: Migrate All App Installations to Nix Package Manager

**Type:** Feature
**Priority:** P0 (critical)
**Status:** Draft
**Requested by:** PO (Your Name)
**Date:** 2026-03-20

## Problem

Apps installed via apt in the Docker image live on the ephemeral container filesystem and reset on reboot. The PO wants all app installations managed via Nix package manager on the persistent HOME disk so updates and new installs survive reboots.

## Requirements

### R1: Reboot Workstation with New Image

After the Docker image rebuild (which includes the 200_persist-nix.sh startup script), stop and restart the workstation so the new image is picked up. Verify:
- /nix symlink is restored automatically on boot
- nvidia profile script is restored on boot
- TigerVNC and noVNC are running

### R2: Install Core Tools via Nix

Install the following via `nix-env -iA nixpkgs.<pkg>` on the persistent disk:
- vim, tmux, htop, git, curl, wget
- Any other common dev tools the workstation needs

### R3: Install Antigravity Persistently

Google Antigravity is a proprietary Electron app from Google's APT repo — it is NOT in nixpkgs. Strategy:
- Keep the APT-installed copy on the persistent disk at ~/.antigravity (already done)
- The desktop shortcut at ~/.local/share/applications/ points to the persistent copy
- The update-antigravity script at ~/.local/bin/ handles updates
- This is the correct approach for proprietary apps not in nixpkgs

### R4: Install Google Chrome via Nix

Chrome is available in nixpkgs as `nixpkgs.google-chrome`. Install via Nix so it persists. Create a desktop shortcut with the required flags.

### R5: Verify All Persistent After Reboot

Stop and restart the workstation to verify:
- Nix and all nix-installed packages work
- Antigravity launches from persistent copy
- Chrome launches
- GPU (nvidia-smi) works
- noVNC desktop is accessible

## Acceptance Criteria

- [ ] Workstation rebooted with new image, startup scripts work
- [ ] Core dev tools installed via Nix
- [ ] Antigravity runs from persistent disk
- [ ] Chrome installed via Nix with correct flags
- [ ] All apps survive a stop/start cycle
