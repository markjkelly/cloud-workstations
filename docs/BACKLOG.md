# Project Backlog — Cloud Workstation

**Maintained by:** TPM
**Last updated:** 2026-06-02 (TPM bookkeeping — reconcile stale F-0106/F-0107 Hub rows)

---

## How to Read This Backlog

- **ID:** Unique feature identifier (`F-0001`, `F-0002`, etc.) — sequential across all milestones, never reused
- **Priority:** P0 (critical path), P1 (important), P2 (nice to have)
- **Status:** `backlog` | `in-progress` | `in-review` | `done` | `blocked` | `superseded`
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

## Milestone 16: Antigravity CLI and Auto-Upgrade

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0088 | Initialize Antigravity CLI via curl installer | [F-0040](specs/F-0040-antigravity-2-cli.md) | P1 | done | SWE-1 | main | F-0087 | Implemented idempotent curl install in `workstation-image/boot/07-apps.sh`. Initializes `~/.gemini/antigravity-cli/` config directory. Re-runs on every boot to check for updates. Command: `curl -fsSL https://antigravity.google/cli/install.sh \| bash`. Logs to `$LOG_FILE`. |
| F-0089 | Add apt auto-upgrade for antigravity in boot scripts | [F-0040](specs/F-0040-antigravity-2-cli.md) | P1 | done | — | — | F-0087 | Added to 07-apps.sh: `sudo apt-get install -y --only-upgrade antigravity` runs on every boot. Verified on live workstation: upgraded from 1.22.2 to 1.23.2. No image rebuild needed. |
| F-0090 | Update sway config: keybindings for Antigravity desktop + CLI | [F-0040](specs/F-0040-antigravity-2-cli.md) | P1 | done | SWE-2 | main | F-0087 | Updated `workstation-image/configs/sway/config`: `$mod+g` launches CLI (`/usr/bin/antigravity` no flags), `$mod+n` launches desktop app (same binary, keybinding invocation). Both use same `/usr/bin/antigravity` binary — no separate CLI binary. |
| F-0091 | Update 08-workspaces.sh: workspace 3 auto-launch desktop | [F-0040](specs/F-0040-antigravity-2-cli.md) | P1 | done | SWE-2 | main | F-0089, F-0090 | Updated `workstation-image/boot/08-workspaces.sh` workspace 3 comment to reference Antigravity desktop app. Binary path `/usr/bin/antigravity` confirmed correct, timeout 30s retained. Single binary, different invocation mode. |
| F-0092 | Update 10-tests.sh: boot tests for Antigravity binary + CLI config | [F-0040](specs/F-0040-antigravity-2-cli.md) | P1 | done | SWE-2 | main | F-0088, F-0091 | Added two new tests to `workstation-image/boot/10-tests.sh`: verify Antigravity binary at `/usr/bin/antigravity`, verify CLI config at `~/.gemini/antigravity-cli/` (curl installer creates this directory). |
| F-0099 | Update cloud-build-setup.sh: Antigravity CLI in fresh provisioning | [F-0040](specs/F-0040-antigravity-2-cli.md) | P1 | done | SWE-3 | main | F-0088, F-0089 | Updated `scripts/cloud-build-setup.sh`: added Antigravity CLI curl install during fresh provisioning. Verification step checks for `/usr/bin/antigravity` binary (apt package). |
| F-0100 | CLI binary discovery via PATH | [F-0040](specs/F-0040-antigravity-2-cli.md) | P1 | done | SWE-3 | main | F-0088 | Verified `~/.local/bin` already in PATH in `workstation-image/boot/05-shell.sh` — curl installer places CLI artifacts in `~/.gemini/antigravity-cli/` (not a separate PATH-discoverable binary). No PATH change needed. |

---

## Milestone 17: Fork Divergence Catch-up (v1.17)

