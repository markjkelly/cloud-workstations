# F-0016: Sway Window Manager with Waybar and Workspaces

**Type:** Feature
**Priority:** P0 (critical)
**Status:** Draft
**Requested by:** PO (Your Name)
**Date:** 2026-03-20

## Problem

The PO wants Sway (Wayland compositor / tiling window manager) with Waybar as the status bar, configured with at least 6 workspaces. This replaces or supplements the default GNOME desktop for a more keyboard-driven workflow.

## Requirements

### R1: Install Sway via Nix

Install Sway window manager via Nix Home Manager on the persistent disk.
- Package: `nixpkgs.sway`
- Must work with the existing VNC/noVNC setup (note: Sway is Wayland-native, may need wlroots headless backend or Xwayland for VNC compatibility)

### R2: Install and Configure Waybar

Install Waybar via Nix and configure with:
- At least 6 workspace indicators
- System info (CPU, memory, clock)
- Clean, functional layout

### R3: Supporting Apps via Nix

Install via Nix Home Manager:
- `foot` — terminal emulator (Wayland-native)
- `wofi` — application launcher (Wayland-native)
- `thunar` — file manager
- Clipboard manager (e.g., `clipman` or `wl-clipboard` + picker)

### R4: Key Bindings (Modifier: CTRL+SHIFT)

**General:**

| Key | Action |
|-----|--------|
| CTRL+SHIFT+Return | Open Terminal (foot) |
| CTRL+SHIFT+T | Open Terminal (foot) |
| CTRL+SHIFT+Q | Close active window |
| CTRL+SHIFT+Escape | Exit Sway |
| CTRL+SHIFT+F | Toggle fullscreen |
| Super+F | Toggle fullscreen |
| CTRL+SHIFT+D | Toggle floating window |
| CTRL+SHIFT+R | Application Launcher (wofi) |
| CTRL+SHIFT+E | Open File Manager (Thunar) |
| CTRL+SHIFT+B | Open Web Browser (Chrome) |
| CTRL+SHIFT+N | Open Antigravity (Safe Mode) |
| CTRL+SHIFT+M | Open IntelliJ IDEA |
| CTRL+SHIFT+Y | Open VS Code |
| CTRL+SHIFT+A | Clipboard history picker |
| CTRL+SHIFT+S | Snippet picker (text expansion) |

**Navigation:**

| Key | Action |
|-----|--------|
| CTRL+SHIFT+Left | Move focus left |
| CTRL+SHIFT+Right | Move focus right |
| CTRL+SHIFT+Up | Move focus up |
| CTRL+SHIFT+Down | Move focus down |

**Window Resize:**

| Key | Action |
|-----|--------|
| CTRL+SHIFT+, | Grow window width |
| CTRL+SHIFT+. | Shrink window width |
| CTRL+SHIFT+- | Shrink window height |
| CTRL+SHIFT+= | Grow window height |

**Switch Workspace:**

| Key | Workspace |
|-----|-----------|
| CTRL+SHIFT+U | 1 |
| CTRL+SHIFT+I | 2 |
| CTRL+SHIFT+O | 3 |
| CTRL+SHIFT+P | 4 |
| CTRL+SHIFT+H | 5 |
| CTRL+SHIFT+J | 6 |
| CTRL+SHIFT+K | 7 |
| CTRL+SHIFT+L | 8 |

**Move Window to Workspace:**

| Key | Workspace |
|-----|-----------|
| CTRL+SHIFT+ALT+U | 1 |
| CTRL+SHIFT+ALT+I | 2 |
| CTRL+SHIFT+ALT+O | 3 |
| CTRL+SHIFT+ALT+P | 4 |
| CTRL+SHIFT+ALT+H | 5 |
| CTRL+SHIFT+ALT+J | 6 |
| CTRL+SHIFT+ALT+K | 7 |
| CTRL+SHIFT+ALT+L | 8 |

### R5: VNC Compatibility

Ensure Sway works through the existing TigerVNC + noVNC pipeline. Options:
- Use `WLR_BACKENDS=headless` for wlroots
- Or configure Sway to render to a virtual display that VNC can capture
- Or use wayvnc instead of TigerVNC for native Wayland VNC

## Acceptance Criteria

- [ ] Sway installed via Nix and launches
- [ ] Waybar displays with 8 workspace indicators
- [ ] All keybindings from R4 work correctly
- [ ] foot, wofi, thunar installed and functional
- [ ] Clipboard history picker works (CTRL+SHIFT+A)
- [ ] Desktop is accessible via noVNC in browser
- [ ] Configuration persists across reboots (on persistent disk)
