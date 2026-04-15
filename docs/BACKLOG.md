# Project Backlog — Cloud Workstation

**Maintained by:** TPM
**Last updated:** 2026-04-15 (Milestone 22 — Xwayland `-rootless` persistence fix: F-0097)

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
| F-0008 | Network and IAM configuration | F-0001 | P0 | done | PE | feature/ws-iam | F-0001 | admin@your-org.example.com has workstations.user. AR reader granted. No public IP, Shielded VM enabled. |
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
| F-0038 | E2E test of one-click setup | F-0034 | P0 | done | SWE-QA | — | F-0034 thru F-0037 | Tested on YOUR_PROJECT_ID and YOUR_PROJECT_ID from scratch. 33 PASS / 0 FAIL / 0 WARN. Fixed: VPC network, SA permissions, --service-account on config, Nix persistence, webhook URL escaping |

---

## Milestone 6: Multi-Project Hardening

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0039 | Fix setup for fresh GCP projects | — | P0 | done | PE | — | — | Fixed: auto-create VPC network, grant both Cloud Build + Compute SA, add --service-account to config, fix webhook URL escaping |
| F-0040 | Nix store persistence across restarts | — | P0 | done | SWE-1 | — | F-0039 | Added Step 11/17: cp -a /nix /home/user/nix after all installs. Startup script bind-mounts back on boot |
| F-0041 | noVNC desktop connectivity tests | — | P0 | done | SWE-2 | — | F-0040 | Added Step 17/17: verifies Sway running, wayvnc on 5901, noVNC on 80, HTTP accessible |
| F-0042 | Fix Antigravity path (sway config + boot) | — | P0 | done | SWE-1 | — | — | Changed from ~/.antigravity/ to /usr/bin/antigravity (apt-installed). Fixed in sway config, 08-workspaces.sh, and cloud-build-setup.sh |
| F-0043 | Fix swaybar on YOUR_PROJECT_ID | — | P1 | done | SWE-1 | — | — | Deployed current repo sway config (sway-status instead of i3status-rust). Removed outer gaps (0 instead of 12) |
| F-0044 | Weekday-only Cloud Scheduler | — | P1 | done | PE | — | — | ws-weekday-start (6AM Mon-Fri), ws-weekday-stop (9PM Mon-Fri). Off on weekends. All 3 projects configured |
| F-0045 | Fix Antigravity autostart on ws3 | — | P0 | done | SWE-2 | — | F-0042 | 08-workspaces.sh had old path. Changed to /usr/bin/antigravity, timeout 15s→30s. Verified after full stop/start on YOUR_PROJECT_ID+03 |
| F-0046 | Consolidated ws.sh setup + teardown | — | P0 | done | SWE-1 | — | F-0039 | Single script for both setup and teardown with webhook + email notifications. 17-step setup with built-in tests |
| F-0047 | Persistent .env sourcing across reboots | — | P0 | done | SWE-1 | — | F-0031 | 05-shell.sh was overwriting .zshrc on every boot (cat >), losing manual edits. Added `source ~/.env` block (with set -a) to the .zshrc template in 05-shell.sh. Fixes Claude Code not working after reboot (missing Vertex AI env vars) |

---

## Milestone 7: Repo Templatization

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0048 | Repo split: private personal + public template | — | P0 | done | SWE-1, SWE-2, SWE-3 | main | — | Pushed personal repo to your-private-repo (private). Templatized 38 files in cloud-workstations (public) with placeholders. Created scripts/configure.sh for colleague onboarding. Updated README with Quick Start + configure step. |
| F-0049 | Remove configure.sh, auto-detect REPO_URL | — | P1 | done | SWE-1 | main | F-0048 | Removed configure.sh (caused dirty git state on 38 files). ws.sh now auto-detects REPO_URL from git remote. README simplified to clone → ws.sh setup. |

---

