# F-0081: Composable Install — Profile-Based Module System

**Type:** Feature
**Priority:** P1 (important)
**Status:** Partially Done
**Requested by:** PO
**Date:** 2026-04-02

## Problem

Full workstation setup takes ~50 minutes. Many users don't need all components (4 languages compiled from source, 7 AI CLI tools, 5 IDEs) on every workstation. There is currently no way to customize what gets installed — every setup installs everything, wasting 15–30 minutes on unwanted components. This is especially painful during teardown+setup cycles and when onboarding new GCP projects.

## Solution Overview

Introduce a **profile-based module system** that lets users choose what to install. Five profiles (minimal, dev, ai, full, custom) map to seven modules that gate which boot scripts run, which Nix packages are installed, and which tests execute.

---

## Profiles

| Profile | Modules Included | Estimated Setup Time |
|---------|-----------------|---------------------|
| **minimal** | core, tmux | ~20 min |
| **dev** | core, tmux, desktop | ~25 min |
| **ai** | core, tmux, desktop, ides, ai-tools | ~35 min |
| **full** | core, tmux, desktop, ides, ai-tools, languages, tailscale | ~50 min |
| **custom** | User-selected modules | varies |

**Default profile: `full`** (backwards compatible — existing behavior unchanged).

---

## Modules

| Module | Boot Scripts | Contents |
|--------|-------------|----------|
| **core** (always on) | 01-nix, 02-nvidia, 03-sway, 04-fonts, 05-shell, 06-prompt | Nix, NVIDIA drivers, Sway desktop, fonts, ZSH, Starship prompt, Chrome, Antigravity, foot terminal |
| **desktop** | 09-wofi, 09-snippets | Wofi launcher styling, sway-status bar, clipboard manager, code snippets |
| **ides** | 07-apps (partial: home-manager IDE packages) | VSCode, IntelliJ IDEA, Cursor, Windsurf, Zed |
| **ai-tools** | 07-apps (partial: npm AI tools + Go tools) | Claude Code, Codex, Cody, Pi, OpenCode, Aider, GitHub Copilot CLI, Gemini CLI |
| **languages** | 07a-lang-deps, 07b-languages | Go, Rust (rustup), Python (pyenv), Ruby (rbenv) — compiled from source |
| **tailscale** | 06a-tailscale | Tailscale VPN client |
| **tmux** | 06b-tmux | tmux config, claude-tmux integration, tmux-debug |

---

## Implementation Phases

### Phase 1: CLI + Config (`ws.sh --profile`, `~/.ws-modules`)

**Goal:** Add profile selection to the CLI and create the module config file on the workstation.

**Requirements:**

1. `ws.sh setup` accepts a new `--profile` flag with values: `minimal`, `dev`, `ai`, `full`, `custom`
2. `ws.sh setup` accepts a new `--modules` flag (comma-separated list, only valid with `--profile custom`)
3. Profile defaults to `full` when `--profile` is not specified (backwards compatible)
4. Profile value is passed to `cloud-build-setup.sh` as a Cloud Build substitution variable (`_PROFILE`)
5. `cloud-build-setup.sh` creates `~/.ws-modules` on the workstation via SSH after the workstation is running
6. `~/.ws-modules` is a simple key=value file listing enabled modules:
   ```
   PROFILE=dev
   MODULE_CORE=true
   MODULE_DESKTOP=true
   MODULE_IDES=false
   MODULE_AI_TOOLS=false
   MODULE_LANGUAGES=false
   MODULE_TAILSCALE=false
   MODULE_TMUX=true
   ```
7. Usage help (`ws.sh --help`) is updated to document the new flags
8. Invalid profile names or module names produce clear error messages

**Acceptance Criteria:**

- [ ] `ws.sh setup -p PROJECT --profile minimal` passes profile to Cloud Build
- [ ] `ws.sh setup -p PROJECT --profile custom --modules "core,ides,tmux"` works correctly
- [ ] `ws.sh setup -p PROJECT` defaults to `full` profile (no behavior change)
- [ ] `~/.ws-modules` file is created on the workstation with correct module flags
- [ ] `ws.sh --help` shows profile and modules documentation
- [ ] Invalid `--profile xyz` produces an error (not silent failure)
- [ ] `--modules` without `--profile custom` produces an error

**Files to modify:**
- `scripts/ws.sh` — add `--profile` and `--modules` flags, pass to Cloud Build
- `scripts/cloud-build-setup.sh` — accept `_PROFILE` substitution, create `~/.ws-modules` on workstation

---

### Phase 2: Boot Script Gating

**Goal:** `setup.sh` reads `~/.ws-modules` and skips boot scripts for disabled modules.

**Requirements:**