Tracks fork-only work that pre-dated or accompanied v1.17. All items are documented retrospectively so the backlog matches `git log upstream/main..HEAD`.

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0093 | Cloud Build pipeline for workstation image | [F-0093](specs/F-0088-cloud-build-pipeline.md) | P1 | done | PE | main | F-0034 | `cloudbuild/ws-image.yaml` builds + pushes to AR. `_AR_PROJECT` substitution allows differing AR/build projects. Invoked by `ws.sh setup`. Commits 82373e1, aa1fc95 |
| F-0094 | Custom tools module (Terraform, gh, Java, Eclipse, Claude Code) | [F-0094](specs/F-0089-custom-tools-module.md) | P1 | done | SWE-1 | main | F-0033, F-0081 | `workstation-image/boot/11-custom-tools.sh` installs Terraform 1.14.8 + gh 2.89.0 to `~/.local/bin`, Java 21 via SDKMAN, Eclipse, Claude Code to `~/.npm-global`, JetBrains Mono font. Also patches noVNC rfb.js and masks ws-autolaunch. Idempotent. Commits 11fe006, 85f6c56, bea5b61, 33a038b, 0ebd8f3 |
| F-0095 | VNC keyboard compatibility (wayvnc + noVNC + foot) | [F-0095](specs/F-0090-vnc-keyboard-compat.md) | P1 | done | SWE-1 | main | F-0001 | `wayvnc --keyboard=us`, `foot.ini term=xterm-256color`, boot-time patch of noVNC `rfb.js` to disable QEMU extended key events. Commits 493d541, eb2d56c, f0c4e54 |
| F-0096 | Align setup script with deployed GCP Organization configuration | [F-0096](specs/F-0091-gcp-org-alignment.md) | P0 | done | PE | main | F-0034, F-0093 | `cloud-build-setup.sh` rewritten for the deployed configuration: us-central1, main-cluster, sway-config, sway-workstation, dev-workstation:latest, n2-standard-8, 200GB pd-balanced, no GPU, 2h idle, workstations-vpc, sway-workstation-sa, 8PM Central stop. README/SETUP/STARTUP_SCRIPTS updated to match (machine spec + 02-nvidia no-op note). Commits df99d3d, fe29dfe |
| F-0097 | Foot terminal font cleanup (DejaVu Sans Mono single source) | — | P2 | done | SWE-1 | main | — | Switched foot font to DejaVu Sans Mono (system-present), removed Home Manager `programs.foot` double-write that was resolving `font=monospace` to Noto Sans Regular and warning on every launch. Added Nix `cascadia-code`/`fira-code`/`jetbrains-mono` packages so fresh setups get open-source fonts without the Operator Mono tarball path. `cloud-build-setup.sh` only uploads Operator Mono (~264K) via `gcloud ssh -T` to stay under the 300s timeout, with a real OTF count verify. Commits 6fef7ff, f871cd1, 5c714dd, 0aca479, 1639c59 |

---

## Milestone 18: Claude Code Auto-Update Fix

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0101 | Fix Claude Code auto-update (persistent npm prefix) | [F-0101](specs/F-0093-claude-autoupdate-fix.md) | P1 | done | SWE-1 | fix/claude-autoupdate | F-0094 | `install_claude_code` in `11-custom-tools.sh` uses `--prefix` inline only; `npm config get prefix` returns `/usr`, so Claude's in-process auto-updater hits EACCES on `/usr/lib/node_modules`. Fix: idempotently write `prefix=/home/user/.npm-global` to `~/.npmrc` (owned by user). Add boot test in `10-tests.sh` asserting `npm config get prefix`. Apply same fix live on workstation (no live-only changes). |

---

## Milestone 19: Foot Terminal Font Regression

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0102 | Fix foot terminal font regression after reboot | [F-0102](specs/F-0094-foot-font-regression.md) | P0 | done | SWE-1 | fix/foot-font-regression | F-0030, F-0097 | Root cause: stale `~/boot/06-prompt.sh` was writing `font=JetBrains Mono` (not installed on this workstation), so foot fell back to Noto Sans and emitted the "font does not appear to be monospace" warning every launch. Fix (commit 62d90fc): (1) new `workstation-image/configs/foot/foot.ini` is the single source of truth; (2) `06-prompt.sh` now deploys that file to `~/.config/foot/foot.ini` instead of writing its own inline copy; (3) `scripts/cloud-build-setup.sh` step 13 deploys the same `foot.ini` to `~/boot/foot.ini` so fresh project setups pick it up. `fc-cache` ordering verified (already enforced by `04-fonts.sh` before `06-prompt.sh`). Boot test added in `workstation-image/boot/10-tests.sh` asserting `fc-match "<family>"` and `fc-match "<family>:spacing=mono"` resolve to the configured monospace font (not Noto/sans). Live boot-test-summary: 51→53 PASS, 31→30 FAIL. AC4(a) reboot persistence verified. AC4(b) teardown+setup and AC4(c) fresh-project setup end-to-end verification still pending — PO deciding between verify-before-PR vs verify-post-merge vs SWE-QA light verification. `docs/STARTUP_SCRIPTS.md` unchanged (no boot-script purpose/ordering change). |

---

## Milestone 20: Foot Terminal CWD Regression

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0103 | Fix foot terminal CWD regression (third occurrence) | [F-0103](specs/F-0095-foot-cwd-regression.md) | P0 | done | SWE-1 | fix/foot-font-regression | F-0087, F-0102 | **Closed as duplicate of F-0095.** The fix (`--working-directory=/home/user`) is already present in all three required sources: `workstation-image/configs/sway/config:94-95` (keybindings), `~/.config/home-manager/sway-config:94-95` (byte-identical to repo), and `workstation-image/boot/08-workspaces.sh:173,176` (ws3 and ws4 autostart). Verified against commit `0dd33b3` which standardized the flag; shipped in v1.18 via PR #9 (`fix/foot-cwd-regression-f0095`). The drift-guard tests this row asked for already exist: R4a (sway keybinding grep), R4b (every `08-workspaces.sh` foot invocation carries the flag), and R4c (byte-level repo-vs-home-manager diff) at `workstation-image/boot/10-tests.sh:473-515`. A fourth regression will be caught by the boot-test summary rather than shipping silently. No code changes needed. See F-0095 for the canonical fix history. |

