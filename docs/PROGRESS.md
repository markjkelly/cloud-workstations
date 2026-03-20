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

### In Progress
- F-0012 through F-0018: Running `home-manager switch` with comprehensive home.nix containing ALL packages

### Pending
- F-0012: Set up Nix Home Manager (blocked on F-0011)
- F-0013: Verify Antigravity persistent (blocked on F-0011)
- F-0014: Install browsers via Nix HM (blocked on F-0012)
- F-0015: Install dev tools via Nix HM (blocked on F-0012)
- F-0016: Install Sway + Waybar (blocked on F-0012)
- F-0017: Install IDEs via Nix HM (blocked on F-0012)
- F-0018: Install AI CLI tools (blocked on F-0012)
- F-0019: E2E validation (blocked on all above)
