# Development Progress Log — Cloud Workstation

## Session 1

### Goals
- Initial project setup and configuration

### Completed
- Generated project scaffolding with appteam
  - CLAUDE.md with team workflow, conventions, and pipeline rules
  - Agent definitions for PM, TPM, SWE-1, SWE-2, SWE-3, SWE-Test, SWE-QA, Platform Engineer, Reviewer
  - BACKLOG.md, PROGRESS.md, RELEASENOTES.md

### Next Steps
- Define initial feature backlog in BACKLOG.md
- Begin implementation of first milestone

---

## Session 2 — 2026-03-20

### Goals
- Execute Milestone 1: Stand up the Cloud Workstation with GPU, Antigravity, GNOME, noVNC

### Pre-existing State (discovered at session start)
- F-0001 (Cluster): `workstation-cluster` already exists in us-west1 — DONE
- F-0002 (Artifact Registry): `workstation-images` repo exists in us-west1 with images — DONE
- F-0003 (Docker Image): `workstation` image built and pushed (~3.3GB) with GNOME, Antigravity, Chrome, TigerVNC, noVNC — DONE
- All required APIs enabled (workstations, artifactregistry, compute)
- No SA key file found; using admin@ameerabbas.altostrat.com identity

### Completed
- **F-0001** (Cluster): Pre-existing `workstation-cluster` in us-west1
- **F-0002** (Artifact Registry): Pre-existing `workstation-images` repo in us-west1
- **F-0003** (Docker Image): Pre-existing `workstation` image (~3.3GB) with GNOME, Antigravity, Chrome, TigerVNC, noVNC
- **F-0004/F-0005** (Config): Created `ws-config` — n1-standard-16 + nvidia-tesla-t4, 500GB pd-ssd, 4h idle/12h run, no public IP, Shielded VM
- **F-0006** (GPU): Tesla T4 verified — Driver 535.288.01, CUDA 12.2, nvidia-smi at `/var/lib/nvidia/bin/`. Created `/etc/profile.d/nvidia.sh` for PATH/LD_LIBRARY_PATH
- **F-0007** (Nix): Nix 2.34.2 installed on persistent HOME disk. `nix-env -iA` works. Created Cloud Router `ws-router` + Cloud NAT `ws-nat` for internet access
- **F-0008** (IAM/Network): admin@ameerabbas.altostrat.com has workstations.user. AR reader granted to service agent. No public IP + Shielded VM (org policies). ameer00@gmail.com access pending (API precondition issue — can be set when workstation is stopped)
- **F-0009** (Workstation): `dev-workstation` RUNNING at `dev-workstation.cluster-wg3q6vm6rnflcvjsrq5k7aqoac.cloudworkstations.dev`
- **F-0010** (E2E): All verified — Antigravity installed, noVNC active (HTTP 302 via proxy), TigerVNC active, T4 GPU working, Nix 2.34.2 with package install, 492GB home disk available

### Issues Encountered and Resolved
1. `--idle-timeout=14400s` invalid — int expected, no suffix — FIXED
2. `g2-standard-16` NOT supported by Cloud Workstations — used `n1-standard-16` + `nvidia-tesla-t4` instead
3. `nvidia-l4` accelerator NOT supported — used `nvidia-tesla-t4` (T4 16GB VRAM)
4. `roles/workstations.user` cannot be bound at project level — granted at workstation level automatically on create
5. Org policy `constraints/compute.vmExternalIpAccess` — added `--disable-public-ip-addresses`
6. Org policy `constraints/compute.requireShieldedVm` — added `--shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring`
7. No internet inside workstation — created Cloud Router + Cloud NAT
8. `nvidia-smi` not in PATH — found at `/var/lib/nvidia/bin/`, created profile script
9. `owner-sa` service account does not exist — not critical, skipped

### Decisions
- Used admin@ameerabbas.altostrat.com identity (no SA key file)
- Machine type: n1-standard-16 (60GB RAM) since g2-standard-16 not supported by Cloud Workstations
- GPU: nvidia-tesla-t4 since nvidia-l4 not supported as accelerator
- Cloud NAT for internet access (required due to no public IP org policy)

### Next Steps
- Grant ameer00@gmail.com access (stop workstation, set IAM, restart)
- Test stop/start cycle to verify persistence (Nix, GPU profile, data)
- Tag v1.0 release after PO approval

---

## Session 3 — 2026-03-20 (continued)

### Goals
- Milestone 2: Migrate all app installs to Nix Home Manager
- Install Sway + Waybar with 8 workspaces and custom keybindings
- Install full app suite: neovim, tmux, zsh, ffmpeg, chromium, chrome, vscode, intellij, cursor, claude-code, gemini-cli
- Configure Neovim with custom init.lua

