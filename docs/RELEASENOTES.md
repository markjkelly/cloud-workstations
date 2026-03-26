# Release Notes — Cloud Workstation

## v1.6 — Multi-Project Hardening (2026-03-24)

### Added
- **17-step setup script** (`cloud-build-setup.sh`) — expanded from 15 steps with Nix persistence (Step 11) and noVNC desktop verification (Step 17)
- **Weekday-only Cloud Scheduler** — `ws-weekday-start` (6AM Mon-Fri) and `ws-weekday-stop` (9PM Mon-Fri). Workstations stay off on weekends
- **25-test post-setup verification suite** — covers Sway, swaybar, wayvnc, noVNC, Antigravity, Nix, fonts, ZSH, Starship, AI tools, Cloud Scheduler, Chrome, VS Code
- **Consolidated `ws.sh`** — single script for setup (via Cloud Build) and teardown with webhook + email notifications

### Fixed
- **Fresh GCP project support** — auto-creates default VPC network, grants permissions to both Cloud Build and Compute Engine SAs, adds `--service-account` to workstation config
- **Nix store persistence** — copies /nix to /home/user/nix after all installs so the store survives container restarts (bind-mounted back by startup script)
- **Antigravity keybinding** — changed from non-existent `/home/user/.antigravity/` path to `/usr/bin/antigravity` (apt-installed in Docker image)
- **Antigravity autostart on workspace 3** — fixed path in `08-workspaces.sh`, increased timeout from 15s to 30s
- **Swaybar after reboot** — deployed current sway config to gement01 (was using old i3status-rust config)
- **Window sizing** — removed outer gaps (12px → 0) for edge-to-edge windows
- **Webhook URL escaping** — array-based substitution building handles `&` characters in Google Chat webhook URLs
- **Cloud Logging visibility** — grants Logs Writer role to build SA so build logs appear

### Verified
- gement02: 33 PASS / 0 FAIL + 25/25 post-setup tests
- gement03: 33 PASS / 0 FAIL + 25/25 post-setup tests
- All 3 projects (gement01/02/03) have working schedulers and identical configurations

---

## v1.4 — Auto-Start & Daily Readiness (2026-03-20)

### Added
- **Persistent disk bootstrap** (`~/boot/setup.sh`) — All workstation setup now lives on the persistent disk as modular scripts (01-nix through 08-workspaces). Future changes require zero Docker rebuilds.
- **Cloud Scheduler** (`ws-daily-start`) — Workstation auto-starts daily at 7AM Pacific via Cloud Scheduler → Workstations API HTTP POST with OAuth
- **Custom fonts** — 223+ fonts installed: Operator Mono (12 variants), CascadiaCode (168), FiraCodeiScript (19), CaskaydiaCove Nerd Font (24)
- **ZSH default shell** — exec zsh in .bashrc, zsh-syntax-highlighting + zsh-autosuggestions via git clone, comprehensive .zshrc with Nix profile, PATH, history, completions
- **Starship prompt** — Starship 1.24.2 cross-shell prompt with ZSH integration
- **foot terminal config** — Operator Mono Book:size=18, Tokyo Night color scheme, 8px padding, 10K scrollback
- **App auto-update on boot** (`~/boot/07-apps.sh`) — Updates Claude Code, Gemini CLI (npm), VSCode, IntelliJ (Nix/Home Manager) on each boot, logs to ~/logs/app-update.log
- **Workspace auto-launch** (`~/boot/08-workspaces.sh`) — Pre-launches 4 Sway workspaces: ws1=foot, ws2=Chrome, ws3=Antigravity, ws4=foot
- **000_bootstrap.sh** — Docker image bridge script that delegates all setup to ~/boot/setup.sh on the persistent disk