## Milestone 8: Programming Language Support

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0050 | Language boot script (`07b-languages.sh`) | F-0001-language-support | P0 | done | SWE-1 | feature/languages | F-0033 | Created 07b-languages.sh: Go (tarball), Rust (rustup), Python 3.12 (pyenv), Ruby 3.3 (rbenv). Idempotent — first boot full install, subsequent boots update only. Commit 2f8d437 |
| F-0051 | Language build deps boot script (`07a-lang-deps.sh`) | F-0001-language-support | P0 | done | SWE-1 | feature/languages | F-0033 | Created 07a-lang-deps.sh: apt build-essential, libssl-dev, zlib1g-dev, etc. Uses dpkg -s to skip installed. Commit 2f8d437 |
| F-0052 | Shell integration (PATH for language managers) | F-0001-language-support | P0 | done | SWE-2 | feature/languages | F-0050, F-0031 | Updated 05-shell.sh: added Go (GOROOT, GOPATH), Rust (.cargo/bin), pyenv init, rbenv init to .zshrc. Guarded with command -v checks. Commit e702deb |
| F-0053 | Update cloud-build-setup.sh for first-time language install | F-0001-language-support | P0 | done | SWE-3 | feature/languages | F-0050, F-0051 | Added Step 15/19 (lang deps) and Step 16/19 (lang install + verification). Renumbered to 19 total steps. Commit fbc537b |
| F-0054 | Update README.md with language documentation | F-0001-language-support | P1 | done | SWE-3 | feature/languages | F-0050 | Added Languages row to "What's Included" table + "Language Version Management" section with version switch commands. Commit fbc537b |
| F-0055 | E2E test and verify language installations | F-0001-language-support | P0 | backlog | SWE-Test | — | F-0050, F-0052, F-0053 | Verify go/rustc/cargo/python/ruby on PATH, pyenv install works, gem install works, survives stop/start, tested on 2+ projects |

---

## Milestone 9: Fix IDE Keybindings

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0056 | Fix sway config IDE keybindings (IntelliJ + VSCode) | [F-0035](specs/F-0035-fix-ide-keybindings.md) | P0 | done | SWE-1 | feature/languages | F-0016, F-0017 | Fixed idea-community→idea-oss, added xwayland disable, set DISPLAY=:0 for IntelliJ, wrapped VSCode exec with env -u LD_LIBRARY_PATH. Commit 526ecbb |
| F-0057 | Update boot scripts for idea-oss binary name | [F-0035](specs/F-0035-fix-ide-keybindings.md) | P0 | done | SWE-1 | feature/languages | F-0056 | No idea-community references found in boot scripts — only sway config needed fixing. Commit 526ecbb |
| F-0058 | E2E verify IDE keybindings after fix | [F-0035](specs/F-0035-fix-ide-keybindings.md) | P0 | backlog | SWE-QA | — | F-0056, F-0057 | Pending: verify CTRL+SHIFT+M launches IntelliJ, CTRL+SHIFT+Y launches VSCode, no GL/library errors, tested on 2+ projects |

---

## Milestone 10: UX Polish (Wofi, Clipboard, Snippets, Waybar)

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0059 | Fix Wofi app launcher + categories + Tokyo Night styling | [F-0036](specs/F-0036-milestone-10-ux.md) | P1 | done | SWE-1 | feature/languages | F-0016, F-0017 | Fixed XDG_DATA_DIRS + env -u LD_LIBRARY_PATH in sway config. Created wofi/config + style.css (Tokyo Night). Created boot/09-wofi.sh to deploy configs. Commits e91bc08, ee67545 |
| F-0060 | Fix CTRL+SHIFT+A clipboard history daemon | [F-0036](specs/F-0036-milestone-10-ux.md) | P1 | done | SWE-2 | feature/languages | F-0016 | Wrapped wl-paste + clipman autostart with env -u LD_LIBRARY_PATH, used full Nix paths, fixed clipman pick keybinding. Commit e91bc08 |
| F-0061 | Fix CTRL+SHIFT+S snippet picker (new script) | [F-0036](specs/F-0036-milestone-10-ux.md) | P1 | done | SWE-2 | feature/languages | F-0060 | Created snippet-picker script + snippets.conf (Wofi-based, wl-copy). Created boot/09-snippets.sh (no-clobber on existing config). Commit e91bc08 |
| F-0062 | Switch to Waybar + Apps dropdown | [F-0036](specs/F-0036-milestone-10-ux.md) | P1 | blocked | SWE-3 | feature/languages | F-0016, F-0059 | **Reverted (225aea7):** Waybar uses wlr-layer-shell protocol which doesn't render through wayvnc in headless Sway. Swaybar restored. Waybar config kept in repo for future activation. Apps dropdown needs alternative approach. |
| F-0063 | E2E test and verify Milestone 10 UX features | [F-0036](specs/F-0036-milestone-10-ux.md) | P0 | backlog | SWE-QA | — | F-0059, F-0060, F-0061 | Pending: verify Wofi shows all apps, clipboard daemon running, snippet picker works, no regressions, tested on 2+ projects |
| F-0064 | Fix clipman pick --tool invocation | [F-0036](specs/F-0036-milestone-10-ux.md) | P0 | done | team-lead | feature/languages | F-0060 | clipman --tool expects tool name ('wofi') not full path. Fixed by adding PATH=/home/user/.nix-profile/bin:$PATH. Commit 225aea7 |

