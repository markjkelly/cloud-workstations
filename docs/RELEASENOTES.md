# Release Notes — Cloud Workstation

## v1.21 — noVNC Resolution & Clarity (2026-04-15)

### Added
- **`ws-resolution` helper script** (F-0100) — change display resolution at runtime (`ws-resolution 1920x1080`, `ws-resolution 2560x1440`) with automatic persistence to `~/.config/ws-resolution` and boot-time restore via `08-workspaces.sh`
- **wayvnc quality config** (F-0100) — `~/.config/wayvnc/config` deployed with `quality=9` for maximum JPEG encoding fidelity; deployed by `03-sway.sh` on every boot and by `cloud-build-setup.sh` on fresh project setup
- **noVNC ui.js patch** (F-0100) — `11-custom-tools.sh` patches `/opt/noVNC/app/ui.js` to set JPEG quality=9 and remote-resize mode as browser defaults, so the noVNC client connects at full fidelity without manual Options tuning
- **Boot test assertions** (F-0100) — `10-tests.sh` F-0100 section: ws-resolution on PATH, wayvnc config present, quality=9 verified, noVNC ui.js patches verified, HEADLESS-1 sway output check

---

## v1.17.2 — Xwayland -rootless persistence (2026-04-15)

Patch release covering F-0097. Closes the loop on the F-0096 fix (v1.17.1 /
v1.20) by making the `-rootless` flag survive reboots, and hardens the
boot test so any future regression fails at boot instead of silently
reintroducing the workspace-1 split.

### Fixed
- **Xwayland `-rootless` now persists across reboots** (F-0097) — Xwayland is now started from sway autostart via `xwayland disable` + `exec /usr/bin/Xwayland -rootless :0 &` in `workstation-image/configs/sway/config`, so the flag is present on every boot. Previously the F-0096 fix only applied during the session it was deployed in; after a reboot, sway's default Xwayland launch took over without `-rootless`, silently reintroducing the 50/50 workspace-1 split. See `docs/specs/F-0097-xwayland-rootless-persistence.md`.

### Changed
- **`workstation-image/boot/10-tests.sh` — runtime Xwayland assertion** (F-0097) — the boot test now asserts that the *running* Xwayland process command line contains `-rootless` (reads `/proc/<pid>/cmdline` for the live process), rather than only grepping the static config for the flag. Catches the F-0097 class of regression — correct config on disk but wrong process actually running — that a static grep would miss.

---

## v1.20 — Xwayland ws1 split fix (2026-04-15)

### Fixed
- **Xwayland no longer splits workspace 1** (F-0096) — `workstation-image/boot/08-workspaces.sh` now launches Xwayland with `-rootless`, the standard mode under a Wayland compositor. Previously, rootful Xwayland painted a workspace-sized root window that Sway tiled 50/50 alongside the autostart foot terminal on ws1. With `-rootless`, no phantom root surface is created and ws1 opens to a single fullscreen foot terminal matching ws2/ws3/ws4. See `docs/specs/F-0096-xwayland-ws1-split.md`.

---

## v1.18 — Claude Code Auto-Update Fix (2026-04-15)

Fixes the Claude Code in-process auto-updater so it can write to the
persistent disk instead of failing with `EACCES` on the ephemeral
`/usr/lib/node_modules` path.

See [docs/specs/F-0093-claude-autoupdate-fix.md](specs/F-0093-claude-autoupdate-fix.md).

### Fixed
- **Claude Code auto-updater `EACCES` on `/usr/lib/node_modules`** (F-0093) — the in-process auto-updater no longer fails when Claude tries to self-upgrade. Root cause: `install_claude_code` in `workstation-image/boot/11-custom-tools.sh` passed `--prefix=/home/user/.npm-global` inline only, so `npm config get prefix` still returned `/usr` (the base-image default) and any later `npm -g` invocation — including Claude Code's auto-updater — tried to write to the root-owned ephemeral `/usr/lib/node_modules`. Fix: `install_claude_code` now idempotently writes `prefix=/home/user/.npm-global` to `~/.npmrc`, so every `npm -g` invocation targets the persistent disk