### Architecture
- **Persistent bootstrap pattern**: Docker image only needs `000_bootstrap.sh` to call `~/boot/setup.sh`. All 8 sub-scripts live on the 500GB persistent disk. Adding features = adding a script file, no rebuild needed.
- **Script execution order**: 01-nix → 02-nvidia → 03-sway → 04-fonts → 05-shell → 06-prompt → 07-apps → 08-workspaces

### Fixed
- **swaymsg SWAYSOCK discovery** — root→user swaymsg calls now auto-discover the Sway IPC socket path
- **Chrome Wayland fallback** — Added `--ozone-platform=wayland` to prevent X11 crash in workspace auto-launch
- **foot.ini deprecation** — Updated `[colors]` → `[colors-dark]` for newer foot versions

---

## v1.3 — Documentation, Validation, and Sway Boot Fix (2026-03-20)

### Added
- **Comprehensive setup guide** (`docs/SETUP.md`, 1,137 lines) — 14-section step-by-step guide to recreate the entire Cloud Workstation from scratch, usable by humans and AI agents
- **Sway auto-start on boot** (`300_setup-sway-desktop.sh`) — startup script creates sway-desktop + wayvnc systemd services on every boot, disables TigerVNC, adds nvidia ldconfig
- **Docker image rebuilt** — natively includes `300_setup-sway-desktop.sh` (Sway auto-start on boot). No more manual deployment of startup scripts after workstation reboot.

### Fixed
- **GNOME starting instead of Sway on reboot** — Sway/wayvnc services were on ephemeral disk and lost on restart. New startup script recreates them before systemd boots
- **nvidia-smi LD_LIBRARY_PATH** — ldconfig now runs on boot to make nvidia libs available system-wide without manual env vars

### Verified
- **Post-reboot E2E validation** (33 PASS, 1 WARN, 0 FAIL):
  - All 17 Nix apps, 2 AI CLI tools, GPU (Tesla T4), Antigravity, Nix store (8,346 packages), persistent disk (479GB free), all configs intact after stop/start cycle

---

## v1.2 — Modern Desktop (Tokyo Night) (2026-03-20)

