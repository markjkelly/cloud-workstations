# Project Backlog — Cloud Workstation

**Maintained by:** TPM
**Last updated:** 2026-03-20

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
| F-0008 | Network and IAM configuration | F-0001 | P0 | done | PE | feature/ws-iam | F-0001 | admin@ameerabbas.altostrat.com has workstations.user. AR reader granted. ameer00@gmail.com pending (API precondition). No public IP, Shielded VM enabled. |
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
| F-0019 | Post-reboot E2E validation | F-0011 | P0 | backlog | SWE-QA | — | F-0013 thru F-0018 | All apps survive stop/start cycle. Nix HM, Sway, all apps, GPU, noVNC. |

---

## Milestone 3: Modern Desktop

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0020 | Modern Sway config (gaps, borders, Tokyo Night) | F-0020 | P1 | done | SWE-1 | — | F-0016 | Deployed to workstation. Tokyo Night theme, 6/12 gaps, smart_gaps, 2px pixel borders, all 33 keybindings preserved. Sway reloaded successfully. |
| F-0021 | Modern swaybar with JSON protocol status | F-0020 | P1 | done | SWE-2 | — | F-0016 | Deployed to workstation. i3bar JSON protocol with color-coded CPU/MEM/DISK/GPU/NET/clock. |
| F-0022 | Waybar config + CSS (future activation) | F-0020 | P2 | done | SWE-2 | — | F-0016 | Deployed to workstation. config.jsonc + style.css ready for when layer-shell works on wayvnc. |
| F-0023 | Comprehensive setup documentation | — | P1 | backlog | SWE-3 | — | F-0020, F-0021 | Full guide for recreating this Cloud Workstation from scratch, usable by humans and AI agents |
| F-0024 | E2E validation of modern desktop | F-0020 | P1 | backlog | SWE-QA | — | F-0020, F-0021, F-0022 | — |

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
