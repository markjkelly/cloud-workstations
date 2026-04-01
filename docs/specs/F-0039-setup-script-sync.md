# F-0039: Sync cloud-build-setup.sh with Milestones 9-12

**Type:** Bug
**Priority:** P0 (critical)
**Status:** Approved
**Requested by:** PO
**Date:** 2026-03-31

## Problem

The setup script (`scripts/cloud-build-setup.sh`) is the single entry point for provisioning new Cloud Workstations via Cloud Build. It is currently stale -- it was last synced around Milestone 8 and is missing all features added in Milestones 9-12. This means that a fresh workstation provisioned by Cloud Build will be incomplete: missing IDEs, AI tools, desktop configs, timezone settings, and shell customizations that the boot scripts and configs already support.

### Gap Analysis

The following features exist in the repo (boot scripts, configs, home.nix template) but are NOT deployed by `cloud-build-setup.sh`:

| # | Missing Feature | Source in Repo | Milestone |
|---|----------------|----------------|-----------|
| 1 | home.nix missing new packages: `jetbrains.idea-oss`, `code-cursor`, `windsurf`, `zed-editor`, `gh`, `htop`, `curl`, `wget`, `unzip`, `grim`, `slurp`, `swaylock`, `swayidle`, `waybar` | F-0017, F-0038 specs; `07-apps.sh` home-manager switch | M9, M12 |
| 2 | Wofi config + Tokyo Night styling not deployed | `workstation-image/configs/wofi/{config,style.css}`, `boot/09-wofi.sh` | M10 |
| 3 | Snippet picker script + default config not deployed | `workstation-image/scripts/snippet-picker`, `workstation-image/configs/snippets/snippets.conf`, `boot/09-snippets.sh` | M10 |
| 4 | npm AI tools missing: `@openai/codex`, `@sourcegraph/cody`, `@mariozechner/pi-coding-agent` | `boot/07-apps.sh` npm update line | M11, M12 |
| 5 | OpenCode not installed via `go install` | `boot/07-apps.sh` Go install step | M11 |
| 6 | GitHub Copilot CLI extension not installed | `boot/07-apps.sh` gh extension step | M12 |
| 7 | Aider not installed via pip | F-0038 spec (aider-chat in Nix packages) | M12 |
| 8 | Sway config may be stale -- missing Cursor/Windsurf keybindings, wofi XDG fix, clipman LD_LIBRARY_PATH fix | `workstation-image/configs/sway/config` (already updated in repo) | M10, M12 |
| 9 | Timezone not explicitly set during setup | `boot/03-sway.sh` (TZ in service), `boot/05-shell.sh` (.zshrc TZ) | M12 |
| 10 | `.zshrc.local` sourcing pattern not in setup-generated .zshrc | `boot/05-shell.sh` (.zshrc includes .zshrc.local source) | M10 |

## Requirements

All changes are to `scripts/cloud-build-setup.sh`. The setup script must match what the boot scripts do on each restart, so a freshly provisioned workstation is identical to one that has been rebooted.

### R1: Update home.nix package list (Step 10)

The `home.nix` heredoc in Step 10 must include ALL packages currently expected by the boot scripts and specs:

```nix
home.packages = with pkgs; [
  sway foot wofi thunar clipman wl-clipboard wayvnc mako
  chromium google-chrome
  neovim tmux tree zsh ripgrep fd jq ffmpeg
  vscode
  jetbrains.idea-oss
  code-cursor
  windsurf
  zed-editor
  nodejs_22
  gh
  htop curl wget unzip
  grim slurp
  swaylock swayidle
  waybar
];
```

### R2: Deploy wofi config (new step after Step 13)

After deploying sway/waybar configs in Step 13, the setup script must also deploy wofi config files:

```bash
cat "${REPO_DIR}/workstation-image/configs/wofi/config" | \
    ws_pipe "mkdir -p ~/.config/wofi && cat > ~/.config/wofi/config"
cat "${REPO_DIR}/workstation-image/configs/wofi/style.css" | \
    ws_pipe "cat > ~/.config/wofi/style.css"
test_pass "Wofi config deployed"
```

### R3: Deploy snippet picker (new step after Step 13)

The setup script must deploy the snippet picker script and default config:

```bash
cat "${REPO_DIR}/workstation-image/scripts/snippet-picker" | \
    ws_pipe "mkdir -p ~/.local/bin && cat > ~/.local/bin/snippet-picker && chmod +x ~/.local/bin/snippet-picker"
cat "${REPO_DIR}/workstation-image/configs/snippets/snippets.conf" | \
    ws_pipe "mkdir -p ~/.config/snippets && cat > ~/.config/snippets/snippets.conf"
test_pass "Snippet picker deployed"
```

### R4: Install additional npm AI tools (Step 17)

The npm install line in Step 17 must include all npm packages:

```bash
npm install -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex @sourcegraph/cody @mariozechner/pi-coding-agent
```

### R5: Install OpenCode via `go install` (Step 17)

After npm installs, the setup script must install OpenCode:

```bash
ws_ssh '
export GOROOT=$HOME/go
export GOPATH=$HOME/gopath
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
go install github.com/opencode-ai/opencode@latest
' || true
```

### R6: Install GitHub Copilot CLI extension (Step 17)

After npm installs, the setup script must install the `gh-copilot` extension:

```bash
ws_ssh '
'"${NIX_SOURCE}"'
gh extension install github/gh-copilot 2>/dev/null || gh extension upgrade gh-copilot
' || true
```

