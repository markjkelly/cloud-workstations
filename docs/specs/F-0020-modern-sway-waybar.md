# F-0020: Modern Sway Desktop and Status Bar

**Type:** Enhancement
**Priority:** P1 (important)
**Status:** Draft
**Requested by:** PO (Ameer Abbas)
**Date:** 2026-03-20

## Problem

The current Sway desktop looks dated and boring. Waybar's wlr-layer-shell protocol doesn't render on the wayvnc headless backend, forcing a fallback to swaybar with minimal styling. The desktop needs a modern aesthetic with proper gaps, colors, and a well-styled status bar.

## Requirements

### R1: Modern Sway Window Manager Config

Apply a cohesive Tokyo Night color theme and modern tiling aesthetics:

- **Gaps**: inner 6px, outer 12px
- **Smart gaps**: enabled (no gaps with single window)
- **Borders**: 2px pixel (no title bars)
  - Focused: #7aa2f7 (blue accent)
  - Unfocused: #414868 (muted gray)
  - Urgent: #f7768e (red)
- **Background**: #1a1b26 (Tokyo Night dark)
- **Font**: pango:monospace Bold 10
- **Focus follows mouse**: yes
- **Window rules**: floating for dialog/popup/splash windows
- **Preserve all keybindings** from F-0016 (CTRL+SHIFT modifier, 8 workspaces, all app launchers)

### R2: Modern Swaybar with JSON Protocol Status

Since Waybar cannot render on wayvnc headless, use swaybar with the i3bar JSON protocol for rich, colored output:

- **Position**: top
- **Height**: 28px
- **Font**: pango:monospace Bold 10
- **Bar colors** (Tokyo Night):
  - Background: #1a1b26
  - Statusline: #c0caf5
  - Separator: #414868
  - Focused workspace: bg=#7aa2f7, border=#7aa2f7, text=#1a1b26
  - Active workspace: bg=#414868, border=#414868, text=#c0caf5
  - Inactive workspace: bg=#1a1b26, border=#1a1b26, text=#565f89
  - Urgent workspace: bg=#f7768e, border=#f7768e, text=#1a1b26
- **Status script** (~/.local/bin/sway-status) using i3bar JSON protocol:
  - CPU usage (color-coded: green <50%, yellow 50-80%, red >80%)
  - Memory usage (color-coded similarly)
  - Disk usage (/ and /home)
  - GPU status (nvidia-smi temperature/utilization)
  - Network status
  - Date and time (formatted nicely)
  - Use JSON protocol with {"version":1} header for per-block colors and markup

### R3: Waybar Config (For Future Use)

Create a Waybar config + CSS that can be activated when/if the layer-shell rendering issue is resolved:
- Modules: workspaces, cpu, memory, disk, network, clock, tray
- CSS: Tokyo Night theme, rounded pill modules, semi-transparent background, hover effects, Nerd Font icons
- Store alongside swaybar config for easy swap

### R4: Config File Organization

All config files stored in the repo at:
- workstation-image/configs/sway/config — Sway config
- workstation-image/configs/swaybar/sway-status — Status script
- workstation-image/configs/waybar/config.jsonc — Waybar config (future)
- workstation-image/configs/waybar/style.css — Waybar CSS (future)

## Acceptance Criteria

- [ ] Sway shows visible gaps between windows (6px inner, 12px outer)
- [ ] Tokyo Night color scheme applied consistently across borders and bar
- [ ] Swaybar displays at top with colored CPU, memory, disk, GPU, clock
- [ ] Status values are color-coded (green/yellow/red thresholds)
- [ ] All F-0016 keybindings work unchanged
- [ ] Waybar config created for future activation
- [ ] Config files committed to repo under workstation-image/configs/

## Dependencies

- F-0016 (Sway/Waybar base install — done)

## Out of Scope

- Fixing the wayvnc layer-shell rendering issue (tracked separately if needed)
- Wallpaper/background images (solid color sufficient)
- Notification daemon styling (mako — separate task)