---

## Milestone 21: Xwayland Workspace 1 Split Regression

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0104 | Fix Xwayland root window splitting workspace 1 at boot | [F-0104](specs/F-0096-xwayland-ws1-split.md) | P0 | done (tested + verified) | SWE / SWE-Test-QA | fix/xwayland-ws1-split | F-0027, F-0029, F-0056, F-0073 | **Completed 2026-04-15 (Milestone 21).** Chose Option 2 — added `-rootless` to Xwayland invocation in `workstation-image/boot/08-workspaces.sh` (commit 2cf39b1). Live verification: `swaymsg -t get_tree` shows ws1=foot only (no Xwayland root), ws2=Chrome, ws3=Antigravity, ws4=foot. `ps` confirms `/usr/bin/Xwayland -rootless :0` running; `DISPLAY=:0 xdpyinfo` still returns a working X server. `10-tests.sh` F-0096 section (static grep for `-rootless` + live swaymsg tree check for `app_id=org.freedesktop.Xwayland`) both PASS. Pre-existing 30 FAILs in the test suite are unrelated (AI CLI version probes, missing `.tmux.conf`/`.env`, home.nix pattern checks). AC1–AC3 verified on live workstation; AC4 (reboot / teardown+setup / fresh-project) deferred to deployment. Original: At boot, ws1 tiles two windows side-by-side — the Xwayland root window (`app_id=org.freedesktop.Xwayland`, `name=Xwayland on :0`) on the left and the autostart foot terminal on the right — instead of a single fullscreen foot. Confirmed live via `swaymsg -t get_tree`. Root cause: `workstation-image/boot/08-workspaces.sh:70` runs `sway_cmd exec "/usr/bin/Xwayland :0"`, which starts Xwayland without `-rootless` and tiles its root window onto the active workspace. Three implementation options for the SWE to choose from (documented in the spec): (1) sway `for_window [app_id="org.freedesktop.Xwayland"]` rule to scratchpad/hide the root; (2) add `-rootless` to the Xwayland invocation (recommended — root-cause fix, one-line change); (3) move Xwayland startup into a dedicated systemd user service outside `sway_cmd exec`. Fix must preserve IntelliJ's `DISPLAY=:0` path (F-0056) and add a `10-tests.sh` drift guard asserting no Xwayland root window on any workspace after autostart. Three-places rule applies if both repo and `~/boot/08-workspaces.sh` (plus `scripts/cloud-build-setup.sh` if sway config changes) are touched. Acceptance covers reboot, `ws.sh teardown && ws.sh setup`, and fresh-project setup. |

---

## Milestone 22: Automatic Boot Script Sync

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0108 | Automatic boot script sync from git repo | [F-0108](specs/F-0108-boot-sync-from-repo.md) | P1 | done | SWE-1 | feature/boot-sync-from-repo | F-0033, F-0025 | New `06-sync.sh` runs at boot (order 6, before 06-prompt.sh) to pull latest repo and sync boot scripts + sway config. Graceful error handling: git pull failures don't fail boot, repo missing is logged as warning. Logs all operations to ~/logs/sync.log. Tests added to 10-tests.sh verify script exists, repo path is correct, log file created. STARTUP_SCRIPTS.md updated with 06-sync.sh entry. Bootstrap procedure: user manually copies script to ~/boot/ on first deployment; thereafter auto-syncs. |

---

## Milestone 23: Boot Sync SSH Authentication Fix

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0109 | Fix SSH authentication in boot sync script | [F-0109](specs/F-0109-sync-ssh-auth.md) | P0 | done | SWE-1 | feature/fix-sync-ssh-auth | F-0108 | Boot sync runs as root but git pull failed due to missing SSH key. Added `GIT_SSH_COMMAND` pointing to user's `id_ed25519` key with `StrictHostKeyChecking=accept-new`. Test added to `10-tests.sh`. Fixes silent auth failures on every boot. |

---

