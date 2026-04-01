# F-0038: Milestone 12 — AI IDEs, CLI Tools, and Timezone Fix

**Type:** Enhancement
**Priority:** P1 (important)
**Status:** Approved
**Requested by:** PO
**Date:** 2026-03-31

## Problem

The Cloud Workstation needs additional AI-powered IDEs and CLI tools to provide a comprehensive coding assistant ecosystem. Additionally, the timezone must be consistently set to Pacific Time (`America/Los_Angeles`) across all runtime contexts — sway desktop, shell sessions, and the status bar — to match the us-west1 deployment region and the PO's local time.

### Current State

1. **AI IDEs missing from Nix packages** — Cursor, Zed, Aider, and Windsurf are not installed, limiting the PO to VSCode and IntelliJ as the only graphical IDEs
2. **AI CLI tools missing from npm** — Sourcegraph Cody CLI and pi-coding-agent are not available alongside Claude Code, Gemini CLI, and Codex
3. **GitHub Copilot CLI not installed** — The `gh copilot` extension is not present, preventing AI-assisted shell command suggestions via GitHub Copilot
4. **Sway keybindings missing for new IDEs** — Cursor and Windsurf have no keyboard shortcuts in the sway config, requiring manual launch
5. **Timezone not set consistently** — The `TZ` environment variable may not be set in all contexts (sway-desktop.service, .zshrc, sway-status script), causing clock displays and log timestamps to show UTC instead of Pacific Time

## Requirements

### Feature 1: Add AI IDEs via Nix Home Manager

1. The following packages MUST be added to the `home.packages` list in `home.nix`:
   - `code-cursor` — Cursor IDE (Electron-based, fork of VSCode)
   - `zed-editor` — Zed IDE (GPU-accelerated code editor)
   - `aider-chat` — Aider AI pair programming tool
   - `windsurf` — Windsurf IDE (Electron-based, fork of VSCode)
2. All four packages MUST be available after `home-manager switch` runs during the boot sequence (07-apps.sh)
3. Binaries MUST be accessible via `$HOME/.nix-profile/bin/`

### Feature 2: Add CLI Tools via npm

1. The following npm packages MUST be added to the global npm update line in `07-apps.sh`:
   - `@sourcegraph/cody` — Sourcegraph Cody AI coding assistant CLI
   - `@mariozechner/pi-coding-agent` — pi-coding-agent CLI
2. Both MUST be installed globally via `npm update -g` alongside existing packages (Claude Code, Gemini CLI, Codex)
3. Binaries MUST be available on `$PATH` via `$HOME/.npm-global/bin/`

### Feature 3: Add GitHub Copilot CLI

1. The `gh-copilot` extension MUST be installed via `gh extension install github/gh-copilot`
2. On subsequent boots, the extension MUST be upgraded via `gh extension upgrade gh-copilot`
3. The install/upgrade command MUST be added to `07-apps.sh` so it runs on every boot
4. After installation, `gh copilot suggest` and `gh copilot explain` MUST be functional

### Feature 4: Sway Keybindings for Cursor and Windsurf

1. A keybinding for Cursor MUST be added to the sway config using `CTRL+SHIFT+C`:
   - Binary: `$nix/cursor`
   - Electron flags: `--no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage`
   - MUST be wrapped with `env -u LD_LIBRARY_PATH` to prevent nvidia GL conflicts (same pattern as VSCode)
2. A keybinding for Windsurf MUST be added to the sway config using `CTRL+SHIFT+W`:
   - Binary: `$nix/windsurf`
   - Electron flags: identical to Cursor and VSCode
   - MUST be wrapped with `env -u LD_LIBRARY_PATH`
3. Both keybindings MUST follow the existing VSCode keybinding pattern established in F-0035

### Feature 5: Fix Timezone to Pacific Time

1. The `sway-desktop.service` systemd unit MUST set `Environment=TZ=America/Los_Angeles` so that all processes spawned by sway (including the status bar) inherit Pacific Time
2. The `.zshrc` MUST export `TZ="America/Los_Angeles"` so that interactive shell sessions display correct local time
3. The `sway-status` script MUST export `TZ="America/Los_Angeles"` so that the status bar clock shows Pacific Time
4. All three locations MUST be consistent — no context should fall back to UTC

