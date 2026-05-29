# F-0040: Install Antigravity CLI and enable apt auto-upgrade

**Type:** Feature
**Priority:** P1 (important)
**Status:** Approved
**Requested by:** PO
**Date:** 2026-05-29

## Problem

The workstation needs to initialize the Antigravity CLI via its official curl installer, which sets up configuration in `~/.gemini/antigravity-cli/`. Additionally, the Antigravity apt package is not automatically upgraded between image rebuilds, so the workstation's installed version grows stale relative to available updates in the apt repository.

Antigravity is a single apt package with rolling 1.x releases (not "2.0" — that was a hallucination). The CLI and desktop app use the same `/usr/bin/antigravity` binary, invoked differently (CLI mode without flags, desktop mode via keybinding). The curl installer initializes the CLI config layer.

## Requirements

1. The system must install Antigravity CLI via official curl installer (`https://antigravity.google/cli/install.sh`) and re-run on every boot for updates
2. The system must enable apt auto-upgrade for the Antigravity package on every boot (`apt-get install -y --only-upgrade antigravity`)
3. The system must provide a sway keybinding `$mod+g` for CLI mode (invokes `/usr/bin/antigravity` without flags)
4. The system must provide a sway keybinding `$mod+n` for desktop app mode (same `/usr/bin/antigravity` binary)
5. The system must auto-launch Antigravity desktop on workspace 3 at boot
6. The system must persist Antigravity CLI config on the persistent disk (`$HOME/.gemini/antigravity-cli/`)
7. The system must test Antigravity CLI availability and binary presence in boot tests
8. The system must survive reboot and teardown+setup cycles

## Acceptance Criteria

- [ ] Antigravity CLI is installed via `curl -fsSL https://antigravity.google/cli/install.sh | bash`
- [ ] CLI init script runs idempotently on every boot (checks if already initialized, re-runs installer for updates)
- [ ] Antigravity CLI config persists at `~/.gemini/antigravity-cli/` (on persistent disk)
- [ ] `apt-get install -y --only-upgrade antigravity` runs on every boot to check for apt package updates
- [ ] Sway keybinding `$mod+g` launches Antigravity CLI (no flags: `/usr/bin/antigravity`)
- [ ] Sway keybinding `$mod+n` launches Antigravity desktop app (same binary, keybinding invocation mode)
- [ ] Workspace 3 autostart launches Antigravity desktop on boot (via `08-workspaces.sh`)
- [ ] `boot/10-tests.sh` includes tests for:
  - Antigravity binary at `/usr/bin/antigravity`
  - Antigravity CLI config dir at `~/.gemini/antigravity-cli/`
  - Sway config contains both `$mod+g` (CLI) and `$mod+n` (desktop) keybindings
- [ ] Antigravity CLI and desktop app both persist across reboot
- [ ] Fresh provisioning via `cloud-build-setup.sh` includes Antigravity CLI curl install and apt auto-upgrade boot script
- [ ] All boot scripts and sway config changes survive home-manager switch and swaymsg reload

## Out of Scope

- Configuration of Antigravity CLI authentication or project settings (handled separately by PO)
- Integration with Cloud Run deployment or CI/CD (PE handles)
- Testing on multiple GCP projects (PE handles multi-project validation)
- Removing legacy Gemini CLI (out of scope — separate feature if/when needed)

## Files Modified

| File | Change | Reason |
|------|--------|--------|
| `workstation-image/boot/07-apps.sh` | Add Antigravity CLI curl install (idempotent, runs every boot) | Initialize CLI and check for updates |
| `workstation-image/boot/06b-apt-upgrade.sh` (new) | Add `apt-get install -y --only-upgrade antigravity` | Auto-upgrade apt package on every boot |
| `workstation-image/configs/sway/config` | Ensure `$mod+g` launches CLI (`/usr/bin/antigravity`) and `$mod+n` launches desktop | CLI and desktop keybindings |
| `workstation-image/boot/08-workspaces.sh` | Workspace 3 launches `/usr/bin/antigravity` desktop mode | Auto-launch on boot |
| `workstation-image/boot/10-tests.sh` | Add tests for Antigravity binary at `/usr/bin/antigravity` and CLI config at `~/.gemini/` | Verify installation in boot test suite |
| `scripts/cloud-build-setup.sh` | Add Antigravity CLI curl install step | Fresh provisioning includes CLI |

## Dependencies

- F-0087 (Foot terminal starts in $HOME) — prior release, no blocking dependency
- Antigravity apt package availability in repository (rolling 1.x releases, no "2.0" package)
- Antigravity CLI official install script stable at https://antigravity.google/cli/install.sh

## Resolved Questions

1. **Antigravity 2.0 vs rolling 1.x**: Antigravity is not a "2.0" release. It's a single apt package with rolling 1.x releases (currently 1.22.2 installed, 1.23.2 candidate). No separate "2.0" package exists. The apt auto-updater delivers incremental updates.

2. **CLI vs Desktop binary**: Both CLI and desktop app use the same `/usr/bin/antigravity` binary. Different invocation modes are triggered by context (CLI mode when run from terminal without keybinding, desktop mode via sway keybinding with Wayland flags).

3. **CLI installer behavior**: The curl installer at `https://antigravity.google/cli/install.sh` initializes `~/.gemini/antigravity-cli/` config directory. Re-running is idempotent and safe on every boot for checking updates.

4. **Workspace 3 timeout**: 30s timeout retained (Antigravity startup is consistent).

## Implementation Notes

- **Idempotency**: Both curl installer and apt upgrade must be idempotent (safe to run multiple times per boot)
- **Persistence**: Antigravity CLI config (`~/.gemini/antigravity-cli/`) MUST be on persistent disk (it is by default, lives in `$HOME`)
- **Same binary, different invocations**: `$mod+g` and `$mod+n` both launch `/usr/bin/antigravity` — no separate CLI binary exists
- **Apt upgrade safety**: `apt-get install -y --only-upgrade antigravity` is a safe operation that checks for updates and applies them if available
- **Test coverage**: Every keybinding and binary must have a corresponding test in `10-tests.sh` (per CLAUDE.md)
- **No live-only edits**: All changes must be committed to repo and verified via setup script (per CLAUDE.md zero-tolerance rule)