### Added
- **Boot test for npm prefix** — `workstation-image/boot/10-tests.sh` now asserts `npm config get prefix` equals `/home/user/.npm-global`, catching any regression that would silently break the Claude Code auto-updater on future boots

---

## v1.19 — Foot Terminal CWD Regression Drift Guards (2026-04-15)

Third occurrence of the "foot does not start in `/home/user`" class of bug.
The configs were actually correct — the previous F-0087 boot test had
gone stale and was still looking for its own `cd ~ &&` pattern, so a
later drift back to the `--working-directory=/home/user` style (from
`0dd33b3`) passed the test silently instead of failing it. The fix
hardens the boot test into three drift guards so a fourth regression
fails `~/logs/boot-test-summary.txt` on the next boot.

### Fixed
- **Foot terminal CWD regression** (F-0095) — foot now reliably opens
  with `pwd=/home/user` from sway `$mod+Return`, `$mod+t`, and the
  autostart workspace script. Standardized on
  `--working-directory=/home/user` as the single CWD-guard style;
  F-0087's `cd ~ &&` wrapper is superseded. Root cause was a stale
  boot-test assertion, not a config regression — the configs already
  carried the correct flag

### Changed
- **`workstation-image/boot/10-tests.sh` — three R4 drift guards**
  (F-0095) replacing the single F-0087 `cd ~ &&` grep:
  - **R4a** — every sway keybinding that launches foot must carry
    `--working-directory=/home/user` (checks `$mod+Return`, `$mod+t`,
    and any other foot-launching binding in the active
    `~/.config/sway/config`)
  - **R4b** — every `foot` invocation in
    `workstation-image/boot/08-workspaces.sh` must carry the same
    flag; matcher broadened after SWE-Test caught a regex gap where a
    bare `"$FOOT"` at end of line slipped through
  - **R4c** — the repo `workstation-image/configs/sway/config` and
    the deployed `~/.config/home-manager/sway-config` must be
    byte-identical on the lines that launch foot, catching
    three-places-rule drift at boot instead of at the user

### Docs
- **F-0095 spec** — `docs/specs/F-0095-foot-cwd-regression.md`
  captures the regression history (`0dd33b3` → F-0087/`e7236a8` →
  F-0095), the four-hypothesis root-cause framework used during
  diagnosis, and the drift-guard requirement so any future repeat of
  this class is caught automatically

### Verification Status
- **Statically verified:** configs carry the correct flag in all three
  sources (repo / home-manager source / setup script); R4a/R4b/R4c
  assertions compile and run
- **Live-verified on the currently-drifted workstation:** R4 drift
  guards correctly produce a FAIL in
  `~/logs/boot-test-summary.txt` when any of the three sources is
  corrupted — AC3 headline validated
- **Pending live verification:** AC1 (`$mod+Return` → `pwd`), AC2
  (autostart foot windows), AC4(b) (teardown + re-setup on this
  project), AC4(c) (fresh project setup). PO to choose between
  verify-before-PR, verify-post-merge, or an SWE-QA light-verification
  pass before Milestone 20 closes

---

## v1.17 — GCP Organization Alignment, Font Cleanup, Fork Retrospective (2026-04-15)

This release captures the final alignment of the fork with the deployed
GCP Organization environment and cleans up the terminal font stack. It
also adds a retrospective **Fork Divergence Summary** covering fork-only
work that pre-dated the v1.14–v1.16 release notes and had never been
formally documented.

### Added
- **GCP Organization deployment alignment** (F-0091) — `scripts/cloud-build-setup.sh` rewritten to target the live deployed configuration: region `us-central1`, cluster `main-cluster`, config `sway-config`, workstation `sway-workstation`, image `dev-workstation:latest`, dedicated `sway-workstation-sa` service account, custom `workstations-vpc` (10.0.0.0/24), 2h idle timeout, daily 8PM Central stop scheduler
- **Nix-managed open-source fonts** — `cascadia-code`, `fira-code`, and `jetbrains-mono` added to `home.packages` so they are present on fresh setups without a tarball upload

