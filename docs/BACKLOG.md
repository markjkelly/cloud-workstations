# Project Backlog — Cloud Workstation

**Maintained by:** TPM
**Last updated:** 2026-03-26

---

## How to Read This Backlog

- **ID:** Unique feature identifier (`F-0001`, `F-0002`, etc.) — sequential across all milestones, never reused
- **Priority:** P0 (critical path), P1 (important), P2 (nice to have)
- **Status:** `backlog` | `in-progress` | `in-review` | `done` | `blocked`
- **Owner:** Assigned team member
- **Branch:** Git feature branch
- **Dependencies:** Other feature IDs that must complete first
- **Feedback:** Review notes, blockers, decisions — updated as work progresses

---

## Current Milestone — Milestone 1: Cloud Workstation v1.0

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0001 | Cloud Workstation Cluster (us-west1) | F-0001 | P0 | done | PE | feature/ws-cluster | — | Cluster `workstation-cluster` created 2026-03-20 |
| F-0002 | Artifact Registry repository | F-0001 | P0 | done | PE | feature/ws-registry | — | `workstation-images` repo created, Docker format, us-west1 |
| F-0003 | Custom Docker image (Dockerfile) | F-0001 | P0 | done | SWE-1 | feature/ws-dockerfile | F-0002 | Image `workstation` pushed (~3.3GB), includes GNOME+Antigravity+Chrome+VNC+noVNC |
| F-0004 | Workstation Config (GPU) | F-0001 | P0 | done | PE | feature/ws-config | F-0001, F-0003 | Config `ws-config` created: n1-standard-16 + nvidia-tesla-t4, 500GB pd-ssd, 4h idle/12h run, no public IP (org policy) |
| F-0005 | Persistent disk setup (500GB SSD, HOME) | F-0001 | P0 | done | PE | feature/ws-disk | F-0004 | 500GB pd-ssd configured in ws-config via --pd-disk-size=500 --pd-disk-type=pd-ssd |
| F-0006 | GPU driver verification (T4) | F-0001 | P0 | done | PE | feature/ws-gpu-drivers | F-0009 | Tesla T4 verified, Driver 535.288.01, CUDA 12.2. nvidia-smi at /var/lib/nvidia/bin/. Profile script created. |
| F-0007 | Nix package manager (persistent disk) | F-0001 | P1 | done | PE | feature/ws-nix | F-0009 | Nix 2.34.2 installed on persistent disk. nix-env works. Cloud Router + NAT created for internet. |
| F-0008 | Network and IAM configuration | F-0001 | P0 | done | PE | feature/ws-iam | F-0001 | admin@ameerabbas.altostrat.com has workstations.user. AR reader granted. No public IP, Shielded VM enabled. |
| F-0009 | Workstation creation and VNC setup | F-0001 | P0 | done | PE | feature/ws-create | F-0004, F-0008 | dev-workstation RUNNING. Host: dev-workstation.cluster-wg3q6vm6rnflcvjsrq5k7aqoac.cloudworkstations.dev |
| F-0010 | End-to-end validation | F-0001 | P0 | done | SWE-QA | — | F-0009, F-0006, F-0007 | All verified: Antigravity installed, noVNC active (HTTP 302 via proxy), T4 GPU working, Nix 2.34.2 with package install, 492GB home disk |

---

## Milestone 2: Nix App Migration

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0011 | Reboot workstation with new image | F-0011 | P0 | done | PE | — | — | Rebooted. /nix bind mount restored (not symlink — Nix rejects symlinks). nvidia profile restored. VNC running. |
| F-0012 | Set up Nix Home Manager (user + root) | F-0017 | P0 | done | SWE-1 | — | F-0011 | Home Manager v26.05-pre installed. home.nix with allowUnfree, all packages declared. |
| F-0013 | Verify Antigravity persistent install | F-0011 | P0 | done | SWE-1 | — | F-0011 | Verified after reboot. Fixed wrapper path. v1.107.0 working from ~/.antigravity/. |
| F-0014 | Install browsers via Nix HM (Chromium, Chrome) | F-0017 | P0 | done | SWE-1 | — | F-0012 | Chromium 146.0.7680.80, Google Chrome 146.0.7680.80 — both via home-manager. |
| F-0015 | Install dev tools via Nix HM (neovim, tmux, tree, zsh, ffmpeg) | F-0017 | P0 | done | SWE-1 | — | F-0012 | NVIM 0.11.6 + custom init.lua, tmux 3.6a, zsh 5.9, ffmpeg 8.0.1, ripgrep, fd, jq. |
| F-0016 | Install Sway + Waybar + supporting apps via Nix HM | F-0016 | P0 | done | SWE-2 | — | F-0012 | Sway 1.11, Waybar 0.15.0, foot 1.26.1, wofi, thunar, clipman, wayvnc. Full keybinding config. |
| F-0017 | Install IDEs via Nix HM (VSCode, IntelliJ, Cursor) | F-0017 | P0 | done | SWE-2 | — | F-0012 | VSCode 1.111.0, IntelliJ IDEA OSS. Cursor not in nixpkgs — TBD. |
| F-0018 | Install AI CLI tools via Nix (Claude Code, Gemini CLI) | F-0017 | P0 | done | SWE-3 | — | F-0012 | Claude Code 2.1.80, Gemini CLI 0.34.0 — both via npm to ~/.npm-global/bin. Node.js 22.22.1 via Nix. |
| F-0019 | Post-reboot E2E validation | F-0011 | P0 | done | SWE-QA | — | F-0013 thru F-0018 | 33 PASS, 1 WARN, 0 FAIL. All apps, GPU (T4 535.288.01), Nix (8346 pkgs), AI tools, Antigravity, configs verified after reboot. WARN: nvidia-smi needs LD_LIBRARY_PATH (fixed by F-0025). |

