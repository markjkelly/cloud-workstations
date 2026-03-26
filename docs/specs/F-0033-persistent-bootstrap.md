# F-0033: Persistent Disk Bootstrap Architecture

**Type:** Refactor
**Priority:** P0 (critical)
**Status:** Approved
**Requested by:** PO (Your Name)
**Date:** 2026-03-20

## Problem

The current Docker image is ~3.3GB and includes GNOME, Antigravity, Google Chrome, TigerVNC, noVNC, and all startup scripts baked in. Every change -- fonts, configs, services, app updates -- requires a full Docker image rebuild via Cloud Build, which is slow, expensive, and fragile. The startup scripts (`200_persist-nix.sh`, `300_setup-sway-desktop.sh`) are embedded in the Docker image at `/etc/workstation-startup.d/`, meaning any change to boot-time logic also triggers a rebuild.

This architecture is unsustainable as the project moves into Milestone 4 (auto-start, daily readiness, fonts, ZSH, Starship) where rapid iteration on setup scripts is essential. Future features (F-0028 through F-0032) should be deployable by editing files on the persistent disk -- not by rebuilding and re-deploying a multi-GB Docker image.

## Requirements

### R1: Master setup script on persistent disk

Create `~/boot/setup.sh` on the persistent disk as the single entry point for all workstation setup logic. This script consolidates and replaces all logic currently in:
- `200_persist-nix.sh` (Nix bind mount, nvidia PATH/LD_LIBRARY_PATH)
- `300_setup-sway-desktop.sh` (nvidia ldconfig, Sway + wayvnc systemd services, TigerVNC disable)

The master script must:
- Be idempotent (safe to run multiple times)
- Log its actions to stdout for debugging via `journalctl`
- Source modular sub-scripts from `~/boot/` in numbered order
- Exit 0 on success so systemd considers the boot healthy

### R2: Minimal bootstrap script in Docker image

Create `000_bootstrap.sh` in the Docker image at `/etc/workstation-startup.d/`. This is the ONLY custom startup script in the Docker image. It must be approximately 5 lines:
1. Check if `~/boot/setup.sh` exists on the persistent disk
2. If it exists, execute it with `bash ~/boot/setup.sh`
3. If it does not exist, log a warning and exit gracefully

This script is the bridge between the ephemeral Docker container and the persistent disk's setup logic.

### R3: Lean Docker image (one final rebuild)

Rebuild the Docker image ONE FINAL TIME containing only:
- Base Cloud Workstation image (`us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base`)
- systemd (required for service management)
- TigerVNC + noVNC (required for VNC pipeline -- noVNC proxies port 80 to 5901)
- `000_bootstrap.sh` (from R2)
- Existing assets: `100_persist-machine-id.sh`, `100_add-xstartup.sh`, systemd service files for TigerVNC/noVNC, entrypoint script

Remove from Docker image:
- GNOME desktop (entire `ubuntu-desktop-minimal` + gnome-* packages)
- Google Antigravity APT install (already installed via Nix on persistent disk)
- Google Chrome APT install (already installed via Nix on persistent disk)
- `200_persist-nix.sh` (logic moves to `~/boot/01-nix.sh`)
- `300_setup-sway-desktop.sh` (logic moves to `~/boot/03-sway.sh`)

### R4: Modular sub-scripts on persistent disk

Migrate existing startup script logic into modular sub-scripts under `~/boot/`:

| Script | Purpose | Source |
|--------|---------|--------|
| `~/boot/setup.sh` | Master orchestrator, sources all numbered scripts | New |
| `~/boot/01-nix.sh` | Restore /nix bind mount from persistent disk | From `200_persist-nix.sh` |
| `~/boot/02-nvidia.sh` | nvidia ldconfig + PATH + LD_LIBRARY_PATH setup | From `200_persist-nix.sh` and `300_setup-sway-desktop.sh` |
| `~/boot/03-sway.sh` | Create sway-desktop + wayvnc systemd services, disable TigerVNC | From `300_setup-sway-desktop.sh` |

Future scripts (added without Docker rebuild):
| `~/boot/04-fonts.sh` | Font installation (F-0030) |
| `~/boot/05-shell.sh` | ZSH + plugins (F-0031) |
| `~/boot/06-prompt.sh` | Starship + foot config (F-0032) |
| `~/boot/07-apps.sh` | App updates on boot (F-0028) |
| `~/boot/08-workspaces.sh` | Auto-launch workspaces (F-0029) |

### R5: End-to-end boot verification

After the migration, verify the workstation boots correctly with the new lean image + persistent disk bootstrap:
- Nix bind mount restored
- nvidia GPU accessible (nvidia-smi works)
- Sway starts and wayvnc serves on port 5901
- noVNC proxies port 80 to 5901 correctly
- All Nix-installed apps available (Chrome, Antigravity, VSCode, etc.)
- No regressions from the current setup

## Acceptance Criteria

- [ ] AC1: Docker image is under 1GB (down from ~3.3GB)
- [ ] AC2: `~/boot/setup.sh` runs successfully on boot and sets up the full environment (Nix, GPU, Sway, wayvnc)
- [ ] AC3: No Docker rebuild is needed for font installs, config changes, or app additions -- all future changes are persistent disk edits
- [ ] AC4: All existing functionality is preserved: Sway desktop, wayvnc on 5901, noVNC on port 80, Nix package manager, GPU acceleration, Antigravity
- [ ] AC5: New features F-0028 through F-0032 are deployable by adding/editing scripts in `~/boot/` on the persistent disk only

## Out of Scope

- Migrating TigerVNC/noVNC to persistent disk (they must remain in Docker image for the VNC pipeline to work before persistent disk mounts)
- Removing `100_persist-machine-id.sh` or `100_add-xstartup.sh` from Docker image (these are low-level system scripts that belong in the image)
- Automating the `~/boot/` script deployment (manual SCP/SSH or direct edit for now)
- Multi-workstation support (single workstation: `dev-workstation`)

## Dependencies

- F-0025: Sway auto-start on boot (provides the startup script logic being migrated)
- F-0026: Docker image rebuild with startup scripts (provides the current Docker image being slimmed down)

## Open Questions

- Should `100_add-xstartup.sh` be removed from the Docker image since we no longer use GNOME/TigerVNC for the desktop? It sets up `.vnc/xstartup` for GNOME, which is unused with Sway. Keeping it is harmless but adds dead code.
- Should we keep TigerVNC in the Docker image at all, given that wayvnc replaces it? TigerVNC is currently disabled by `03-sway.sh`, but its packages still consume image space. However, noVNC depends on the VNC pipeline being available early in boot.