### Changed
- **Machine spec** (F-0090) — documented target is now `n2-standard-8` with 200GB `pd-balanced` and **no GPU**. T4 GPU quota removed as a prerequisite. `02-nvidia.sh` is a documented no-op on this profile. README, SETUP.md, and STARTUP_SCRIPTS.md updated accordingly
- **Font deployment via Cloud Build** — only Operator Mono (~264K) is piped through `gcloud workstations ssh` (previously the full 61MB dev-fonts tarball hit the 300s timeout and silently failed). `--ssh-flag="-T"` added to prevent TTY corruption of binary stdin. Setup verify now does a real OTF count check instead of unconditional `test_pass`, and splits `fonts_operator` / `fonts_cascadia` so each deployment path is checked independently
- **Foot terminal font** — switched to `DejaVu Sans Mono` (confirmed present on the system) as the single source of truth managed only by `06-prompt.sh`. Home Manager no longer manages `foot.ini`, eliminating the double-write that resolved `font=monospace` to the proportional Noto Sans Regular and produced the "non-monospaced font" warning on every terminal open
- **Boot test** — `10-tests.sh` updated to assert the correct configured font

### Fixed
- **Silent font deployment failure** — root cause (tarball too large for SSH timeout) is fixed rather than hidden; the `font-monospace-warn=no` suppression is removed since the real warning is gone

---

## Fork Divergence Summary (retrospective, pre-v1.14)

The following fork-only work shipped in the markjkelly fork before the v1.14
release notes began tracking it. Documented here so the release history is
complete.

### Cloud Build Pipeline (F-0088)
- `cloudbuild/ws-image.yaml` — builds and pushes the workstation Docker image to Artifact Registry via Cloud Build, replacing manual `docker build/push` cycles
- `_AR_PROJECT` substitution so the Artifact Registry project can differ from the build project
- Integrated into the `ws.sh setup` flow so a `git push` + `ws.sh setup` cycle produces a fresh image

### Custom Tools Module (F-0089)
- New boot script `workstation-image/boot/11-custom-tools.sh` installs tools that are either unavailable in Nix or must live on the persistent disk to survive image rebuilds:
  - **Terraform** — pinned version, installed to `~/.local/bin`
  - **GitHub CLI (`gh`)** — pinned version, installed to `~/.local/bin`
  - **Java** — installed via SDKMAN into `$HOME`
  - **Eclipse IDE** — installed to the persistent disk
  - **Claude Code** — installed to `~/.npm-global` on boot
- Auto-launch of workspace apps disabled by default in this module so the user chooses what to start

### VNC Keyboard Compatibility (F-0090)
- `wayvnc --keyboard=us` so key codes are encoded correctly for the browser client
- `term=xterm-256color` added to `foot.ini` for VNC keyboard compatibility
- Boot-time patch of `noVNC`'s `rfb.js` to disable QEMU extended key events (fixes broken special keys in the browser)

### Fonts & Terminal
- JetBrains Mono installed via apt as a persistent boot-time step (later superseded by Nix packages in v1.17)
- Foot terminal non-monospace font warning suppressed (later root-caused and removed in v1.17)

### Docs & Templating
- `GEMINI.md` added with project context and branching/PR conventions for Gemini-driven workflows
- `REPO_URL` placeholder updated to point at the markjkelly fork

---

## v1.16 — Terminal UX (2026-04-15)

### Fixed
- **Foot terminals now open in `$HOME`** — sway bindings (`$mod+Return`, `$mod+t`) previously inherited sway's cwd, causing new terminals to start in whatever directory sway was launched from. Bindings now `cd ~` before exec. Boot test added to `10-tests.sh`.

---

## v1.15 — Composable Install Profiles (2026-04-02)

