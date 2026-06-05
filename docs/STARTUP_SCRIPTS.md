# Cloud Workstation — Startup Scripts

Summary of all boot scripts that run on every workstation start. Scripts execute in numerical order via `~/boot/setup.sh`, which is called by the Docker entrypoint's `250_bootstrap.sh`.

## Boot Sequence

| Order | Script | Purpose | Idempotent | Time |
|-------|--------|---------|------------|------|
| 1 | `01-nix.sh` | Restore Nix bind mount from persistent disk to `/nix` | Yes — checks if mounted | ~5s |
| 2 | `02-nvidia.sh` | GPU driver setup (ldconfig, PATH for nvidia-smi) — no-ops if no GPU present | Yes — overwrites profile | ~2s |
| 3 | `03-sway.sh` | Create sway-desktop, wayvnc, ws-autolaunch systemd services | Yes — overwrites services | ~3s |
| 4 | `04-fonts.sh` | Install Operator Mono OTFs from `~/boot/fonts/` (open-source fonts come via Nix) | Yes — copies + fc-cache | ~5s |
| 5 | `05-shell.sh` | ZSH default shell, plugins (syntax-highlighting, autosuggestions), generate `.zshrc` | Yes — guarded append, overwrite | ~3s |
| 6 | `09-sync.sh` | **Sync boot scripts + sway config from git repo** (F-0108). Runs `git pull --ff-only` in repo, copies `workstation-image/boot/*.sh` to `~/boot/`, copies `workstation-image/configs/sway/config` to `~/.config/home-manager/sway-config`. Logs to `~/logs/sync.log`. Graceful failure if repo missing or pull fails (boot continues). | Yes — idempotent copies | ~2s (pull + copies) |
| 6 | `06-prompt.sh` | Install Starship prompt; deploy foot terminal config by copying `~/boot/foot.ini` (source of truth: `workstation-image/configs/foot/foot.ini`, deployed by `cloud-build-setup.sh` step 13) into `~/.config/foot/foot.ini`, with an embedded heredoc fallback if `~/boot/foot.ini` is missing (F-0094) | Yes — overwrites configs | ~5s |
| 6a | `06a-tailscale.sh` | Tailscale VPN (opt-in via `TAILSCALE_AUTHKEY` in `~/.env`). Starts tailscaled, authenticates, enables SSH, configures SSH password auth, adds iptables rule for SSH on tailscale0 | Yes — checks running/connected | ~5s |
| 6b | `06b-tmux.sh` | Deploy `tmux.conf` (Tokyo Night theme), `claude-tmux`, and `tmux-debug` scripts | Yes — copy overwrite | ~1s |
| 7 | `07-apps.sh` | **F-0123:** Now runs via `ws-app-updates.service` (After=user@1000.service), NOT via setup.sh. Upgrade AI tools (npm: Claude Code, Codex, Cody, Pi; go: OpenCode; pip: Aider; gh: Copilot), run `home-manager switch`; install/update Antigravity Hub and CLI; **F-0125**: remove orphaned IDE dirs (`~/.config/Antigravity`, `~/.config/Antigravity.bak.*`, `~/.antigravity`, `~/.cache/antigravity`). Logs to `~/logs/app-update.log`. | Yes — update/switch idempotent; dir removal is rm -rf (idempotent) | ~60s |
| 8 | `07a-lang-deps.sh` | Install apt build dependencies for language compilers (build-essential, libssl-dev, etc.) | Yes — dpkg -s check | ~10s |
| 9 | `07b-languages.sh` | Install/update Go (tarball), Rust (rustup), Python (pyenv), Ruby (rbenv) | Yes — existence checks | First: ~15min, subsequent: ~30s |
| 10 | `09-wofi.sh` | Deploy wofi config + Tokyo Night style.css to `~/.config/wofi/` | Yes — copy overwrite | ~1s |
| 11 | `09-snippets.sh` | Deploy snippet-picker script + default snippets.conf (no-clobber) | Yes — cp -n for user config | ~1s |
| 12 | `11-custom-tools.sh` | Fork-only (F-0089): installs Terraform + gh CLI to `~/.local/bin` (pinned), Java LTS via SDKMAN, Eclipse, Claude Code to `~/.npm-global` (with `~/.npmrc` pinning `prefix` so auto-update doesn't EACCES on `/usr`), JetBrains Mono font. Also patches noVNC `rfb.js` (QEMU key events) and masks `ws-autolaunch.service` | Yes — version/existence guarded | First: ~5min, subsequent: ~10s |

**Note:** `07-apps.sh`, `08-workspaces.sh`, and `10-tests.sh` are NOT run by setup.sh — they run via systemd services. `07-apps.sh` runs via `ws-app-updates.service` (After=user@1000.service) so the user session is guaranteed ready. `08-workspaces.sh` and `10-tests.sh` run after Sway starts. See below.

## Execution Flow

```
Docker entrypoint
  └── /etc/workstation-startup.d/250_bootstrap.sh
        └── ~/boot/setup.sh
              ├── 01-nix.sh
              ├── 02-nvidia.sh
              ├── 03-sway.sh  ← also creates ws-app-updates.service + enables linger
              ├── 04-fonts.sh
              ├── 05-shell.sh
              ├── 09-sync.sh (NEW: F-0108)
              ├── 06-prompt.sh
              ├── 06a-tailscale.sh
              ├── 06b-tmux.sh
              │   (07-apps.sh SKIPPED — runs via ws-app-updates.service below)
              ├── 07a-lang-deps.sh
              ├── 07b-languages.sh
              ├── 09-wofi.sh
              ├── 09-snippets.sh
              └── 11-custom-tools.sh

systemd (F-0123: after user@1000.service is active)
  └── ws-app-updates.service  (After=user@1000.service network-online.target)
        └── 07-apps.sh (npm globals, home-manager switch, Hub/CLI install)
              → logs to ~/logs/app-update.log

systemd (after Sway starts)
  ├── ws-autolaunch.service
  │     └── 08-workspaces.sh (launches apps; Xwayland is started
  │         by the sway config's `exec /usr/bin/Xwayland -rootless :0`
  │         autostart — 08-workspaces.sh only re-launches if that
  │         is somehow absent — see F-0097)
  │         F-0124/F-0131 workspace layout: ws1 = empty (Hub NOT auto-launched),
  │         ws2 = VS Code (auto-started via sway exec + for_window placement rule — F-0131),
  │         ws3 = foot terminal, ws4 = foot terminal, ws5 = Chrome.
  │         Boot no longer launches the Hub (F-0124). Workspace 1 starts
  │         empty. The user runs hub-restart (F-0122) after connecting to
  │         launch the Hub — this always works reliably.
  │         VS Code autostart is implemented in the sway config (exec directive
  │         in the AUTOSTART section + for_window placement rule), NOT via
  │         ws-autolaunch.service (which is masked by 11-custom-tools.sh).
  │         Launch order: Chrome (ws5) first, foot (ws3, ws4) last.
  │         Final focus: ws3 (terminal — ready to run hub-restart).
  │         Chrome uses --disable-gpu (no GPU on this host — F-0111).
  │         F-0116 Hub placement rule (sway config): the
  │         for_window [app_id="^antigravity-ide$"] → ws1 rule (F-0136) and for_window [app_id="^antigravity$"] → ws5 rule for Hub
  │         F-0115: gnome-keyring-daemon is started with empty-password
  │         unlock (--unlock --components=secrets) BEFORE any app launch
  │         so the Hub's language_server can persist and reload its OAuth
  │         token via the Secret Service API. DBUS_SESSION_BUS_ADDRESS is
  │         exported to all launched app processes. Startup is idempotent
  │         (pgrep guard); missing binary logs WARNING and boot continues.
  │         Requires /usr/bin/gnome-keyring-daemon (present in base image).
  │         F-0117/F-0118/F-0119/F-0120/F-0121-PartB: all Hub autostart
  │         machinery (retry loop, readiness check, diagnostic sampler,
  │         LS capture shim installer, user-session gate) REMOVED in
  │         F-0124. The real language_server ELF was restored on the live
  │         disk (mv language_server.real language_server).
  └── ws-boot-tests.service (After=ws-autolaunch, 30s delay)
        └── 10-tests.sh (run ~190 verification tests)
```

## Logs

| File | Content |
|------|---------|
| `~/logs/hub-launch.log` | Hub launch output — written by `hub-restart` (F-0122) and any manual Hub invocation. Was also written by 08-workspaces.sh at boot prior to F-0124. Boot no longer writes this file. |
| `~/logs/language_server_boot_diag.log` | **REMOVED in F-0124.** Was written by F-0117 retry loop on failed launch attempts. Boot no longer launches the Hub, so this log is no longer written. |
| `~/logs/hub-ls-diag.log` | **REMOVED in F-0124.** Was written by the F-0118 background diagnostic sampler during every Hub launch window. Boot no longer launches the Hub, so this log is no longer written. |
| `~/logs/ls-spawn.log` | **REMOVED in F-0124.** Was written by the F-0119 LS capture shim (spawn/exit records). Shim removed and live binary restored to real ELF. |
| `~/logs/ls-spawn.out` | **REMOVED in F-0124.** Was written by the F-0119 LS capture shim (raw LS stdout). |
| `~/logs/ls-spawn.err` | **REMOVED in F-0124.** Was written by the F-0119 LS capture shim (raw LS stderr). |
| `~/logs/sync.log` | 09-sync.sh output (git pull, boot script sync, sway config sync) |
| `~/logs/app-update.log` | 07-apps.sh output (npm updates, home-manager switch) |
| `~/logs/language-install.log` | 07b-languages.sh output (Go, Rust, Python, Ruby) |
| `~/logs/boot-test-results.txt` | Full test results (~190 PASS/FAIL/WARN checks) |
| `~/logs/boot-test-summary.txt` | One-line summary: `PASS: X | FAIL: Y | WARN: Z` |
| `~/.tmux.conf` | tmux config (Tokyo Night theme, deployed by 06b-tmux.sh) |
| `~/.tailscale/tailscaled.state` | Tailscale VPN state (persisted on persistent disk, created by 06a-tailscale.sh) |
| `~/logs/custom-tools.log` | 11-custom-tools.sh output (Terraform/gh/Java/Eclipse/Claude Code install + noVNC patch) |

## Module Gating (Composable Install)

Boot scripts are gated by the composable install module system. The `~/.ws-modules` config file records which modules are enabled (set by `ws.sh setup --profile <profile>`). Each boot script sources `ws-modules.sh` and calls `ws_module_enabled <module>` to check if it should run. If its module is disabled, the script exits early with a log message and the boot test script (`10-tests.sh`) reports SKIP instead of FAIL.

| Module | Scripts Gated | Profiles |
|--------|--------------|----------|
| `core` | 01-nix, 02-nvidia, 03-sway, 04-fonts, 05-shell, 06-prompt | All (always enabled) |
| `desktop` | 09-wofi, 09-snippets | All except minimal |
| `ides` | IDE packages in home.nix | ai, full |
| `ai-tools` | 07-apps (AI tool install section) | dev, ai, full |
| `languages` | 07a-lang-deps, 07b-languages | full |
| `tailscale` | 06a-tailscale | full |
| `tmux` | 06b-tmux | dev, ai, full |

## User Tools (~/.local/bin)

Scripts deployed to `~/.local/bin/` by `cloud-build-setup.sh` (persisted to the persistent disk; survive reboot and fresh-project setup).

| Tool | Source in Repo | Purpose |
|------|---------------|---------|
| `antigravity-hub` | installed by `07-apps.sh` (tarball) | Symlink to the Antigravity Hub Electron binary |
| `sway-status` | `workstation-image/configs/swaybar/sway-status` | swaybar status line (clock, battery, etc.) |
| `snippet-picker` | `workstation-image/scripts/snippet-picker` | Wofi-based snippet launcher (desktop module) |
| `claude-tmux` | `workstation-image/scripts/claude-tmux` | Open a named tmux window with Claude Code (tmux module) |
| `tmux-debug` | `workstation-image/scripts/tmux-debug` | tmux session diagnostics (tmux module) |
| `hub-restart` | `workstation-image/scripts/hub-restart` | (F-0122) Manually (re)launch the Antigravity Hub onto ws1 — kills any stuck Hub, clears Singleton lock, relaunches from user session, polls for language_server readiness. Workaround for the cold-boot blank-ws1 failure. |

## Key Design Decisions

1. **All scripts are idempotent** — safe to run multiple times. No duplicate entries, no state corruption.
2. **Persistent disk** — all installs go to `$HOME` on the persistent disk. The Docker image is ephemeral; only `~/boot/` scripts and configs persist.
3. **Home Manager manages Nix apps** — `07-apps.sh` runs `nix-channel --update && home-manager switch` to upgrade all Nix-managed tools (IDEs, dev tools, Sway ecosystem).
4. **npm manages AI CLI tools** — Claude Code, Codex, Cody, Pi installed globally to `~/.npm-global/`.
5. **Native version managers for languages** — Go (tarball), Rust (rustup), Python (pyenv), Ruby (rbenv) for multi-version support.
6. **No-clobber for user configs** — `snippets.conf` and `.zshrc.local` are never overwritten, preserving user customizations.
7. **Test on every boot** — `10-tests.sh` runs ~190 checks and saves results for the PO to review.