### Completed So Far
- Moved /nix to persistent disk at /home/user/nix with bind mount (not symlink — Nix rejects symlinks)
- Added 200_persist-nix.sh startup script to Docker image (restores /nix bind mount + nvidia paths on boot)
- Rebuilt Docker image via Cloud Build (SUCCESS)
- Rebooted workstation — startup scripts verified working (/nix bind mount, nvidia, VNC)
- Copied Antigravity to persistent disk at ~/.antigravity — verified working after reboot (v1.107.0)
- Created specs: F-0011 (nix migration), F-0016 (sway/waybar), F-0017 (nix HM apps)
- Saved Sway keybindings, Neovim keybindings, and Neovim init.lua config locally
- Created Milestone 2 backlog (F-0011 through F-0019)
- Committed all specs and configs
- Installed Nix Home Manager v26.05-pre
- Created comprehensive home.nix with ALL packages: neovim, tmux, tree, zsh, ffmpeg, chromium, google-chrome, vscode, jetbrains.idea-community, sway, waybar, foot, wofi, thunar, clipman, wayvnc, nodejs_22
- Created Sway config with full keybindings (CTRL+SHIFT modifier, 8 workspaces)
- Created Waybar config (workspaces, CPU, memory, disk, clock)
- Created Neovim init.lua config (Space leader, floating terminal, habamax theme)
- Running home-manager switch to install everything
- Fixed: jetbrains.idea-community removed from nixpkgs — using jetbrains.idea-oss
- Fixed: Added nixpkgs.config.allowUnfree = true for Chrome, VSCode, etc.
- Fixed: /nix must be bind mount, not symlink — Nix rejects symlinks
- home-manager switch SUCCESS — all packages installed
- Verified all apps: NVIM 0.11.6, tmux 3.6a, zsh 5.9, ffmpeg 8.0.1, Chromium 146, Chrome 146, VSCode 1.111.0, IntelliJ OSS, Sway 1.11, Waybar 0.15.0, foot 1.26.1, Node.js 22.22.1
- Claude Code 2.1.80 and Gemini CLI 0.34.0 installed via npm to ~/.npm-global/bin
- All configs deployed: Neovim init.lua, Sway config (8 workspaces, CTRL+SHIFT keybindings), foot config
- Switched from GNOME to Sway desktop via wayvnc (headless backend)
- Waybar layer-shell surfaces don't render with headless+wayvnc — using swaybar (sway's built-in bar) instead
- Swaybar showing: workspace indicators (left), LOAD/MEM/datetime (right), dark #1a1b26 theme
- Created sway-status script at ~/.local/bin/sway-status for bar status output
- Created systemd services: sway-desktop.service, wayvnc.service (replacing TigerVNC)

### Pending
- F-0019: E2E validation (blocked on all above)

---

## Session 4 — 2026-03-20 (continued)

### Goals
- Milestone 3: Modernize Sway and status bar appearance (Tokyo Night theme, gaps, colored status)
- Fix boring/dated desktop look
- Add comprehensive setup documentation to backlog

### Completed
- **F-0020** (Modern Sway config): Created `workstation-image/configs/sway/config` with:
  - Tokyo Night color palette (10 variables: bg, fg, accent, urgent, green, yellow, magenta, cyan, muted, inactive)
  - Gaps: 6px inner, 12px outer, smart_gaps on
  - 2px pixel borders with Tokyo Night-themed client colors (focused=#7aa2f7, unfocused=#414868, urgent=#f7768e)
  - All 33 keybindings from F-0016 preserved (CTRL+SHIFT modifier, 8 workspaces, all app launchers)
  - Floating window rules for dialogs, pop-ups, file operations
  - Integrated swaybar with Tokyo Night workspace colors
  - Headless output config (HEADLESS-1 1920x1080) for wayvnc
  - Clipboard manager autostart (wl-paste + clipman)

- **F-0021** (Modern swaybar status): Created `workstation-image/configs/swaybar/sway-status` with:
  - i3bar JSON protocol ({"version":1} header + continuous JSON array stream)
  - 6 modules: NET, GPU, CPU, MEM, DISK, Clock
  - Color-coded thresholds: green (#9ece6a) < warn, yellow (#e0af68) < crit, red (#f7768e)
  - CPU: real-time via /proc/stat delta sampling (500ms)
  - Memory: used/total from /proc/meminfo
  - Disk: /home partition from df
  - GPU: nvidia-smi temp + utilization (graceful N/A fallback)
  - Network: ping-based connectivity check
  - 2-second refresh loop

- **F-0022** (Waybar config for future): Created for when layer-shell works on wayvnc:
  - `workstation-image/configs/waybar/config.jsonc` — modules: workspaces, mode, window, network, gpu, cpu, memory, disk, clock with warning/critical states and calendar tooltip
  - `workstation-image/configs/waybar/style.css` — Tokyo Night CSS with semi-transparent bg, pill-shaped modules (12px radius), hover effects, urgent-pulse animation, color-coded states

- **F-0020 spec**: Created `docs/specs/F-0020-modern-sway-waybar.md` with 4 requirements and 7 acceptance criteria
- **Backlog updated**: Added Milestone 3 section with F-0020 through F-0024, including F-0023 for comprehensive setup documentation

### Pipeline
- PM created spec and backlog items
- SWE-1 implemented Sway config (all 33 keybindings verified)
- SWE-2 implemented swaybar status script and Waybar config/CSS
- All three agents ran in parallel

### Decisions
- Kept swaybar (not Waybar) as active bar — Waybar layer-shell doesn't render on wayvnc headless
- Tokyo Night as the standard theme across all components
- i3bar JSON protocol for color-coded status output
- Created Waybar config+CSS for future swap when layer-shell issue is resolved
- Added F-0023 (comprehensive setup documentation) to backlog per PO request

### Deployment
- **Deployed all 4 configs** to workstation via `gcloud workstations ssh` pipe:
  - `~/.config/sway/config` (7937 bytes) — replaced Nix HM symlink with regular file
  - `~/.local/bin/sway-status` (4758 bytes, executable) — i3bar JSON protocol script
  - `~/.config/waybar/config` (2638 bytes) — for future use
  - `~/.config/waybar/style.css` (5088 bytes) — for future use
- Removed stale Nix Home Manager symlinks pointing to old configs in Nix store
- **Sway reloaded** via swaymsg — `{"success": true}`
- Fixed gcloud auth (corrupted GCE credential entry in credentials.db)
- Verified: 3 workspaces active on HEADLESS-1 (1920x1080), inner gaps (6px) and outer gaps (12px) applied

### Next Steps
- F-0023: Create comprehensive setup guide for recreating workstation from scratch
- F-0024: E2E validation of modern desktop
- F-0019: Post-reboot E2E validation (Milestone 2 carryover)