### Added
- **Install profiles** — choose `minimal`, `dev`, `ai`, `full`, or `custom` profile via `--profile` flag to control what gets installed. Minimal profile builds in ~14 min vs ~55 min for full (75% faster)
- **`--profile` flag** for `ws.sh setup` — selects a predefined set of modules (e.g., `--profile minimal`)
- **`--modules` flag** for `ws.sh setup` — enables individual modules with `--profile custom --modules "ides,ai-tools"`
- **`~/.ws-modules` config file** — records which modules are enabled. Boot scripts and tests automatically adapt to the selected profile
- **`ws-modules.sh` helper** — provides `ws_module_enabled()` function for boot scripts to check whether a module is enabled before running
- **Dynamic `home.nix` generation** — `cloud-build-setup.sh` generates Nix Home Manager config with only the packages needed for the selected profile. AI IDEs (Cursor, Windsurf, Zed, VSCode, IntelliJ) only included for ai/full profiles
- **Conditional boot tests** — `10-tests.sh` reports SKIP for disabled modules instead of FAIL, keeping test results clean and actionable

### Changed
- **`setup.sh`** — boot scripts now check `ws_module_enabled <module>` and skip if their module is disabled
- **`cloud-build-setup.sh`** — language and AI tool install steps gated by profile; `home.nix` generated dynamically

### Fixed
- **`ws-modules.sh` `$HOME` bug** — `$HOME` is empty when sourced by root during Cloud Build setup. Changed to hardcoded `/home/user` path

### Performance
| Profile | Build Time | Tests |
|---------|-----------|-------|
| minimal | ~14 min | 46 PASS, 0 FAIL, 8 SKIP |
| full | ~55 min | 77 PASS, 1 FAIL (false positive), 0 SKIP |

---

## v1.14 — Tailscale, tmux, Persistence (2026-04-02)

### Added
- **Tailscale VPN** — opt-in via `TAILSCALE_AUTHKEY` in `~/.env`. Auto-installs if missing (ephemeral root disk), auto-connects with SSH enabled, configures iptables
- **USER_PASSWORD** — set SSH password via `~/.env` for Tailscale/Termius access, auto-set on boot
- **claude-tmux wrapper** — crash-resistant tmux sessions that auto-launch `claude --dangerously-skip-permissions`. Aliases: `t1`-`t10`, `cc`, `tdbg`
- **tmux-debug** — same as claude-tmux but with server-level logging to `~/logs/tmux/`
- **tmux.conf** — Tokyo Night theme with true color, mouse, vi copy mode, auto-rename windows to current directory
- **Boot script 06b-tmux.sh** — deploys tmux.conf + claude-tmux + tmux-debug on boot
- **.gitignore** — protects `.env`, `*-sa-key.json` from accidental commit

### Fixed
- **PII scrubbed** from all docs (project IDs, emails, names replaced with placeholders)
- **ZSH aliases** — `~/.zsh/zsh_aliases.sh` now sourced in Home Manager initContent (was missing)

### Verified
- Full cycle: teardown 14 min + build 56 min + boot tests 5 min = ~76 min total
- Setup script: 52 PASS, 0 FAIL
- Boot tests: 77 PASS, 0 FAIL (1 false positive WARN)

---

## v1.13 — Setup Script Hardening & Boot Tests (2026-04-01)

### Added
- **Boot test script** (`10-tests.sh`) — 80+ automated tests across 12 categories, runs via systemd after all services up. Results at `~/logs/boot-test-{results,summary}.txt`
- **STARTUP_SCRIPTS.md** — full documentation of all 14 boot scripts, execution flow, logs

### Changed
- **Setup script bulletproofed** — SSH commands have 5-min timeout (15-min for long ops), Nix install split into download+install, silent `|| true` removed
- **AR race condition fixed** — 30s propagation wait + verification loop after Artifact Registry creation
- **Verified teardown** — all 9 resource types have `wait_deleted` polling: workstation, config, cluster, AR, NAT, router, scheduler, cloud function, cloud builds
- **Unified .zshrc** — Home Manager `programs.zsh` is single source of truth; `05-shell.sh` defers when Home Manager manages `.zshrc`
- **10-tests.sh via systemd** — runs after ws-autolaunch.service instead of during setup.sh, preventing false FAILs from services not yet started