## Milestone 24: Xwayland `-rootless` Persistence Fix (F-0096 Regression)

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0105 | Fix Xwayland `-rootless` flag not persisting after reboot | [F-0105](specs/F-0097-xwayland-rootless-persistence.md) | P0 | done | SWE-1 | fix/xwayland-rootless-persistence | F-0104 | **Completed 2026-04-15 (PR #11 merged, commit 399408b).** Root cause: `08-workspaces.sh` ran only on first boot via `ws-autolaunch`, but on subsequent boots sway's autostart started Xwayland without `-rootless`. Fix: moved `exec /usr/bin/Xwayland -rootless :0 &` plus `xwayland disable` into sway autostart (home-manager `sway-config` line 228). Live verification: running process is `/usr/bin/Xwayland -rootless :0`. `10-tests.sh` strengthened with runtime `pgrep` assertion so a regression fails boot tests instead of shipping silently. Original: **P0 regression of just-shipped F-0096 (v1.17.1).** After reboot, `pgrep -af Xwayland` shows `/usr/bin/Xwayland :0` — the `-rootless` flag is missing from the running process even though `workstation-image/boot/08-workspaces.sh` and `~/boot/08-workspaces.sh` both contain `sway_cmd exec "/usr/bin/Xwayland -rootless :0"`. Workspace 1 is split 50/50 again. The F-0096 static-grep test still PASSES, so the current test only proves the string is typed into the script, not that the running Xwayland process actually honors it. This is a P0 test-coverage gap as much as a functional regression. SWE must (1) identify why the flag is dropped at runtime (candidates: stale/duplicate Xwayland invocation elsewhere in boot path, sway autostart ordering, a second `exec Xwayland` in sway config or home-manager source, systemd user unit pre-starting Xwayland before `08-workspaces.sh`, `DISPLAY=:0` race with F-0056 IntelliJ path), (2) implement the fix in the correct source-of-truth files, and (3) strengthen `10-tests.sh` so the bad state is detectable — the test must assert the **running** Xwayland process command line contains `-rootless` (e.g., `pgrep -af Xwayland \| grep -- -rootless`) in addition to the existing static grep and sway-tree assertion. Three-places rule applies: repo `workstation-image/boot/08-workspaces.sh`, live `~/boot/08-workspaces.sh`, and `scripts/cloud-build-setup.sh` must all agree. Acceptance covers reboot, `ws.sh teardown && ws.sh setup`, and fresh-project setup — the runtime assertion must PASS in all three. |

---

## Milestone 23: Antigravity 2.0 Desktop App

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0106 | Install Antigravity 2.0 Desktop App (Hub) | [F-0106](specs/F-0106-antigravity-hub-desktop-app.md) | P1 | superseded | SWE-1 | feature/antigravity-hub-desktop-app | F-0087, F-0088 | **Implementation complete.** `07-apps.sh` downloads v2.0.10 from GCS, extracts to `~/.local/share/antigravity-hub/`, creates symlink at `~/.local/bin/antigravity-hub`. Sway config: `$mod+h` launches with Electron flags. Boot tests added for directory, symlink, and keybinding. **Note:** Home Manager sway-config at `~/.config/home-manager/sway-config` must be manually synced when deployed to live workstations (three-places rule). **⚠ SUPERSEDED by F-0124 (2026-06-02):** Hub autostart machinery removed across F-0124. The Hub binary install in `07-apps.sh` is retained (Hub is still usable via `hub-restart`), but the goal of boot auto-launching Hub was abandoned after F-0107 through F-0121 never achieved reliable cold-boot startup. See F-0124 for the removal decision. |
| F-0107 | Add Antigravity Hub as workspace 5 auto-launch | [F-0107](specs/F-0107-antigravity-hub-workspace.md) | P1 | superseded | SWE-1 | feature/antigravity-hub-workspace | F-0106 | Auto-launch Hub in ws5 on boot, fix `$mod+h` keybinding conflict (was both exec + workspace), fix ws2 Antigravity IDE GPU flag (--use-gl=swiftshader instead of --disable-gpu). Implement in 08-workspaces.sh, sway config, cloud-build-setup.sh. Add test guard for keybinding uniqueness. **⚠ SUPERSEDED by F-0124/F-0125 (2026-06-02):** Hub workspace auto-launch (and all subsequent autostart attempts F-0110–F-0121) never achieved reliable cold-boot startup. PO chose to remove all Hub autostart machinery in F-0124. Boot now starts ws1 empty; user runs `hub-restart` after connecting. The workspace-5 assignment was itself swapped by F-0112 (Hub moved to ws1) and later removed by F-0124. |

---

## Milestone 25: Hub WS5 Auth-Friendly Launch

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0110 | Hub WS5 auth-friendly launch (90s timeout, conditional ws1 focus, stderr capture) | [F-0110](specs/F-0110-hub-ws5-auth-friendly-launch.md) | P1 | done | SWE-1 | feature/hub-ws5-auth-friendly-launch | F-0107 | Bumps Hub timeout 30s→90s; leaves focus on ws5 if Hub timed out so OAuth window is visible; captures Hub stdout+stderr to ~/logs/hub-launch.log with per-boot timestamp header. 3 boot tests added; false-positive test fixed. All other workspace timeouts unchanged. bash -n PASS. **⚠ SUPERSEDED by F-0124: Hub autostart removed from boot; hub-launch.log no longer written at boot.** |

---

## Milestone 26: Hub GPU-Less Fix

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0111 | Disable GPU and fix Hub user-data-dir for GPU-less workstation | [F-0111](specs/F-0111-disable-gpu-hub-user-data-dir.md) | P0 | done | SWE-1 | feature/disable-gpu-hub-fix | F-0110 | Two bugs fixed: (1) `--use-gl=swiftshader` replaced with `--disable-gpu` for IDE (ws2) and Hub (ws5) — swiftshader still launched a GPU child process that crashed in a loop on this GPU-less host; (2) `--user-data-dir=/home/user/.config/Antigravity-Hub` added to Hub — without it, Hub defaulted to `~/.config/Antigravity` (same as IDE), Electron SingletonLock let IDE win, Hub had no window. Also added `--disable-gpu` to Chrome (ws1) for consistency. Live validated: Hub window appeared on ws5 within 15s, no GPU process crash errors in log. `bash -n` PASS. 4 new tests + negative check added to `10-tests.sh`. Three-places rule applied. |
| F-0112 | Swap Chrome and Hub workspace assignments | [F-0112](specs/F-0112-swap-chrome-hub-workspaces.md) | P1 | done | SWE-1 | feature/swap-chrome-hub | F-0110, F-0111 | Chrome moved ws1 → ws5; Hub moved ws5 → ws1. Hub is now the default landing workspace. Launch order updated: Chrome first (fast, needed for IDE/Hub OAuth), then Hub (ws1, 90s timeout), then IDE (ws2), then foot terminals (ws3, ws4). All F-0110/F-0111 flags/timeouts/log-redirect travel with the Hub to ws1. End-of-boot focus always lands on ws1 (Hub) — both success and timeout paths call `sway_cmd "workspace number 1"`. `10-tests.sh` updated: Hub ws1 90s test, ws1=Hub, ws5=Chrome assertions, F-0098 order tests replaced with F-0112 layout tests. `bash -n` PASS. Three-places rule applied (~/boot/08-workspaces.sh and ~/boot/10-tests.sh synced). |

---

## Milestone 28: Remap Workspace Keybindings After Chrome/Hub Swap

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0113 | Remap workspace keybindings after Chrome/Hub swap | [F-0113](specs/F-0113-remap-workspace-keys.md) | P1 | done | SWE-1 | feature/remap-workspace-keys | F-0112 | Fixed mnemonic mismatch introduced by F-0112: `$mod+h` now switches to ws1 (Hub), `$mod+u` now switches to ws5 (Chrome). Move-container bindings ($mod+Alt+h → ws1, $mod+Alt+u → ws5) updated to match. Applied to all three locations: repo sway config, `~/.config/home-manager/sway-config`, and `~/.config/sway/config` (live). `swaymsg reload` confirmed success (SWAYSOCK=/run/user/1000/sway-ipc.1000.3430.sock). `10-tests.sh` updated: old F-0107 test (mod+h → ws5) replaced with F-0113 test (mod+h → ws1); new tests for mod+u → ws5 and both Alt+move bindings. `docs/specs/sway-keybindings.md` cheat sheet updated. `~/boot/10-tests.sh` synced live. `scripts/cloud-build-setup.sh` deploys via cat pipe from repo — no inline edit needed. |
| F-0114 | Hub stale singleton lock cleanup before launch | [F-0114](specs/F-0114-hub-stale-lock-cleanup.md) | P0 | done | SWE-1 | feature/hub-stale-lock-cleanup | F-0111, F-0112 | Fixed Hub blank-ws1 wedge after unclean shutdown. Root cause: stale `SingletonLock/Cookie/Socket` in `~/.config/Antigravity-Hub/` plus orphaned Hub/language_server processes prevent Electron from mapping a BrowserWindow. Added pre-launch cleanup block to `08-workspaces.sh`: safe pgrep-based process reaping (filtered by exe/cmdline, NOT broad `pkill -f`), `rm -f .../Singleton*`, and a log message. `10-tests.sh` extended with 5 new checks (4 positive grep, 1 negative pkill-f guard). `~/boot/08-workspaces.sh` and `~/boot/10-tests.sh` synced live. `scripts/cloud-build-setup.sh` deploys boot dir via tar — no change needed. **⚠ SUPERSEDED by F-0124: pre-launch stale-Hub reaping removed (only needed because boot launched the Hub).** |

---

## Milestone 30: Hub Keyring Secret Service for OAuth Token Persistence

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0115 | Keyring Secret Service for Hub OAuth token persistence | [F-0115](specs/F-0115-keyring-auth-persistence.md) | P0 | done | SWE-1 | feature/keyring-auth-persistence | F-0110, F-0114 | Root cause confirmed: no Secret Service provider in headless Sway session; Hub language_server fails to persist/reload OAuth token (`failed to unlock correct collection '/org/freedesktop/secrets/aliases/default'`). Fix: (1) added `DBUS_ADDR="unix:path=/run/user/1000/bus"` constant; (2) idempotent block starts `gnome-keyring-daemon --unlock --components=secrets` with empty password before first `launch_and_wait` call; (3) `DBUS_SESSION_BUS_ADDRESS` added to app-launch env in `launch_and_wait`. Guard on binary existence (log WARNING + continue if missing). 4 new grep-based tests in `10-tests.sh` (--unlock, --components=secrets, DBUS_SESSION_BUS_ADDRESS, pgrep guard). `~/boot/08-workspaces.sh` and `~/boot/10-tests.sh` synced live. `scripts/cloud-build-setup.sh` deploys boot dir via tar — no change needed. `docs/STARTUP_SCRIPTS.md` updated. |

---

## Milestone 31: Remove Antigravity IDE and Fix Hub ws1 Placement

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0116 | Remove Antigravity IDE and fix Hub window placement on workspace 1 | [F-0116](specs/F-0116-remove-antigravity-ide-hub-ws1-fix.md) | P0 | done | SWE-1 | feature/remove-antigravity-ide | F-0112, F-0115 | Root cause: Hub and IDE both report `app_id="antigravity"` to sway; Hub BrowserWindow maps asynchronously after `language_server` starts, landing on whichever workspace has focus at that point (not ws1). `--class=antigravity-hub` does not change the Electron app_id on the installed build. Fix: (1) removed Antigravity IDE from Dockerfile, `07-apps.sh`, `08-workspaces.sh`, sway keybindings (`$mod+n`, `$mod+g`), and `scripts/cloud-build-setup.sh`; (2) added `for_window [app_id="antigravity"] move container to workspace number 1` to sway config — now unambiguous since IDE is gone. Three-places persistence rule satisfied: repo sway config, `~/.config/home-manager/sway-config`, and live `~/.config/sway/config` all updated; `swaymsg reload` confirmed. `~/boot/08-workspaces.sh`, `~/boot/07-apps.sh`, `~/boot/10-tests.sh` synced live. `10-tests.sh`: removed IDE-presence assertions, added IDE-absent assertion, Hub placement rule assertion, removed-keybindings assertion, ws2-empty assertion. Live validation confirmed: Hub relaunched while focus on ws3, `for_window` rule moved window to ws1 (verified via `swaymsg -t get_tree`). |

---

## Milestone 32: Hub Boot Resilience

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0117 | Hub boot resilience: readiness-based wait, retry, and instrumentation | [F-0117](specs/F-0117-hub-boot-resilience.md) | P0 | done | SWE-1 | feature/hub-boot-resilience | F-0114, F-0115, F-0116 | Root cause: language_server intermittently fails to reach "listening" at cold boot; `launch_and_wait` waits only for a sway window, so a renderer-less Hub sits alive but invisible and is never retried. Fix: (1) readiness-based wait — poll language_server HTTPS port in LISTEN state (via `/proc/<pid>/net/tcp6`) in addition to sway window; (2) retry loop up to `HUB_MAX_RETRIES=3` — on failure kill stale processes + clear Singleton*, relaunch, log each attempt; (3) named constants `HUB_LAUNCH_TIMEOUT` and `HUB_MAX_RETRIES`; (4) instrumentation log `~/logs/language_server_boot_diag.log` capturing boot environment and retry timeline. Sway `for_window` rule (F-0116) preserved. Boot-script-only fix; PO can test by rebooting. `~/boot/08-workspaces.sh` and `~/boot/10-tests.sh` synced live. `docs/STARTUP_SCRIPTS.md` updated. **⚠ SUPERSEDED and REMOVED by F-0124: entire retry loop, readiness check, and instrumentation constants removed from 08-workspaces.sh.** |

---

## Milestone 33: Hub LS Boot Diagnostics

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0118 | Hub language_server boot diagnostics: thorough sampler instrumentation | [F-0118](specs/F-0118-hub-ls-boot-diagnostics.md) | P0 | done | SWE-1 | feature/hub-ls-boot-diagnostics | F-0117 | Root cause of blank ws1 confirmed: F-0117's `hub_language_server_ready()` is a guaranteed false positive (reads shared-namespace `/proc/net/tcp6`, sees host-wide LISTEN sockets, returns "ready" immediately). The real LS bind failure is invisible — LS dies before writing its log and the Hub swallows its stderr. F-0118 adds a background diagnostic sampler that runs during the full Hub launch window, capturing per-sample: LS pid/state/disappearance, LS-owned LISTEN sockets via correct inode→fd matching (not shared-namespace), Hub-reported port, live curl/tcp probes, renderer count, DNS/network readiness, LS log file locations, and LS fd/1+fd/2 targets. Diagnostic only — no launch behavior change. Implemented, tested (9 new boot tests), verified, `~/boot/08-workspaces.sh` synced live. **⚠ SUPERSEDED and REMOVED by F-0124: _f0118_ls_diag_sampler() and all related constants removed from 08-workspaces.sh.** |

---

## Milestone 34: Hub LS Spawn Capture Shim

**Last updated:** 2026-05-29 (Milestone 34 — Hub LS spawn capture shim)

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0119 | Hub language_server spawn capture shim | [F-0119](specs/F-0119-hub-ls-spawn-capture.md) | P0 | done | SWE-1 | feature/hub-ls-spawn-capture | F-0118 | Shim installed between Hub and real LS binary. Tees LS stdout → `~/logs/ls-spawn.out` and stderr → `~/logs/ls-spawn.err`; writes spawn/exit records to `~/logs/ls-spawn.log`. Both streams passed through UNMODIFIED so Hub port-discovery works. Install function `_f0119_install_ls_shim()` added to `08-workspaces.sh`, called before Hub launch. Idempotent (marker-based detection). SIGTERM/SIGINT forwarded to real child. Warm-path verified: `ls-spawn.out` (211 bytes) and `ls-spawn.err` (1806 bytes) received content; `hub-launch.log` showed `Port changed!` confirming Hub launched successfully. `~/boot/08-workspaces.sh` and `~/boot/10-tests.sh` synced live. Diagnostic only — no launch behavior change. F-0120 will use the captured evidence to implement a fix. **⚠ SUPERSEDED and REMOVED by F-0124: _f0119_install_ls_shim() removed from 08-workspaces.sh; live shim restored to real ELF binary.** |

---

## Milestone 35: Hub LS Shim Env-Capture + PATH Repair

**Last updated:** 2026-05-29 (Milestone 35 — Hub LS shim env-capture + PATH repair)

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0120 | Hub LS shim: capture Hub child-spawn env + repair PATH in shim | [F-0120](specs/F-0120-hub-ls-shim-env-capture-repair.md) | P0 | done | SWE-1 | feature/hub-ls-shim-env-capture-repair | F-0119 | Shim upgraded: (1) shebang `#!/bin/bash` (absolute — runs under empty PATH), (2) env capture to `~/logs/ls-spawn.env` before any repair (timestamp, pid, args, raw PATH, full env dump), (3) PATH repaired to `/usr/bin:/bin:/usr/local/bin${PATH:+:$PATH}` and HOME set if empty. Idempotent upgrade: detects F-0119 shim (no `# F-0120` marker) and rewrites in-place; `.real` untouched. Passthrough unchanged (port-discovery safe). 8 new tests in `10-tests.sh`. Three-places parity verified (diff clean). Live shim installed immediately. Validation-on-reboot pending PO merge + reboot. **⚠ SUPERSEDED and REMOVED by F-0124: shim installer removed from 08-workspaces.sh; live shim restored to real ELF binary.** |
| F-0121 | Gate boot scripts on user-session readiness (fix silent app-update failures; address Hub cold-boot first-spawn race) | [F-0121](specs/F-0121-user-session-readiness-gate.md) | P0 | done | SWE-1 | feature/user-session-readiness-gate | F-0117, F-0120 | **Implemented, tested, verified (2026-05-29).** Root cause confirmed: `07-apps.sh` runs at boot+32s; `user@1000.service` only comes up at boot+115s — every `runuser` failed silently. Fix Part A: `wait_for_user_session` helper (120s timeout, fail-open) added to `07-apps.sh`; all update steps now check exit status and log real PASS/FAIL. Fix Part B: same helper added to `08-workspaces.sh` after Sway-ready and before gnome-keyring/Hub launch; fail-open with elapsed-time log. 9 static tests added to `10-tests.sh` (all 9 pass). Three-places rule: repo + `~/boot/` synced (diff clean), `cloud-build-setup.sh` unchanged (deploys boot dir via tarball). Part B (blank-ws1 cold-boot fix) validation-on-reboot pending PO merge + reboot. **⚠ Part B (08-workspaces.sh) SUPERSEDED and REMOVED by F-0124. Part A (07-apps.sh) KEPT.** |

---

## Milestone 37: hub-restart manual Hub-relaunch utility

**Last updated:** 2026-05-29 (Milestone 37 — hub-restart manual Hub-relaunch utility)

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0122 | hub-restart — manual Hub-relaunch utility (repo + setup persistence) | [F-0122](specs/F-0122-hub-restart-utility.md) | P1 | done | SWE-1 | feature/hub-restart-utility | F-0121 | **Implemented, tested, verified (2026-05-29).** Script captured verbatim from live `~/.local/bin/hub-restart` into `workstation-image/scripts/hub-restart` (diff clean). Wired into `cloud-build-setup.sh` (unconditional, after sway-status deploy). Three-places rule: repo has script, live copy byte-identical, setup installs it. 3 new tests in `10-tests.sh` (file exists, executable, on PATH). `docs/STARTUP_SCRIPTS.md` updated with new User Tools table. |

---

## Milestone 39: Antigravity IDE cleanup

**Last updated:** 2026-05-29 (Milestone 39 — Antigravity IDE cleanup: F-0125)

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0125 | Clean up orphaned Antigravity IDE remnants (~/.config/Antigravity, ~/.antigravity, etc.) and remove dead sway for_window rule | [F-0125](specs/F-0125-antigravity-ide-cleanup.md) | P2 | done | SWE-1 | feature/antigravity-ide-cleanup | F-0116, F-0124 | **Implemented, tested, verified (2026-05-29).** Added idempotent F-0125 cleanup block to `07-apps.sh` (removes `~/.config/Antigravity`, `~/.config/Antigravity.bak.*`, `~/.antigravity`, `~/.cache/antigravity` via `runuser`; explicit guards prevent touching Hub/CLI dirs). Removed dead `for_window [app_id="antigravity"]` rule + F-0116 comment block from all three sway config locations: repo `workstation-image/configs/sway/config`, `~/.config/home-manager/sway-config` (diff clean), and `scripts/cloud-build-setup.sh` deploys from repo so no separate change needed. `10-tests.sh`: removed stale F-0116 Hub-placement-rule positive-presence test; added 7 new tests (4 orphaned-dir absent, 2 over-deletion guards, 1 dead-rule absent). bash -n PASS both scripts. `~/boot/07-apps.sh` and `~/boot/10-tests.sh` synced live (diff clean). Live dir cleanup will run on next boot. Live sway config: home-manager source updated; `home-manager switch` not run mid-session to avoid disrupting running Sway — takes effect on next boot. |

---

## Future Items

| ID | Feature | Spec | Priority | Status | Owner | Branch | Dependencies | Feedback |
|----|---------|------|----------|--------|-------|--------|--------------|----------|
| F-0083 | Build speed: skip AR deletion on teardown | [Research](research/build-speed-optimization.md) | P2 | backlog | — | — | — | Keep Docker image in AR across teardown/setup cycles. Saves ~17min. Image is ~280MB, pennies/month. |
| F-0084 | Build speed: faster Cloud Build machine (E2_HIGHCPU_32) | [Research](research/build-speed-optimization.md) | P2 | backlog | — | — | — | Docker builds 2-3x faster. Saves ~8min. |
| F-0085 | Build speed: ws.sh update command (config-only, no rebuild) | [Research](research/build-speed-optimization.md) | P1 | backlog | — | — | — | Push configs + run boot scripts on existing workstation. ~2min vs 50min for config-only changes. |
| F-0086 | Cloud Build tags for Console visibility | [Research](research/build-tags.md) | P2 | backlog | — | — | — | Add --tags to builds so outer (ws-setup) and inner (docker-image) are identifiable in Console. |
| F-0123 | 07-apps user-session wait timeout (120s) too short — app updates skipped on slow boots | — | P2 | backlog | — | — | F-0121 | **Bug (F-0121 follow-up).** `07-apps.sh` runs at ~boot+34s but `user@1000.service` start is highly variable (observed boot+115s and boot+203s). F-0121's `wait_for_user_session` uses a 120s timeout, so on a slow boot (203s) it gives up ~49s early, logs `WARNING — user session NOT ready after 120s; skipping`, and ALL app updates are skipped (npm globals, Antigravity CLI, Copilot, OpenCode, home-manager). Logging is now honest (no false "complete"), but updates still don't run. Fix options: (1) raise timeout to ~300s (one-line stopgap); (2) **robust** — run app-updates from a user systemd unit ordered after `user@1000` / gate the setup.sh step on `systemctl is-active user@1000.service`, removing the race. AC: on a boot with user@1000 at +200s+, app-update.log shows "User session ready after Ns" then real per-step OK — not SKIPPED. |
| F-0124 | Remove Hub autostart machinery (boot no longer launches the Hub; hub-restart is the supported path) | [F-0124](specs/F-0124-remove-hub-autostart.md) | P0 | done | SWE-1 | feature/remove-hub-autostart | F-0121, F-0122 | **Implemented, tested, verified (2026-05-29).** Decision: Hub autostart attempted across F-0110–F-0121 never made reliable. PO chose Option A: strip all autostart machinery; boot starts ws1 empty; user runs hub-restart (F-0122) after connecting. Removed from 08-workspaces.sh: Hub launch block (runuser antigravity-hub), F-0117 retry loop + readiness check (hub_language_server_ready), F-0118 diagnostic sampler (_f0118_ls_diag_sampler), F-0119/F-0120 LS shim installer (_f0119_install_ls_shim), F-0114 stale-Hub reaper, F-0121 Part B (wait_for_user_session). Kept: F-0115 gnome-keyring, F-0116 for_window rule, Chrome ws5, foot ws3/ws4, all helpers. Final focus changed to ws3 (terminal). Live binary restored: language_server was bash shim (F-0119/F-0120); `mv language_server.real language_server` + chmod +x — confirmed ELF, no .real remains. Tests: removed 30+ stale tests (F-0117/F-0118/F-0119/F-0120/F-0121-PartB); added 7 regression tests (Hub not launched, dead functions absent, shim not present). bash -n PASS both files. ~/boot/ synced (diff clean). cloud-build-setup.sh unchanged (deploys via tar). 08-workspaces.sh: 1079 → 181 lines (-898 lines). |

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