## Files to Change

| File | Change |
|------|--------|
| `~/.config/home-manager/home.nix` | Add `code-cursor`, `zed-editor`, `aider-chat`, `windsurf` to `home.packages` list |
| `workstation-image/boot/07-apps.sh` | Add `@sourcegraph/cody @mariozechner/pi-coding-agent` to npm update line; add `gh extension install/upgrade gh-copilot` step |
| `workstation-image/configs/sway/config` | Add `bindsym $mod+c` for Cursor and `bindsym $mod+w` for Windsurf (Electron flags, `env -u LD_LIBRARY_PATH`) |
| `workstation-image/boot/03-sway.sh` | Ensure `Environment=TZ=America/Los_Angeles` in sway-desktop.service |
| `workstation-image/boot/05-shell.sh` | Ensure `export TZ="America/Los_Angeles"` in generated .zshrc |
| `workstation-image/configs/swaybar/sway-status` | Ensure `export TZ="America/Los_Angeles"` at top of script |

## Acceptance Criteria

### Feature 1: AI IDEs via Nix
- [ ] `code-cursor`, `zed-editor`, `aider-chat`, `windsurf` are listed in `home.nix` under `home.packages`
- [ ] After `home-manager switch`, binaries exist at `~/.nix-profile/bin/{cursor,zed,aider,windsurf}`
- [ ] No regressions to existing Nix packages (VSCode, IntelliJ, etc.)

### Feature 2: npm CLI Tools
- [ ] `@sourcegraph/cody` and `@mariozechner/pi-coding-agent` are in the `npm update -g` line in 07-apps.sh
- [ ] After boot, `cody --help` and `pi-coding-agent --help` work from the terminal
- [ ] Existing npm tools (Claude Code, Gemini CLI, Codex) are not affected

### Feature 3: GitHub Copilot CLI
- [ ] `gh extension install github/gh-copilot` runs on first boot
- [ ] `gh extension upgrade gh-copilot` runs on subsequent boots
- [ ] `gh copilot suggest "list files"` produces output (requires auth)
- [ ] The install/upgrade step is in 07-apps.sh

### Feature 4: Sway Keybindings
- [ ] `CTRL+SHIFT+C` launches Cursor with correct Electron flags and `env -u LD_LIBRARY_PATH`
- [ ] `CTRL+SHIFT+W` launches Windsurf with correct Electron flags and `env -u LD_LIBRARY_PATH`
- [ ] Both commands follow the exact same pattern as the VSCode keybinding (`$mod+y`)
- [ ] No conflicts with existing keybindings
- [ ] No regressions to other sway keybindings

### Feature 5: Timezone
- [ ] `sway-desktop.service` contains `Environment=TZ=America/Los_Angeles`
- [ ] `.zshrc` contains `export TZ="America/Los_Angeles"`
- [ ] `sway-status` script contains `export TZ="America/Los_Angeles"`
- [ ] Status bar clock shows Pacific Time (not UTC)
- [ ] `date` command in terminal shows Pacific Time
- [ ] All three timezone settings are consistent

## Out of Scope

- API key configuration for any AI tool (user manages their own keys via `~/.env`)
- Zed or Aider sway keybindings (these are terminal-based tools, not Electron apps — launched from the shell)
- Shell completions or aliases for the new CLI tools
- Global nvidia `LD_LIBRARY_PATH` fix (per-invocation workaround with `env -u` is the established pattern)
- Configuring GitHub Copilot authentication (user handles `gh auth login` separately)

## Dependencies

- F-0001 (Language support — Go must be available for OpenCode; Node.js for npm tools)
- F-0017 (Nix Home Manager Apps — established the home.nix package pattern)
- F-0035 (Fix IDE Keybindings — established the `env -u LD_LIBRARY_PATH` + Electron flags pattern for Electron IDEs)

## Open Questions

- None — all features are straightforward additions following established patterns in the codebase