### Fixed
- **AI tools install** — OpenCode, Aider, GH Copilot now properly install in setup script with error handling
- **Missing ZSH/Starship** — added to inline home.nix in setup script (was missing `programs.zsh` block)
- **Test false positives** — Zed binary name (`zeditor`), OpenCode version flag, Aider PATH, GH Copilot extension check

---

## v1.12 — AI IDEs, CLI Tools, and Timezone Fix (2026-03-31)

### Added
- **Cursor IDE** (v2.6.22) — AI-powered VSCode fork, installed via Nix Home Manager (`code-cursor`). Sway keybinding: `CTRL+SHIFT+C` with Electron flags and `env -u LD_LIBRARY_PATH` for nvidia compatibility
- **Windsurf IDE** (v1.108.2) — AI-powered VSCode fork, installed via Nix Home Manager (`windsurf`). Sway keybinding: `CTRL+SHIFT+W` with same Electron flags pattern
- **Zed IDE** (v0.229.0) — GPU-accelerated code editor, installed via Nix Home Manager (`zed-editor`). Launched from terminal
- **Aider** (v0.86.2) — AI pair programming CLI tool, installed via pip (Nix build fails due to sandbox network restrictions). Available as `aider` from the terminal
- **Sourcegraph Cody CLI** (v5.5.26) — AI coding assistant CLI, installed via npm global (`@sourcegraph/cody`). Upgrades on every boot
- **pi-coding-agent** (v0.64.0) — AI coding agent CLI, installed via npm global (`@mariozechner/pi-coding-agent`). Upgrades on every boot
- **GitHub Copilot CLI** — `gh copilot` extension installed on first boot, upgraded on subsequent boots. Enables `gh copilot suggest` and `gh copilot explain` commands

### Fixed
- **Timezone consistency** — Set `TZ=America/Los_Angeles` in three locations: `sway-desktop.service` (all sway child processes), `.zshrc` (interactive shells), and `sway-status` (status bar clock). All displays now show Pacific Time instead of UTC

### Changed
- **`home.nix`** — Added `code-cursor`, `windsurf`, and `zed-editor` to Nix Home Manager packages
- **`07-apps.sh`** — Added `@sourcegraph/cody` and `@mariozechner/pi-coding-agent` to npm global update line; added `gh extension install/upgrade gh-copilot` step; added `pip install aider-chat` step
- **`sway/config`** — Added `CTRL+SHIFT+C` (Cursor) and `CTRL+SHIFT+W` (Windsurf) keybindings following the established Electron IDE pattern
- **`03-sway.sh`** — Added `Environment=TZ=America/Los_Angeles` to sway-desktop.service
- **`05-shell.sh`** — Added `export TZ="America/Los_Angeles"` to .zshrc template
- **`sway-status`** — Added `export TZ="America/Los_Angeles"` at top of script

---

## v1.11 — AI CLI Tools Expansion (2026-03-31)

### Added
- **Codex CLI** (`@openai/codex` v0.118.0) — OpenAI's CLI coding assistant, installed via npm global alongside Claude Code and Gemini CLI. Upgrades to latest on every boot
- **OpenCode** (v0.0.55) — Open-source AI coding assistant, installed via `go install` to `$GOPATH/bin` on the persistent disk. Upgrades to latest on every boot

### Changed
- **`07-apps.sh`** — Updated npm global update line to include `@openai/codex` alongside `@anthropic-ai/claude-code` and `@anthropic-ai/gemini-cli`. Added `go install` step for OpenCode with proper GOROOT/GOPATH configuration

### Notes
- Requires Go from Milestone 8 (F-0050) for OpenCode installation
- API key configuration is user-managed (not included in boot scripts)

---

## v1.10 — UX Polish: Wofi, Clipboard, Snippets (2026-04-01)