1. `setup.sh` sources `~/.ws-modules` at the start (if the file exists)
2. If `~/.ws-modules` does not exist, all modules are enabled (backwards compatible)
3. Each boot script is mapped to a module:
   - `01-nix.sh` → core (always runs)
   - `02-nvidia.sh` → core (always runs)
   - `03-sway.sh` → core (always runs)
   - `04-fonts.sh` → core (always runs)
   - `05-shell.sh` → core (always runs)
   - `06-prompt.sh` → core (always runs)
   - `06a-tailscale.sh` → tailscale
   - `06b-tmux.sh` → tmux
   - `07-apps.sh` → split (see Phase 2b below)
   - `07a-lang-deps.sh` → languages
   - `07b-languages.sh` → languages
   - `09-wofi.sh` → desktop
   - `09-snippets.sh` → desktop
4. `setup.sh` logs which scripts are skipped and why: `"Skipping 07b-languages.sh (module 'languages' disabled)"`
5. `07-apps.sh` must be split or made conditional — it currently handles both IDE updates (home-manager) and AI tool updates (npm). Options:
   - **Option A (recommended):** Split into `07-ides.sh` and `07c-ai-tools.sh`
   - **Option B:** Add internal conditionals reading `~/.ws-modules`

**Acceptance Criteria:**

- [ ] `setup.sh` reads `~/.ws-modules` and skips disabled module scripts
- [ ] Missing `~/.ws-modules` = all modules enabled (backwards compatible)
- [ ] Skipped scripts are logged with the reason
- [ ] Boot time with `minimal` profile is measurably faster than `full`
- [ ] `07-apps.sh` is split or conditionally gated for IDEs vs AI tools

**Files to modify:**
- `workstation-image/boot/setup.sh` — add module-gating logic
- `workstation-image/boot/07-apps.sh` — split into IDE + AI-tools scripts (or add conditionals)

---

### Phase 3: Dynamic `home.nix`

**Goal:** Generate `home.nix` dynamically so Nix Home Manager only installs packages for enabled modules.

**Requirements:**

1. Create a `home.nix` template (or use Nix conditionals) that includes/excludes package groups based on profile
2. The following package groups map to modules:
   - **core:** sway, foot, wofi, thunar, clipman, wl-clipboard, wayvnc, neovim, git, zsh, nodejs_22, starship, bat, eza, ripgrep, fd, jq, yq, fzf, htop, btop, unzip, wget, curl
   - **ides:** vscode, jetbrains.idea-community, code-cursor (overlay), windsurf (overlay), zed-editor
   - **desktop:** (wofi config, snippets — mostly config files, not Nix packages)
3. `cloud-build-setup.sh` generates the appropriate `home.nix` based on profile before running `home-manager switch`
4. A helper script or template approach generates `home.nix` from `~/.ws-modules`
5. The generated `home.nix` must still be a valid Nix expression that Home Manager can evaluate

**Acceptance Criteria:**

- [ ] `minimal` profile `home.nix` does not include IDE packages
- [ ] `full` profile `home.nix` includes all packages (same as current)
- [ ] `home-manager switch` succeeds for all profiles
- [ ] Adding a module later (changing `~/.ws-modules` and re-running setup) installs the new packages
- [ ] Home Manager sway-config is unaffected by profile (Sway config is always core)

**Files to modify:**
- `scripts/cloud-build-setup.sh` — generate `home.nix` from template based on profile
- New file: `workstation-image/configs/home.nix.template` (or equivalent)
- `workstation-image/boot/07-apps.sh` (or split scripts) — ensure `home-manager switch` uses correct `home.nix`

---

### Phase 4: Setup Script Gating

**Goal:** `cloud-build-setup.sh` skips time-consuming setup steps for disabled modules.

**Requirements:**

1. The following setup steps in `cloud-build-setup.sh` are gated by module:
   - **languages:** Skip Go download, Rust install, pyenv/rbenv setup, Python/Ruby compilation
   - **ai-tools:** Skip npm install of AI CLI tools, OpenCode Go install
   - **ides:** Skip IDE-specific configuration (extensions, settings)
   - **tailscale:** Skip Tailscale installation and auth
2. Each gated section logs: `"Skipping [section] (module '[name]' disabled)"`
3. The `_PROFILE` substitution variable controls which sections run
4. Profile-to-module expansion happens inside `cloud-build-setup.sh` (not in Cloud Build YAML)

**Acceptance Criteria:**

