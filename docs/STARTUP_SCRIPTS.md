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
  │     └── 08-workspaces.sh (launches apps + Xwayland)
  └── ws-boot-tests.service (After=ws-autolaunch, 30s delay)
        └── 10-tests.sh (run ~82 verification tests)
```

## Logs

| File | Content |
|------|---------|
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

## Key Design Decisions

1. **All scripts are idempotent** — safe to run multiple times. No duplicate entries, no state corruption.
2. **Persistent disk** — all installs go to `$HOME` on the persistent disk. The Docker image is ephemeral; only `~/boot/` scripts and configs persist.
3. **Home Manager manages Nix apps** — `07-apps.sh` runs `nix-channel --update && home-manager switch` to upgrade all Nix-managed tools (IDEs, dev tools, Sway ecosystem).
4. **npm manages AI CLI tools** — Claude Code, Codex, Cody, Pi installed globally to `~/.npm-global/`.
5. **Native version managers for languages** — Go (tarball), Rust (rustup), Python (pyenv), Ruby (rbenv) for multi-version support.
6. **No-clobber for user configs** — `snippets.conf` and `.zshrc.local` are never overwritten, preserving user customizations.
7. **Test on every boot** — `10-tests.sh` runs ~82 checks and saves results for the PO to review.