---

## Milestone 3: Modern Desktop

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0020 | Modern Sway config (gaps, borders, Tokyo Night) | F-0020 | P1 | done | SWE-1 | — | F-0016 | Complete. Full Nix paths, Electron flags (--no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage), GPU ldconfig, Xwayland. All keybindings verified working by PO. |
| F-0021 | Modern swaybar with JSON protocol status | F-0020 | P1 | done | SWE-2 | — | F-0016 | Fixed: nvidia-smi uses full path /var/lib/nvidia/bin/nvidia-smi. GPU now shows T4 temp + utilization. |
| F-0022 | Waybar config + CSS (future activation) | F-0020 | P2 | done | SWE-2 | — | F-0016 | Deployed to workstation. config.jsonc + style.css ready for when layer-shell works on wayvnc. |
| F-0023 | Comprehensive setup documentation | — | P1 | done | SWE-3 | — | F-0020, F-0021 | docs/SETUP.md created (1137 lines, 14 sections). Covers prerequisites through troubleshooting. Usable by humans and AI agents. |
| F-0024 | E2E validation of modern desktop | F-0020 | P1 | done | SWE-QA | — | F-0020, F-0021, F-0022 | PO confirmed: swaybar visible, GPU in status bar, keybindings working, Antigravity launches stable. |
| F-0025 | Sway auto-start on boot (startup script) | — | P0 | done | SWE-1 | — | F-0016, F-0020 | 300_setup-sway-desktop.sh creates sway-desktop + wayvnc services on boot. Disables TigerVNC. Adds nvidia ldconfig. Deployed and verified: Sway active, wayvnc on 5901, noVNC proxying port 80. |
| F-0026 | Docker image rebuild with startup scripts | — | P0 | done | PE | — | F-0025 | Image rebuilt via Cloud Build to natively include 300_setup-sway-desktop.sh. Old images cleaned up. |

---

## Milestone 4: Auto-Start & Daily Readiness

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0027 | Cloud Scheduler (weekday start/stop) | F-0027 | P0 | done | PE | — | — | Updated by F-0044: ws-weekday-start (6AM Mon-Fri) + ws-weekday-stop (9PM Mon-Fri). Old daily job removed. All 3 projects configured. |
| F-0028 | App update startup script | F-0027 | P0 | done | SWE-1 | — | F-0027, F-0033 | ~/boot/07-apps.sh: Updates Claude Code, Gemini CLI (npm), VSCode, IntelliJ (nix-channel + home-manager switch). Logs to ~/logs/app-update.log. |
| F-0029 | Auto-launch 4 workspaces with apps | F-0027 | P0 | done | SWE-2 | — | F-0025, F-0028, F-0033 | ~/boot/08-workspaces.sh: ws1=foot, ws2=Chrome, ws3=Antigravity, ws4=foot. Discovers SWAYSOCK, waits for Sway ready, idempotent. |
| F-0030 | Install Nerd Fonts (CascadiaCode, FiraCode) | F-0030 | P0 | done | SWE-1 | — | F-0033 | ~/boot/04-fonts.sh: 12 Operator Mono, 168 Cascadia, 19 Fira, 24 Caskaydia fonts installed from ~/boot/fonts/ to ~/.local/share/fonts/. fc-cache rebuilt. |
| F-0031 | ZSH default shell + plugins (no plugin manager) | F-0030 | P0 | done | SWE-2 | — | F-0030, F-0033 | ~/boot/05-shell.sh: exec zsh in .bashrc, plugins via git clone to ~/.zsh/, .zshrc with Nix profile, PATH, history, completions, Starship init. |
| F-0032 | Starship prompt + foot terminal config | F-0030 | P0 | done | SWE-3 | — | F-0030, F-0031, F-0033 | ~/boot/06-prompt.sh: Starship 1.24.2 installed, foot.ini with Operator Mono Book:size=18 and Tokyo Night [colors-dark] theme. |
| F-0033 | Persistent disk bootstrap architecture | F-0033 | P0 | done | PE | — | F-0026 | ~/boot/setup.sh orchestrates 8 sub-scripts (01-nix through 08-workspaces). 000_bootstrap.sh in Docker image delegates to persistent disk. All future changes are disk-only edits. |

