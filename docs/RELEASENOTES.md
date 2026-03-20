# Release Notes — Cloud Workstation

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
- ameer00@gmail.com IAM access still pending (API precondition)

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
- ameer00@gmail.com IAM access pending (API precondition issue — set when workstation is stopped)
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