---

## Milestone 11: AI CLI Tools Expansion

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0065 | Add OpenCode + Codex CLI to boot scripts | [F-0037](specs/F-0037-ai-cli-tools.md) | P2 | done | SWE-1 | feature/languages | F-0050 (Go required for `go install`) | Added Codex CLI (npm @openai/codex v0.118.0) and OpenCode (go install, v0.0.55) to 07-apps.sh. Both install on first boot and upgrade on every subsequent boot. Commit 97f20fc |

---

## Milestone 12: AI IDEs, CLI Tools, and Timezone Fix

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0066 | Add AI IDEs via Nix Home Manager (Cursor, Windsurf, Zed, Aider) | [F-0038](specs/F-0038-milestone-12-ai-ides-tools-timezone.md) | P1 | done | SWE-1 | feature/languages | F-0017 | Added code-cursor, windsurf, zed-editor to home.nix. aider-chat installed via pip (Nix build fails due to sandbox network restrictions). Cursor 2.6.22, Windsurf 1.108.2, Zed 0.229.0, Aider 0.86.2 verified. Commit 8cade9e |
| F-0067 | Add CLI tools via npm + GitHub Copilot CLI | [F-0038](specs/F-0038-milestone-12-ai-ides-tools-timezone.md) | P1 | done | SWE-1 | feature/languages | F-0018 | Added @sourcegraph/cody and @mariozechner/pi-coding-agent to npm update in 07-apps.sh. Added gh copilot extension install/upgrade. Cody 5.5.26, pi 0.64.0, gh copilot working. Commit 8cade9e |
| F-0068 | Add sway keybindings for Cursor and Windsurf | [F-0038](specs/F-0038-milestone-12-ai-ides-tools-timezone.md) | P1 | done | SWE-1 | feature/languages | F-0056 | Added CTRL+SHIFT+C (Cursor) and CTRL+SHIFT+W (Windsurf) with Electron flags and env -u LD_LIBRARY_PATH. Commit 8cade9e |
| F-0069 | Fix timezone to Pacific Time (TZ=America/Los_Angeles) | [F-0038](specs/F-0038-milestone-12-ai-ides-tools-timezone.md) | P1 | done | SWE-2 | feature/languages | F-0033 | Set TZ=America/Los_Angeles in 03-sway.sh (sway-desktop.service), 05-shell.sh (.zshrc template), and sway-status script. Swaybar now shows Pacific time. Commit 6b16472 |

---

