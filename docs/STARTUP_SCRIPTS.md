# Cloud Workstation — Startup Scripts

Summary of all boot scripts that run on every workstation start. Scripts execute in numerical order via `~/boot/setup.sh`, which is called by the Docker entrypoint's `000_bootstrap.sh`.

## Boot Sequence

| Order | Script | Purpose | Idempotent | Time |
|-------|--------|---------|------------|------|
| 1 | `01-nix.sh` | Restore Nix bind mount from persistent disk to `/nix` | Yes — checks if mounted | ~5s |
| 2 | `02-nvidia.sh` | GPU driver setup (ldconfig, PATH for nvidia-smi) — no-ops if no GPU present | Yes — overwrites profile | ~2s |
| 3 | `03-sway.sh` | Create sway-desktop, wayvnc, ws-autolaunch systemd services | Yes — overwrites services | ~3s |
| 4 | `04-fonts.sh` | Install Operator Mono OTFs from `~/boot/fonts/` (open-source fonts come via Nix) | Yes — copies + fc-cache | ~5s |
| 5 | `05-shell.sh` | ZSH default shell, plugins (syntax-highlighting, autosuggestions), generate `.zshrc` | Yes — guarded append, overwrite | ~3s |
| 6 | `06-sync.sh` | **Sync boot scripts + sway config from git repo** (F-0108). Runs `git pull --ff-only` in repo, copies `workstation-image/boot/*.sh` to `~/boot/`, copies `workstation-image/configs/sway/config` to `~/.config/home-manager/sway-config`. Logs to `~/logs/sync.log`. Graceful failure if repo missing or pull fails (boot continues). | Yes — idempotent copies | ~2s (pull + copies) |
| 6 | `06-prompt.sh` | Install Starship prompt; deploy foot terminal config by copying `~/boot/foot.ini` (source of truth: `workstation-image/configs/foot/foot.ini`, deployed by `cloud-build-setup.sh` step 13) into `~/.config/foot/foot.ini`, with an embedded heredoc fallback if `~/boot/foot.ini` is missing (F-0094) | Yes — overwrites configs | ~5s |
| 6a | `06a-tailscale.sh` | Tailscale VPN (opt-in via `TAILSCALE_AUTHKEY` in `~/.env`). Starts tailscaled, authenticates, enables SSH, configures SSH password auth, adds iptables rule for SSH on tailscale0 | Yes — checks running/connected | ~5s |
| 6b | `06b-tmux.sh` | Deploy `tmux.conf` (Tokyo Night theme), `claude-tmux`, and `tmux-debug` scripts | Yes — copy overwrite | ~1s |
| 7 | `07-apps.sh` | Upgrade AI tools (npm: Claude Code, Codex, Cody, Pi; go: OpenCode; pip: Aider; gh: Copilot), run `home-manager switch` | Yes — update/switch idempotent | ~60s |
| 8 | `07a-lang-deps.sh` | Install apt build dependencies for language compilers (build-essential, libssl-dev, etc.) | Yes — dpkg -s check | ~10s |
| 9 | `07b-languages.sh` | Install/update Go (tarball), Rust (rustup), Python (pyenv), Ruby (rbenv) | Yes — existence checks | First: ~15min, subsequent: ~30s |
| 10 | `09-wofi.sh` | Deploy wofi config + Tokyo Night style.css to `~/.config/wofi/` | Yes — copy overwrite | ~1s |
| 11 | `09-snippets.sh` | Deploy snippet-picker script + default snippets.conf (no-clobber) | Yes — cp -n for user config | ~1s |
| 12 | `11-custom-tools.sh` | Fork-only (F-0089): installs Terraform + gh CLI to `~/.local/bin` (pinned), Java LTS via SDKMAN, Eclipse, Claude Code to `~/.npm-global` (with `~/.npmrc` pinning `prefix` so auto-update doesn't EACCES on `/usr`), JetBrains Mono font. Also patches noVNC `rfb.js` (QEMU key events) and masks `ws-autolaunch.service` | Yes — version/existence guarded | First: ~5min, subsequent: ~10s |

**Note:** `08-workspaces.sh` and `10-tests.sh` are NOT run by setup.sh — they run via systemd services after Sway starts. See below.

## Execution Flow

```
Docker entrypoint
  └── /etc/workstation-startup.d/000_bootstrap.sh
        └── ~/boot/setup.sh
              ├── 01-nix.sh
              ├── 02-nvidia.sh
              ├── 03-sway.sh
              ├── 04-fonts.sh
              ├── 05-shell.sh
              ├── 06-sync.sh (NEW: F-0108)
              ├── 06-prompt.sh
              ├── 06a-tailscale.sh
              ├── 06b-tmux.sh
              ├── 07-apps.sh
              ├── 07a-lang-deps.sh
              ├── 07b-languages.sh
              ├── 09-wofi.sh
              ├── 09-snippets.sh
              └── 11-custom-tools.sh

systemd (after Sway starts)
  ├── ws-autolaunch.service
  │     └── 08-workspaces.sh (launches apps; Xwayland is started
  │         by the sway config's `exec /usr/bin/Xwayland -rootless :0`
  │         autostart — 08-workspaces.sh only re-launches if that
  │         is somehow absent — see F-0097)
  │         F-0116 workspace layout: ws1 = Hub, ws2 = empty (Antigravity
  │         IDE removed in F-0116), ws3 = foot, ws4 = foot, ws5 = Chrome.
  │         Hub is the default landing workspace; Chrome is a background
  │         OAuth helper on ws5.
  │         Launch order: Chrome (ws5) first, Hub (ws1) second,
  │         foot (ws3, ws4) last. Final focus: ws1 (Hub).
  │         Electron flags (F-0111): Hub and Chrome use --disable-gpu since
  │         this host has no GPU. Hub uses --user-data-dir=
  │         /home/user/.config/Antigravity-Hub for isolated Electron state.
  │         F-0116 Hub placement: sway config has
  │         for_window [app_id="antigravity"] → ws1, which pins the Hub's
  │         BrowserWindow to ws1 regardless of async map timing.
  │         F-0115: gnome-keyring-daemon is started with empty-password
  │         unlock (--unlock --components=secrets) BEFORE any app launch
  │         so the Hub's language_server can persist and reload its OAuth
  │         token via the Secret Service API. DBUS_SESSION_BUS_ADDRESS is
  │         exported to all launched app processes. Startup is idempotent
  │         (pgrep guard); missing binary logs WARNING and boot continues.
  │         Requires /usr/bin/gnome-keyring-daemon (present in base image).
  │         F-0117: Hub launch uses a readiness-based retry loop instead of
  │         a single-shot window-wait. Each attempt (up to HUB_MAX_RETRIES=3)
  │         polls the language_server HTTPS port in LISTEN state via
  │         /proc/<pid>/net/tcp6 as the primary readiness signal, falling
  │         back to a sway window appearing on ws1. On failure: stale Hub
  │         processes are killed (safe pgrep/exe-path filter), Singleton*
  │         locks cleared, diagnostics written to
  │         ~/logs/language_server_boot_diag.log, then Hub is relaunched.
  │         NOTE: F-0117's readiness check is a known false positive (reads
  │         shared network namespace, sees host-wide LISTEN sockets, always
  │         returns "ready" immediately — retry never fires). Fix pending
  │         root-cause diagnosis from F-0118.
  │         F-0118: Background diagnostic sampler runs during every Hub
  │         launch window. Samples every 3 s, appends to
  │         ~/logs/hub-ls-diag.log. Captures: LS pid/state/disappearance,
  │         LS-owned LISTEN sockets (correct inode method), Hub-reported
  │         port, curl probes, renderer count, DNS/network readiness, LS
  │         log file locations, LS stdout/stderr fd targets. Diagnostic
  │         only — does not change Hub launch behavior.
  │         F-0119: Before the Hub launch block, `_f0119_install_ls_shim()`
  │         installs a bash shim over `language_server` (idempotent via
  │         marker on line 2 of the shim). The shim tees LS stdout →
  │         ~/logs/ls-spawn.out and stderr → ~/logs/ls-spawn.err while
  │         passing both streams UNMODIFIED to the Hub (Hub reads stdout
  │         to discover the dynamic HTTPS port). Spawn/exit records with
  │         timestamps, args, and exit code go to ~/logs/ls-spawn.log.
  │         SIGTERM/SIGINT forwarded to real child. Diagnostic only.
  └── ws-boot-tests.service (After=ws-autolaunch, 30s delay)
        └── 10-tests.sh (run ~82 verification tests)
```

## Logs

| File | Content |
|------|---------|
| `~/logs/hub-launch.log` | 08-workspaces.sh Hub launch output — stdout+stderr from the Antigravity Hub process; append mode with `=== Hub launch: YYYY-MM-DD HH:MM:SS ===` header per boot (F-0110) |
| `~/logs/language_server_boot_diag.log` | 08-workspaces.sh Hub resilience diagnostics (F-0117) — written only when a launch attempt fails. Contains: attempt number/timestamp, `uptime` output, language_server PID and process status headers, Hub Electron PIDs, key environment variables (WAYLAND_DISPLAY, DBUS_ADDR, SWAYSOCK), and `/proc/net/tcp6` + `/proc/net/tcp` LISTEN socket snapshots. Used to diagnose the intermittent cold-boot language_server non-readiness failure. |
| `~/logs/hub-ls-diag.log` | 08-workspaces.sh Hub LS boot diagnostic sampler (F-0118) — written on every boot, continuously throughout the Hub launch window. Each boot opens with `=== F-0118 LS diag: YYYY-MM-DD HH:MM:SS ===`. Then, every 3 seconds during the 90 s launch window, a timestamped sample is appended with: (a) all `language_server` PIDs + `/proc/<pid>/stat` state + disappearance notifications; (b) LS-owned LISTEN sockets via correct inode→fd matching (NOT the shared-namespace method — fixes the F-0117 false-positive); (c) Hub-reported port from `hub-launch.log`; (d) curl/tcp probe of each LS-owned and Hub-reported port; (e) Hub renderer process count; (f) DNS resolution and curl probe of `daily-cloudcode-pa.googleapis.com` (leading cold-boot failure hypothesis); (g) one-time snapshot of LS log directories and LS stdout/stderr fd targets. This is the primary diagnostic artifact for root-causing the blank ws1 failure; read it after any cold boot where ws1 is blank. |
| `~/logs/ls-spawn.log` | F-0119 LS capture shim — human-readable spawn/exit log. One record per LS invocation: `=== LS spawn: YYYY-MM-DD HH:MM:SS.NNNNNNNNN pid=<pid> ===` followed by `args: <command line>`, then `=== LS exit: YYYY-MM-DD HH:MM:SS.NNNNNNNNN pid=<pid> rc=<code> ===` when LS exits. Append mode — accumulates across reboots. |
| `~/logs/ls-spawn.out` | F-0119 LS capture shim — raw LS stdout, append mode. On a successful warm launch contains version/build info and may include the port advertisement line the Hub parses. On a failing cold boot, may be sparse or empty (LS may exit before writing). |
| `~/logs/ls-spawn.err` | F-0119 LS capture shim — raw LS stderr, append mode. On a successful warm launch contains glog-format server startup lines (port binding, auth, init time). On a failing cold boot this is the primary evidence for WHY LS exits — read this first after a blank ws1 reboot. |
| `~/logs/sync.log` | 06-sync.sh output (git pull, boot script sync, sway config sync) |
| `~/logs/app-update.log` | 07-apps.sh output (npm updates, home-manager switch) |
| `~/logs/language-install.log` | 07b-languages.sh output (Go, Rust, Python, Ruby) |
| `~/logs/boot-test-results.txt` | Full test results (~80 PASS/FAIL/WARN checks) |
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
7. **Test on every boot** — `10-tests.sh` runs ~82 checks and saves results for the PO to review.