### R7: Install aider via pip (Step 17)

Aider is available as a Nix package (`aider-chat`) added in R1, so no separate pip install is needed. However, if the Nix package is insufficient, a fallback `pip install aider-chat` step should be added. Since F-0038 lists `aider-chat` as a Nix home.packages entry, R1 covers this.

### R8: Ensure sway config is current (Step 13)

The sway config deployment in Step 13 already copies from `${REPO_DIR}/workstation-image/configs/sway/config`. Since the repo file has already been updated with Cursor/Windsurf keybindings, wofi XDG_DATA_DIRS fix, and clipman LD_LIBRARY_PATH fix (Milestones 10 and 12), **no change is needed** -- the existing `cat | ws_pipe` deployment picks up the latest file automatically.

### R9: Timezone is already set (no change needed)

The timezone is already set in:
- `boot/03-sway.sh` -- `Environment=TZ=America/Los_Angeles` in sway-desktop.service (deployed in Step 14 via `setup.sh`)
- `boot/05-shell.sh` -- `export TZ="America/Los_Angeles"` in .zshrc (deployed in Step 14 via `setup.sh`)
- `sway-status` script -- `export TZ="America/Los_Angeles"` (deployed in Step 13)

Since Step 14 runs `setup.sh` which executes all boot scripts (including 03-sway.sh and 05-shell.sh), timezone is covered. **No additional change needed.**

### R10: .zshrc.local sourcing is already set (no change needed)

The `boot/05-shell.sh` script already includes `source "$HOME/.zshrc.local"` in the generated .zshrc. Since Step 14 runs `setup.sh` which calls `05-shell.sh`, this is covered. **No additional change needed.**

### R11: Update verification in Step 17

The verification step must check the newly added tools:

```bash
echo "codex=$(~/.npm-global/bin/codex --version 2>/dev/null | head -1)"
echo "cody=$(~/.npm-global/bin/cody --version 2>/dev/null | head -1)"
echo "opencode=$(~/gopath/bin/opencode --version 2>/dev/null | head -1)"
```

### R12: Update final summary banner

The final "Installed:" summary at the bottom of the script must mention the additional tools:

```
Installed: Sway (Tokyo Night), Nix, ZSH, Starship,
  Operator Mono font, Chrome, VS Code, Cursor, Windsurf, Zed,
  IntelliJ IDEA, Antigravity, Claude Code, Gemini CLI, Codex,
  Cody, OpenCode, GitHub Copilot CLI, Aider,
  Go, Rust (rustup), Python (pyenv), Ruby (rbenv), Node.js (Nix)
```

### R13: Renumber steps

The script header says "Step 1/19" through "Step 19/19". Adding new deployment steps (wofi, snippets) in Step 13 requires either:
- (a) Adding sub-steps (Step 13b, 13c) to avoid renumbering, or
- (b) Renumbering all steps

Option (a) is preferred to minimize diff size. Add wofi and snippet deployments as Step 13b and Step 13c.

## Acceptance Criteria

- [ ] `cloud-build-setup.sh` Step 10 home.nix includes ALL packages: `jetbrains.idea-oss`, `code-cursor`, `windsurf`, `zed-editor`, `gh`, `htop`, `curl`, `wget`, `unzip`, `grim`, `slurp`, `swaylock`, `swayidle`, `waybar`
- [ ] Step 13 (or sub-step) deploys wofi config and style.css to `~/.config/wofi/`
- [ ] Step 13 (or sub-step) deploys snippet-picker to `~/.local/bin/` and snippets.conf to `~/.config/snippets/`
- [ ] Step 17 npm install includes `@openai/codex`, `@sourcegraph/cody`, `@mariozechner/pi-coding-agent`
- [ ] Step 17 installs OpenCode via `go install`
- [ ] Step 17 installs `gh-copilot` extension
- [ ] Step 17 verification checks codex, cody, and opencode
- [ ] Final banner lists all installed tools
- [ ] Existing sway config deployment (Step 13) picks up the latest config with Cursor/Windsurf keybindings, wofi fixes, and clipman fixes (no change needed -- verify file is current in repo)
- [ ] Timezone is set by boot scripts run in Step 14 (no change needed -- verify 03-sway.sh and 05-shell.sh contain TZ settings)
- [ ] `.zshrc.local` sourcing is included in .zshrc generated by boot/05-shell.sh (no change needed -- verify)
- [ ] Script runs end-to-end without errors on a fresh workstation
- [ ] All test_pass/test_fail checks pass
- [ ] No regressions to existing Steps 1-19

## Out of Scope

- Changes to boot scripts (they are already correct -- this spec only updates the setup script)
- Changes to the Docker image / Dockerfile
- Changes to sway config, waybar config, wofi config, or snippet files (already updated in prior milestones)
- API key configuration for any AI tool
- Testing on all three GCP projects (PE handles multi-project testing separately)

## Dependencies

- F-0036 (Milestone 10 UX -- wofi, snippets, waybar configs must exist in repo)
- F-0037 (OpenCode and Codex -- tools must be installable)
- F-0038 (Milestone 12 -- AI IDEs, CLI tools, timezone must be in boot scripts and configs)
- F-0001 (Language support -- Go and Node.js must be installed before AI tools)

## Open Questions

- None -- the gap analysis is complete and all source files exist in the repo. This is a straightforward sync of the setup script to match what the boot scripts already do.