## Milestone 13: Setup Script Hardening & Boot Tests

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0070 | Bulletproof SSH commands in setup script | [F-0039](specs/F-0039-setup-script-sync.md) | P0 | done | SWE-1 | feature/languages | — | Added 5-min timeout to ws_ssh, 15-min ws_ssh_long for Nix/languages. Split Nix install into download+install. Removed silent || true. Commit 842b401 |
| F-0071 | Fix AR race condition in setup | [F-0039](specs/F-0039-setup-script-sync.md) | P0 | done | SWE-1 | feature/languages | F-0070 | Added 30s propagation wait + verification loop after AR creation. Docker push no longer fails with "Repository not found". Commit 0541291 |
| F-0072 | Verified teardown with wait_deleted | [F-0039](specs/F-0039-setup-script-sync.md) | P0 | done | SWE-1 | feature/languages | — | All 9 resources verified deleted: workstation, config, cluster, AR, NAT, router, scheduler, cloud function, cloud builds. Commits e0d216d, 0df6bb7, 71c2f5a, ce95a43 |
| F-0073 | Boot test script (10-tests.sh) | [F-0039](specs/F-0039-setup-script-sync.md) | P0 | done | SWE-2 | feature/languages | — | 80+ tests across 12 categories. Runs via systemd after all services up. Results at ~/logs/boot-test-{results,summary}.txt. Commits e20c0c0, a352760 |
| F-0074 | Unify .zshrc via Home Manager | [F-0039](specs/F-0039-setup-script-sync.md) | P0 | done | SWE-1 | feature/languages | F-0073 | Moved all shell config into programs.zsh.initContent. 05-shell.sh skips .zshrc when Home Manager manages it. Tests check home.nix. Commit 263e7d3 |
| F-0075 | Fix AI tools install in setup script | [F-0039](specs/F-0039-setup-script-sync.md) | P0 | done | SWE-1 | feature/languages | F-0070 | Fixed OpenCode go install, Aider pip install, GH Copilot extension, .env creation. Proper error handling. Commit 6b5fb40 |

---

## Milestone 14: Tailscale, tmux, Persistence

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0076 | Tailscale opt-in via ~/.env | — | P1 | done | SWE-1 | feature/languages | — | 06a-tailscale.sh: auto-install if missing, start daemon, authenticate with authkey, enable SSH, set password, configure iptables. Commits af3be99, 50c4781 |
| F-0077 | tmux Tokyo Night config + claude-tmux wrapper | — | P1 | done | SWE-1 | feature/languages | — | tmux.conf with Tokyo Night theme, mouse, true color. claude-tmux/tmux-debug scripts launch Claude with --dangerously-skip-permissions. t1-t10 aliases. Commits cec0b9f, dfe3691 |
| F-0078 | .gitignore for secrets | — | P0 | done | team-lead | feature/languages | — | Protects .env, *-sa-key.json from accidental commit. Commit ee21791 |
| F-0079 | PII scrub from docs | — | P0 | done | SWE-1 | feature/languages | — | Replaced all personal info (project IDs, emails, names) with placeholders. Commit fd91950 |
| F-0080 | STARTUP_SCRIPTS.md documentation | — | P1 | done | SWE-2 | feature/languages | — | Full documentation of all 14 boot scripts, execution flow, logs, design decisions. Commit 7a9b0e6 |

---

## Milestone 15: Composable Install Profiles

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0081 | Composable install profiles (minimal/dev/ai/full/custom) | [Research](research/composable-install.md) | P1 | done | SWE-1 | feature/composable-install | — | Implemented in 5 phases: --profile flag, ws-modules.sh helper, ~/.ws-modules config, boot script gating, conditional tests. Minimal 14 min vs full 55 min (75% faster). Commits 95cdd38, c10782d, cf68015, 155e265 |
| F-0082 | Dynamic home.nix generation per profile | [Research](research/composable-install.md) | P1 | done | SWE-1 | feature/composable-install | F-0081 | cloud-build-setup.sh generates home.nix with conditional package lists. AI IDEs only for ai/full profiles. Commit d96385e |

---

## Milestone 16: Terminal UX

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0087 | Foot terminal starts in $HOME | — | P2 | done | PO | main | — | Sway bindings ($mod+Return, $mod+t) wrapped with `cd ~ &&` so foot inherits HOME instead of sway's cwd. Test added to 10-tests.sh. |

---

## Milestone 17: Fork Divergence Catch-up (v1.17)