---

## Milestone 5: One-Click Setup

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0034 | Launcher script (setup.sh) | F-0034 | P0 | done | SWE-1 | — | — | scripts/setup.sh: Parses -p PROJECT_ID, validates auth, enables Cloud Build, grants SA Owner, submits build async, prints tracking URL |
| F-0035 | Cloud Build setup script | F-0034 | P0 | done | PE | — | F-0034 | scripts/cloud-build-setup.sh: 15-step idempotent setup with retry logic, self-recovery, and built-in verification tests (PASS/FAIL/WARN) |
| F-0036 | Nix + Home Manager install | F-0034 | P0 | done | SWE-2 | — | F-0035 | Integrated into cloud-build-setup.sh steps 9-10: Nix install, persistent disk, Home Manager, all packages |
| F-0037 | Config + AI tools deployment | F-0034 | P0 | done | SWE-3 | — | F-0036 | Integrated into cloud-build-setup.sh steps 11-14: boot scripts, fonts, Sway config, ZSH, Starship, Claude Code, Gemini, Antigravity |
| F-0038 | E2E test of one-click setup | F-0034 | P0 | done | SWE-QA | — | F-0034 thru F-0037 | Tested on gement02 and gement03 from scratch. 33 PASS / 0 FAIL / 0 WARN. Fixed: VPC network, SA permissions, --service-account on config, Nix persistence, webhook URL escaping |

---

## Milestone 6: Multi-Project Hardening

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0039 | Fix setup for fresh GCP projects | — | P0 | done | PE | — | — | Fixed: auto-create VPC network, grant both Cloud Build + Compute SA, add --service-account to config, fix webhook URL escaping |
| F-0040 | Nix store persistence across restarts | — | P0 | done | SWE-1 | — | F-0039 | Added Step 11/17: cp -a /nix /home/user/nix after all installs. Startup script bind-mounts back on boot |
| F-0041 | noVNC desktop connectivity tests | — | P0 | done | SWE-2 | — | F-0040 | Added Step 17/17: verifies Sway running, wayvnc on 5901, noVNC on 80, HTTP accessible |
| F-0042 | Fix Antigravity path (sway config + boot) | — | P0 | done | SWE-1 | — | — | Changed from ~/.antigravity/ to /usr/bin/antigravity (apt-installed). Fixed in sway config, 08-workspaces.sh, and cloud-build-setup.sh |
| F-0043 | Fix swaybar on gement01 | — | P1 | done | SWE-1 | — | — | Deployed current repo sway config (sway-status instead of i3status-rust). Removed outer gaps (0 instead of 12) |
| F-0044 | Weekday-only Cloud Scheduler | — | P1 | done | PE | — | — | ws-weekday-start (6AM Mon-Fri), ws-weekday-stop (9PM Mon-Fri). Off on weekends. All 3 projects configured |
| F-0045 | Fix Antigravity autostart on ws3 | — | P0 | done | SWE-2 | — | F-0042 | 08-workspaces.sh had old path. Changed to /usr/bin/antigravity, timeout 15s→30s. Verified after full stop/start on gement02+03 |
| F-0046 | Consolidated ws.sh setup + teardown | — | P0 | done | SWE-1 | — | F-0039 | Single script for both setup and teardown with webhook + email notifications. 17-step setup with built-in tests |

---

## Future Items

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| | | | | | | | | |

---

## Team Roster

| Role | Agent | Specialty |
|------|-------|-----------|
| PM | PM | Product requirements & PO communication |
| TPM | TPM | Backlog, coordination & progress tracking |
| SWE-1 | SWE-1 | General Engineer 1 |
| SWE-2 | SWE-2 | General Engineer 2 |
| SWE-3 | SWE-3 | General Engineer 3 |
| SWE-Test | SWE-Test | Automated testing & coverage |
| SWE-QA | SWE-QA | E2E testing & QA |
| Platform | Platform Engineer | Infrastructure & deployment |
| Reviewer | Reviewer | Code review & quality |