### Added
- **Modern Sway config** with Tokyo Night color scheme — 6px inner / 12px outer gaps, smart gaps, 2px pixel borders (focused=#7aa2f7, urgent=#f7768e)
- **Color-coded swaybar status** using i3bar JSON protocol — CPU, memory, disk, GPU temp/utilization, network, clock with green/yellow/red thresholds
- **Waybar config + CSS** (for future use) — pill-shaped modules, semi-transparent background, hover effects, urgent-pulse animation
- All config files stored in repo at `workstation-image/configs/` for reproducibility
- F-0023 backlog item for comprehensive setup documentation

### Changed
- Sway config now uses Tokyo Night palette (bg=#1a1b26, accent=#7aa2f7) with modern gaps and borders
- Swaybar upgraded from plain text to i3bar JSON protocol with per-module color coding
- Added floating window rules for dialogs, pop-ups, file operations

### Preserved
- All 33 keybindings from F-0016 (CTRL+SHIFT modifier, 8 workspaces, all app launchers)

---

## v1.1 — Nix Home Manager + Full App Suite (2026-03-20)

### Added
- Nix Home Manager v26.05-pre — all packages declared in `~/.config/home-manager/home.nix`
- **Dev Tools**: Neovim 0.11.6 (custom init.lua), tmux 3.6a, zsh 5.9, ffmpeg 8.0.1, ripgrep, fd, jq, tree
- **Browsers**: Chromium 146.0.7680.80, Google Chrome 146.0.7680.80
- **IDEs**: VS Code 1.111.0, IntelliJ IDEA OSS
- **Sway Desktop**: Sway 1.11, Waybar 0.15.0, foot 1.26.1, wofi, thunar, clipman, wayvnc, mako
- **AI CLI Tools**: Claude Code 2.1.80, Gemini CLI 0.34.0 (via npm to `~/.npm-global/bin`)
- **Sway Config**: 8 workspaces (CTRL+SHIFT+U/I/O/P/H/J/K/L), CTRL+SHIFT modifier, full keybinding set
- **Neovim Config**: Space leader, habamax theme, floating terminal, auto yank highlight
- Waybar with workspace indicators, CPU, memory, disk, clock
- Startup script `200_persist-nix.sh` for /nix bind mount + nvidia paths

### Changed
- /nix uses bind mount instead of symlink (Nix rejects symlinks)
- Docker image rebuilt with startup script for persistent Nix
- IntelliJ: `idea-community` removed from nixpkgs, using `idea-oss`
- Antigravity wrapper path fixed (double directory: `~/.antigravity/antigravity/bin/`)

### Known Issues
- Cursor IDE not in nixpkgs — needs AppImage approach
- Sway VNC integration needs testing (wayvnc vs TigerVNC)

---

## v1.0 — Cloud Workstation Live (2026-03-20)

### Added
- Cloud Workstation cluster `workstation-cluster` in us-west1
- Artifact Registry `workstation-images` with custom Docker image (~3.3GB)
- Workstation config `ws-config`: n1-standard-16 + NVIDIA Tesla T4 GPU, 500GB pd-ssd, 4h idle / 12h run timeout
- Workstation `dev-workstation` — GNOME desktop via noVNC in browser
- Google Antigravity v1.20.6 installed and accessible from desktop
- Google Chrome with `--no-sandbox --no-zygote --disable-gpu --disable-dev-shm-usage` flags
- TigerVNC (port 5901) + noVNC (port 80) for browser-based desktop access
- NVIDIA Tesla T4 GPU (15GB VRAM, Driver 535.288.01, CUDA 12.2)
- Nix package manager 2.34.2 on persistent HOME disk (492GB available)
- Cloud Router + Cloud NAT for internet access (org policy blocks public IPs)
- Shielded VM enabled (secure boot, vTPM, integrity monitoring — org policy)
- IAM: admin@ameerabbas.altostrat.com has workstations.user access

### Access
- **URL:** `https://dev-workstation.cluster-wg3q6vm6rnflcvjsrq5k7aqoac.cloudworkstations.dev`
- **noVNC:** Auto-redirects to VNC desktop on port 80
- **GPU:** `nvidia-smi` at `/var/lib/nvidia/bin/nvidia-smi` (PATH set via `/etc/profile.d/nvidia.sh`)
- **Nix:** `. /home/user/.nix-profile/etc/profile.d/nix.sh` (auto-sourced on login)

### Known Issues
- Machine type is n1-standard-16 (60GB RAM) instead of g2-standard-16 (64GB) — g2 not supported by Cloud Workstations
- GPU is Tesla T4 instead of L4 — L4 not supported as Cloud Workstations accelerator
- `/etc/profile.d/nvidia.sh` is on ephemeral disk — will need re-creation after container restart (should be added to Dockerfile or startup script)

---

## v0.1 — Initial Release

Build a Cloud Workstation in GCP Project ID gement01 with Google Antigravity installed (antigravity.google) following the blog at this link https://medium.com/google-cloud/running-antigravity-on-a-browser-tab-6298bb7e47c4. The Cloud Workstation machine should have a GPU and 64GB RAM as well as 500GB SSD drive. The 500GB SSD drive is a persistent disk with HOME folder mounted to it. All apps must be installed inside the peristent disk. The main docker image should be minimal so all changes, app installs persist inside the persistent disk. For OS, I prefer NixOS with Nix package manager. Follow the blog for what to install and ask questions as necessary

### Features
- Project scaffolding generated with appteam
- Multi-agent team structure configured
- Development pipeline and workflow established

### Team
- SWE-1: General Engineer 1
- SWE-2: General Engineer 2
- SWE-3: General Engineer 3
- SWE-Test: Automated testing
- SWE-QA: E2E testing & QA
- Platform Engineer: Infrastructure & deployment
- Reviewer: Code review & quality