### Added
- **Wofi app launcher styling** — Created `~/.config/wofi/config` (drun mode, case-insensitive search, app icons) and `~/.config/wofi/style.css` with Tokyo Night theme (bg=#1a1b26, accent=#7aa2f7, text=#c0caf5, rounded corners, modern look)
- **Snippet picker** (`~/.local/bin/snippet-picker`) — Wofi-based script that reads snippets from `~/.config/snippets/snippets.conf` (pipe-delimited `label | value` format), presents labels in a Wofi menu, and copies the selected snippet value to clipboard via `wl-copy`. Invoked with CTRL+SHIFT+S
- **Default snippet config** (`~/.config/snippets/snippets.conf`) — Starter snippets for common text (email, commands, code patterns). User-editable; boot script preserves existing customizations (no-clobber)
- **Boot scripts** — `09-wofi.sh` (deploys wofi config + style), `09-snippets.sh` (deploys snippet picker + default config with no-clobber)

### Fixed
- **Wofi app launcher (CTRL+SHIFT+R)** — Was only showing Antigravity because `XDG_DATA_DIRS` was empty in sway's environment. Fixed by setting `XDG_DATA_DIRS=/home/user/.nix-profile/share:/usr/share:/usr/local/share` and wrapping with `env -u LD_LIBRARY_PATH`. Now shows all Nix-installed and system apps
- **Clipboard history daemon (CTRL+SHIFT+A)** — `wl-paste + clipman store` daemon was not starting due to nvidia `LD_LIBRARY_PATH` conflict breaking Nix binaries. Fixed by wrapping autostart with `env -u LD_LIBRARY_PATH`. Also fixed `clipman pick --tool` invocation: expects tool name (`wofi`) not full path, so added Nix bin to PATH in exec
- **Snippet picker (CTRL+SHIFT+S)** — Keybinding existed but referenced a script (`~/.local/bin/snippet-picker`) that was never created. Script now exists and functions correctly

### Not Shipped
- **Waybar switch** — Attempted replacing swaybar with waybar but reverted: waybar uses wlr-layer-shell protocol which doesn't render through wayvnc in the headless Sway setup. Waybar config preserved in repo for future activation when layer-shell support is available. Swaybar remains the active bar

---

## v1.9 — Fix IDE Keybindings (2026-03-31)

### Fixed
- **IntelliJ keybinding (CTRL+SHIFT+M)** — binary name corrected from `idea-community` to `idea-oss` (matching Nix Home Manager package name). Added `DISPLAY=:0` so IntelliJ connects to system Xwayland instead of broken Nix-packaged Xwayland
- **VSCode keybinding (CTRL+SHIFT+Y)** — wrapped exec with `env -u LD_LIBRARY_PATH` to prevent nvidia's `libGLESv2.so.2` from shadowing the Nix version (was causing `undefined symbol: _glapi_tls_Current` crash)
- **Xwayland startup failure** — added `xwayland disable` to sway config to prevent Sway's built-in Xwayland (Nix binary) from starting under nvidia LD_LIBRARY_PATH, which caused `libX11.so.6: cannot open shared object file`. System Xwayland (`/usr/bin/Xwayland :0`) is launched explicitly instead

### Root Cause
All three bugs shared a common root cause: the nvidia `LD_LIBRARY_PATH=/var/lib/nvidia/lib64` set by `sway-desktop.service` injects nvidia GL libraries into the search path, shadowing Nix-provided libraries and breaking symbol resolution for Nix-built applications (Xwayland, VSCode/Electron). The fix applies per-app workarounds rather than changing the global GPU configuration.

---

## v1.8 — Programming Language Support (2026-03-31)

### Added
- **Go** (latest stable via direct tarball from go.dev) — installs to `~/go` (GOROOT) and `~/gopath` (GOPATH). Auto-detects latest version, updates on boot if newer available
- **Rust** (via `rustup`) — installs stable toolchain to `~/.rustup` and `~/.cargo`. Runs `rustup update` on subsequent boots
- **Python 3.12** (via `pyenv`) — compiles from source, installs to `~/.pyenv`. pyenv updated on boot; Python rebuild only on manual request
- **Ruby 3.3** (via `rbenv` + `ruby-build`) — compiles from source, installs to `~/.rbenv`. rbenv/ruby-build updated on boot; Ruby rebuild only on manual request
- **Boot script `07a-lang-deps.sh`** — installs apt build dependencies (build-essential, libssl-dev, zlib1g-dev, etc.) required by pyenv and rbenv to compile Python/Ruby from source
- **Boot script `07b-languages.sh`** — idempotent language installer. First boot installs all 4 languages (~15 min for Python/Ruby compilation); subsequent boots verify and update version managers in under 30 seconds. Logs to `~/logs/language-install.log`
- **Shell integration** — Go (GOROOT, GOPATH), Rust (~/.cargo/bin), pyenv init, and rbenv init added to `.zshrc` PATH
- **Language version management docs** in README.md — covers installed languages, version managers, and how to install additional versions

### Changed
- **`cloud-build-setup.sh`** — expanded from 17 to 19 steps: Step 18 installs language build deps + version managers, Step 19 verifies all language binaries on PATH
- **`setup.sh`** — updated glob pattern to support letter-suffixed boot scripts (`07a-*`, `07b-*`) in execution order

### Architecture
- **Hybrid approach**: Nix continues to manage system tools (ripgrep, neovim, tmux, VS Code, etc.), while native version managers handle programming languages for multi-version support and familiar developer workflows
- **No /nix copy needed**: All language managers install entirely within `$HOME` on the 500GB persistent SSD, surviving reboots naturally
- **Apt build deps are ephemeral**: Reinstalled on every boot by `07a-lang-deps.sh` since the Docker image is ephemeral; keeps the Docker image lean

---

## v1.7 — Repo Templatization (2026-03-26)

### Added
- **`scripts/configure.sh`** — Onboarding script for colleagues. Prompts for 7 values (GCP project, org, name, email, GitHub), validates inputs, and applies sed replacements across all config files
- **README Quick Start** — Added 3-step quick start section and configure.sh step in setup flow
- **Private repo backup** — Personal repo with all project-specific values pushed to `your-private-repo` (private)

### Changed
- **Templatized 38 files** — Replaced all personal/org-specific info with generic placeholders (`YOUR_PROJECT_ID`, `your-email@example.com`, etc.) across CLAUDE.md, agent configs, skill configs, setup docs, specs, and scripts
- **Public repo is now shareable** — Any colleague can clone, run configure.sh, and deploy their own workstation

### Fixed
- **Persistent `.env` sourcing** — `05-shell.sh` was overwriting `.zshrc` on every boot, losing `source ~/.env`. Added env sourcing to the `.zshrc` template so Claude Code Vertex AI config survives reboots

---

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
- **Swaybar after reboot** — deployed current sway config to YOUR_PROJECT_ID (was using old i3status-rust config)
- **Window sizing** — removed outer gaps (12px → 0) for edge-to-edge windows
- **Webhook URL escaping** — array-based substitution building handles `&` characters in Google Chat webhook URLs
- **Cloud Logging visibility** — grants Logs Writer role to build SA so build logs appear

### Verified
- YOUR_PROJECT_ID: 33 PASS / 0 FAIL + 25/25 post-setup tests
- YOUR_PROJECT_ID: 33 PASS / 0 FAIL + 25/25 post-setup tests
- All 3 projects (YOUR_PROJECT_ID/02/03) have working schedulers and identical configurations

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
- IAM: admin@your-org.example.com has workstations.user access

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

Build a Cloud Workstation in GCP Project ID YOUR_PROJECT_ID with Google Antigravity installed (antigravity.google) following the blog at this link https://medium.com/google-cloud/running-antigravity-on-a-browser-tab-6298bb7e47c4. The Cloud Workstation machine should have a GPU and 64GB RAM as well as 500GB SSD drive. The 500GB SSD drive is a persistent disk with HOME folder mounted to it. All apps must be installed inside the peristent disk. The main docker image should be minimal so all changes, app installs persist inside the persistent disk. For OS, I prefer NixOS with Nix package manager. Follow the blog for what to install and ask questions as necessary

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
