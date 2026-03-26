# F-0017: Nix Home Manager with Full App Suite

**Type:** Feature
**Priority:** P0 (critical)
**Status:** Draft
**Requested by:** PO (Your Name)
**Date:** 2026-03-20

## Problem

The PO wants ALL applications managed via Nix package manager using Home Manager for both user and root. This ensures all installs are declarative, reproducible, and persist on the HOME disk.

## Requirements

### R1: Set Up Nix Home Manager

Install and configure Nix Home Manager for:
- **user** (primary user account) — all desktop apps and dev tools
- **root** — system-level Nix packages if needed

Home Manager config at `~/.config/home-manager/home.nix` (persistent disk).

### R2: Install Dev Tools via Home Manager

Add the following to the Home Manager config:
- `tmux` — terminal multiplexer
- `tree` — directory listing
- `zsh` — Z shell (set as default shell)
- `ffmpeg` — media processing

### R3: Install IDEs and Editors via Home Manager

- `vscode` (nixpkgs.vscode) — Visual Studio Code
- `jetbrains.idea-ultimate` or `jetbrains.idea-community` — IntelliJ IDEA
- `cursor` — Cursor IDE (may need custom derivation or AppImage approach if not in nixpkgs)

### R4: Install Browsers via Home Manager

- `chromium` (nixpkgs.chromium) — Chromium browser
- Google Chrome already handled via F-0014

### R5: Install AI CLI Tools via Home Manager

- `claude-code` — Anthropic Claude Code CLI (may need npm/node install via Nix, e.g., `nixpkgs.nodejs` then `npm install -g @anthropic-ai/claude-code`)
- `gemini-cli` — Google Gemini CLI (may need npm install or custom derivation)

### R6: Desktop Integration

All GUI apps should have:
- Desktop shortcuts in `~/.local/share/applications/`
- Proper icons
- Working launch from both terminal and GNOME/Sway app launcher

## Acceptance Criteria

- [ ] Home Manager installed and configured for user
- [ ] `home.nix` declares all packages
- [ ] `home-manager switch` applies config successfully
- [ ] All listed apps launch correctly
- [ ] All apps persist across workstation stop/start
- [ ] Claude Code CLI works: `claude --version`
- [ ] Gemini CLI works
- [ ] zsh is set as default shell