Tracks fork-only work that pre-dated or accompanied v1.17. All items are documented retrospectively so the backlog matches `git log upstream/main..HEAD`.

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0088 | Cloud Build pipeline for workstation image | [F-0088](specs/F-0088-cloud-build-pipeline.md) | P1 | done | PE | main | F-0034 | `cloudbuild/ws-image.yaml` builds + pushes to AR. `_AR_PROJECT` substitution allows differing AR/build projects. Invoked by `ws.sh setup`. Commits 82373e1, aa1fc95 |
| F-0089 | Custom tools module (Terraform, gh, Java, Eclipse, Claude Code) | [F-0089](specs/F-0089-custom-tools-module.md) | P1 | done | SWE-1 | main | F-0033, F-0081 | `workstation-image/boot/11-custom-tools.sh` installs Terraform 1.14.8 + gh 2.89.0 to `~/.local/bin`, Java 21 via SDKMAN, Eclipse, Claude Code to `~/.npm-global`, JetBrains Mono font. Also patches noVNC rfb.js and masks ws-autolaunch. Idempotent. Commits 11fe006, 85f6c56, bea5b61, 33a038b, 0ebd8f3 |
| F-0090 | VNC keyboard compatibility (wayvnc + noVNC + foot) | [F-0090](specs/F-0090-vnc-keyboard-compat.md) | P1 | done | SWE-1 | main | F-0001 | `wayvnc --keyboard=us`, `foot.ini term=xterm-256color`, boot-time patch of noVNC `rfb.js` to disable QEMU extended key events. Commits 493d541, eb2d56c, f0c4e54 |
| F-0091 | Align setup script with deployed GCP Organization configuration | [F-0091](specs/F-0091-gcp-org-alignment.md) | P0 | done | PE | main | F-0034, F-0088 | `cloud-build-setup.sh` rewritten for the deployed configuration: us-central1, main-cluster, sway-config, sway-workstation, dev-workstation:latest, n2-standard-8, 200GB pd-balanced, no GPU, 2h idle, workstations-vpc, sway-workstation-sa, 8PM Central stop. README/SETUP/STARTUP_SCRIPTS updated to match (machine spec + 02-nvidia no-op note). Commits df99d3d, fe29dfe |
| F-0092 | Foot terminal font cleanup (DejaVu Sans Mono single source) | — | P2 | done | SWE-1 | main | — | Switched foot font to DejaVu Sans Mono (system-present), removed Home Manager `programs.foot` double-write that was resolving `font=monospace` to Noto Sans Regular and warning on every launch. Added Nix `cascadia-code`/`fira-code`/`jetbrains-mono` packages so fresh setups get open-source fonts without the Operator Mono tarball path. `cloud-build-setup.sh` only uploads Operator Mono (~264K) via `gcloud ssh -T` to stay under the 300s timeout, with a real OTF count verify. Commits 6fef7ff, f871cd1, 5c714dd, 0aca479, 1639c59 |

---

## Milestone 18: Claude Code Auto-Update Fix

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0093 | Fix Claude Code auto-update (persistent npm prefix) | [F-0093](specs/F-0093-claude-autoupdate-fix.md) | P1 | done | SWE-1 | fix/claude-autoupdate | F-0089 | `install_claude_code` in `11-custom-tools.sh` uses `--prefix` inline only; `npm config get prefix` returns `/usr`, so Claude's in-process auto-updater hits EACCES on `/usr/lib/node_modules`. Fix: idempotently write `prefix=/home/user/.npm-global` to `~/.npmrc` (owned by user). Add boot test in `10-tests.sh` asserting `npm config get prefix`. Apply same fix live on workstation (no live-only changes). |

---