- [ ] `--profile minimal` setup skips language compilation, AI tool installs, IDE setup
- [ ] `--profile dev` setup skips languages and IDEs but installs Claude Code (it's in core dev tools for dev profile)
- [ ] Skipped steps produce clear log messages
- [ ] Setup time for `minimal` profile is ~20 minutes
- [ ] Setup time for `dev` profile is ~25 minutes
- [ ] No regressions — `full` profile produces identical results to current setup

**Files to modify:**
- `scripts/cloud-build-setup.sh` — add module checks around gated sections

---

### Phase 5: Conditional Tests

**Goal:** `10-tests.sh` only tests components that are installed for the active profile.

**Requirements:**

1. `10-tests.sh` reads `~/.ws-modules` at the start
2. Tests for disabled modules report `SKIP` (not `FAIL` or `PASS`)
3. The test summary line includes skip count: `"PASS: 42 | FAIL: 0 | SKIP: 15 | WARN: 0"`
4. Add `test_skip()` helper alongside existing `test_pass()`, `test_fail()`, `test_warn()`
5. Module-to-test mapping:
   - **ides:** VSCode, IntelliJ, Cursor, Windsurf, Zed binary checks
   - **ai-tools:** Claude Code, Codex, Cody, Pi, OpenCode, Aider, Copilot CLI checks
   - **languages:** go, rustc, cargo, python3, ruby, pyenv, rbenv checks
   - **tailscale:** tailscale binary check
   - **tmux:** tmux binary and config checks
   - **desktop:** wofi config, snippets, sway-status checks
6. Core tests always run (Sway, Nix, NVIDIA, ZSH, Starship, Chrome, Antigravity, foot)

**Acceptance Criteria:**

- [ ] `minimal` profile: core tests PASS, all other tests SKIP
- [ ] `full` profile: all tests run (no SKIP), same behavior as today
- [ ] Missing `~/.ws-modules` = all tests run (backwards compatible)
- [ ] `SKIP` count appears in summary line
- [ ] Boot test summary on `minimal` shows 0 FAIL (not false failures from missing optional components)
- [ ] `test_skip()` helper function added to test script

**Files to modify:**
- `workstation-image/boot/10-tests.sh` — add module-aware test gating, SKIP counter

---

### Phase 6: Multi-Profile Testing

**Goal:** Validate that different profiles work correctly across GCP projects and that timing estimates are accurate.

**Requirements:**

1. Test `minimal` profile on a fresh setup (suggest: gement03)
2. Test `full` profile on a fresh setup (suggest: gement02) as control
3. Measure and record actual setup times for each profile
4. Verify that:
   - `minimal` workstation boots and has a working desktop (Sway, Chrome, Antigravity)
   - `minimal` workstation does NOT have IDEs, AI tools, or languages installed
   - `full` workstation matches current behavior exactly
   - Tests produce correct PASS/SKIP/FAIL results per profile
5. Test profile upgrade: change `~/.ws-modules` on `minimal` workstation from `minimal` to `dev`, re-run setup, verify dev tools are now installed
6. Document actual timing results in PROGRESS.md

**Acceptance Criteria:**

- [ ] `minimal` setup completes in ≤25 minutes (target: ~20 min)
- [ ] `full` setup time is unchanged from current (~50 min)
- [ ] `minimal` workstation: Sway works, Chrome works, Antigravity works
- [ ] `minimal` workstation: `which code` returns not-found (no VSCode)
- [ ] `minimal` workstation: `which go` returns not-found (no Go)
- [ ] `full` workstation: all existing tests pass
- [ ] Profile upgrade (`minimal` → `dev`) installs dev tools correctly
- [ ] Results documented in PROGRESS.md

**Projects for testing:**
- gement02: `full` profile (control)
- gement03: `minimal` profile (test)

---

## Out of Scope

- Per-project profile configuration (all workstations in a project use the same profile)
- GUI/web-based profile selector
- Partial module uninstall (removing already-installed modules requires teardown+setup)
- Module version pinning (always installs latest)
- Remote/API-driven profile changes (profile is set at setup time only)

## Dependencies

- None — this is a standalone enhancement to the existing setup pipeline

## Open Questions

1. **Should `07-apps.sh` be split (Option A) or made conditional (Option B)?**
   Recommendation: Option A (split into `07-ides.sh` + `07c-ai-tools.sh`) for cleaner module boundaries. But this means renumbering — assess impact on existing boot order.

2. **Where should Claude Code live for the `dev` profile?**
   Claude Code is currently installed in `07-apps.sh` alongside other AI tools. For the `dev` profile, Claude Code should be included but other AI tools excluded. This suggests Claude Code should be in `core` or a separate `dev-tools` sub-module.

3. **Should `~/.ws-modules` use YAML or simple key=value?**
   Recommendation: Simple key=value (sourceable by bash) for simplicity. YAML requires a parser.

4. **Home.nix template vs Nix conditionals?**
   Template (generate different `home.nix` files) is simpler but less flexible. Nix conditionals (read marker files) are more elegant but harder to debug. Recommend template approach for Phase 3.

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Module boundary wrong (script does both core + optional) | Medium | Split scripts at module boundaries before gating |
| Home Manager conflicts between profiles | High | Test profile switching thoroughly in Phase 6 |
| Backwards compatibility break | High | Default to `full`, treat missing `~/.ws-modules` as all-enabled |
| Timing estimates inaccurate | Low | Measure in Phase 6, adjust docs |

## Success Metrics

- `minimal` profile setup time ≤25 minutes (50% reduction from full)
- Zero regressions on `full` profile
- Zero false-positive test failures on any profile
- Clean upgrade path from `minimal` → `full`