## Milestone 19: Foot Terminal Font Regression

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0094 | Fix foot terminal font regression after reboot | [F-0094](specs/F-0094-foot-font-regression.md) | P0 | done | SWE-1 | fix/foot-font-regression | F-0030, F-0092 | Root cause: stale `~/boot/06-prompt.sh` was writing `font=JetBrains Mono` (not installed on this workstation), so foot fell back to Noto Sans and emitted the "font does not appear to be monospace" warning every launch. Fix (commit 62d90fc): (1) new `workstation-image/configs/foot/foot.ini` is the single source of truth; (2) `06-prompt.sh` now deploys that file to `~/.config/foot/foot.ini` instead of writing its own inline copy; (3) `scripts/cloud-build-setup.sh` step 13 deploys the same `foot.ini` to `~/boot/foot.ini` so fresh project setups pick it up. `fc-cache` ordering verified (already enforced by `04-fonts.sh` before `06-prompt.sh`). Boot test added in `workstation-image/boot/10-tests.sh` asserting `fc-match "<family>"` and `fc-match "<family>:spacing=mono"` resolve to the configured monospace font (not Noto/sans). Live boot-test-summary: 51→53 PASS, 31→30 FAIL. AC4(a) reboot persistence verified. AC4(b) teardown+setup and AC4(c) fresh-project setup end-to-end verification still pending — PO deciding between verify-before-PR vs verify-post-merge vs SWE-QA light verification. `docs/STARTUP_SCRIPTS.md` unchanged (no boot-script purpose/ordering change). |

---

## Milestone 20: Foot Terminal CWD Regression

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0095 | Fix foot terminal CWD regression (third occurrence) | [F-0095](specs/F-0095-foot-cwd-regression.md) | P0 | in-progress | SWE-1 | fix/foot-font-regression | F-0087, F-0094 | Third regression of the same class: newly spawned foot terminals no longer start in `/home/user` — they inherit the launcher's CWD. Previously fixed in `0dd33b3` (`--working-directory=/home/user`) and `e7236a8` (F-0087, `cd ~ &&` guard + 10-tests.sh assertion). Root cause almost certainly a three-places-rule drift between `workstation-image/configs/sway/config`, `~/.config/home-manager/sway-config`, and `scripts/cloud-build-setup.sh` (possibly also repo vs `~/boot/08-workspaces.sh`). SWE must diff all three sources against `0dd33b3` / `e7236a8` before coding and record which hypothesis (H1–H4 in spec) is the real root cause in the commit body. Spec recommends standardizing on `--working-directory=/home/user` (explicit, no shell expansion, same flag works in `08-workspaces.sh` invocations). Must extend `10-tests.sh` with a drift-guard assertion: repo sway config and Home Manager sway-config byte-identical on foot-launch lines, and every `foot` invocation in `08-workspaces.sh` carries the guard — so a fourth regression fails the boot-test summary instead of shipping silently. Acceptance covers reboot, `ws.sh teardown && ws.sh setup`, and fresh-project setup. |

---

## Milestone 21: Xwayland Workspace 1 Split Regression

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0096 | Fix Xwayland root window splitting workspace 1 at boot | [F-0096](specs/F-0096-xwayland-ws1-split.md) | P0 | done (tested + verified) | SWE / SWE-Test-QA | fix/xwayland-ws1-split | F-0027, F-0029, F-0056, F-0073 | **Completed 2026-04-15 (Milestone 21).** Chose Option 2 — added `-rootless` to Xwayland invocation in `workstation-image/boot/08-workspaces.sh` (commit 2cf39b1). Live verification: `swaymsg -t get_tree` shows ws1=foot only (no Xwayland root), ws2=Chrome, ws3=Antigravity, ws4=foot. `ps` confirms `/usr/bin/Xwayland -rootless :0` running; `DISPLAY=:0 xdpyinfo` still returns a working X server. `10-tests.sh` F-0096 section (static grep for `-rootless` + live swaymsg tree check for `app_id=org.freedesktop.Xwayland`) both PASS. Pre-existing 30 FAILs in the test suite are unrelated (AI CLI version probes, missing `.tmux.conf`/`.env`, home.nix pattern checks). AC1–AC3 verified on live workstation; AC4 (reboot / teardown+setup / fresh-project) deferred to deployment. Original: At boot, ws1 tiles two windows side-by-side — the Xwayland root window (`app_id=org.freedesktop.Xwayland`, `name=Xwayland on :0`) on the left and the autostart foot terminal on the right — instead of a single fullscreen foot. Confirmed live via `swaymsg -t get_tree`. Root cause: `workstation-image/boot/08-workspaces.sh:70` runs `sway_cmd exec "/usr/bin/Xwayland :0"`, which starts Xwayland without `-rootless` and tiles its root window onto the active workspace. Three implementation options for the SWE to choose from (documented in the spec): (1) sway `for_window [app_id="org.freedesktop.Xwayland"]` rule to scratchpad/hide the root; (2) add `-rootless` to the Xwayland invocation (recommended — root-cause fix, one-line change); (3) move Xwayland startup into a dedicated systemd user service outside `sway_cmd exec`. Fix must preserve IntelliJ's `DISPLAY=:0` path (F-0056) and add a `10-tests.sh` drift guard asserting no Xwayland root window on any workspace after autostart. Three-places rule applies if both repo and `~/boot/08-workspaces.sh` (plus `scripts/cloud-build-setup.sh` if sway config changes) are touched. Acceptance covers reboot, `ws.sh teardown && ws.sh setup`, and fresh-project setup. |

---

## Milestone 22: Xwayland `-rootless` Persistence Fix (F-0096 Regression)

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0097 | Fix Xwayland `-rootless` flag not persisting after reboot | [F-0097](specs/F-0097-xwayland-rootless-persistence.md) | P0 | in-progress | SWE-1 | fix/xwayland-rootless-persistence | F-0096 | **P0 regression of just-shipped F-0096 (v1.17.1).** After reboot, `pgrep -af Xwayland` shows `/usr/bin/Xwayland :0` — the `-rootless` flag is missing from the running process even though `workstation-image/boot/08-workspaces.sh` and `~/boot/08-workspaces.sh` both contain `sway_cmd exec "/usr/bin/Xwayland -rootless :0"`. Workspace 1 is split 50/50 again. The F-0096 static-grep test still PASSES, so the current test only proves the string is typed into the script, not that the running Xwayland process actually honors it. This is a P0 test-coverage gap as much as a functional regression. SWE must (1) identify why the flag is dropped at runtime (candidates: stale/duplicate Xwayland invocation elsewhere in boot path, sway autostart ordering, a second `exec Xwayland` in sway config or home-manager source, systemd user unit pre-starting Xwayland before `08-workspaces.sh`, `DISPLAY=:0` race with F-0056 IntelliJ path), (2) implement the fix in the correct source-of-truth files, and (3) strengthen `10-tests.sh` so the bad state is detectable — the test must assert the **running** Xwayland process command line contains `-rootless` (e.g., `pgrep -af Xwayland \| grep -- -rootless`) in addition to the existing static grep and sway-tree assertion. Three-places rule applies: repo `workstation-image/boot/08-workspaces.sh`, live `~/boot/08-workspaces.sh`, and `scripts/cloud-build-setup.sh` must all agree. Acceptance covers reboot, `ws.sh teardown && ws.sh setup`, and fresh-project setup — the runtime assertion must PASS in all three. |

---

## Future Items

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0083 | Build speed: skip AR deletion on teardown | [Research](research/build-speed-optimization.md) | P2 | backlog | — | — | — | Keep Docker image in AR across teardown/setup cycles. Saves ~17min. Image is ~280MB, pennies/month. |
| F-0084 | Build speed: faster Cloud Build machine (E2_HIGHCPU_32) | [Research](research/build-speed-optimization.md) | P2 | backlog | — | — | — | Docker builds 2-3x faster. Saves ~8min. |
| F-0085 | Build speed: ws.sh update command (config-only, no rebuild) | [Research](research/build-speed-optimization.md) | P1 | backlog | — | — | — | Push configs + run boot scripts on existing workstation. ~2min vs 50min for config-only changes. |
| F-0086 | Cloud Build tags for Console visibility | [Research](research/build-tags.md) | P2 | backlog | — | — | — | Add --tags to builds so outer (ws-setup) and inner (docker-image) are identifiable in Console. |

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
