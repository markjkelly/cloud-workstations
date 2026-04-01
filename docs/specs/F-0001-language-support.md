# F-0001: Programming Language Support (Go, Rust, Python, Ruby)

**Type:** Feature
**Priority:** P1 (important)
**Status:** Approved
**Requested by:** PO (Your Name)
**Date:** 2026-03-31

## Problem

The Cloud Workstation currently provides an excellent desktop environment, AI tools, and IDE setup, but lacks common programming languages beyond Node.js. Developers cannot write Go, Rust, Python, or Ruby code without manually installing toolchains on every workstation. This limits the workstation's utility as a general-purpose cloud development environment.

While Nix Home Manager manages system tools well (ripgrep, neovim, tmux, VS Code, etc.), programming languages require multi-version support, proper toolchain integration (e.g., `cargo`, `pip`, `gem`), and familiar developer workflows that native version managers provide better than Nix.

## Proposed Solution: Hybrid Approach

Continue using **Nix** for system tools while using **native version managers** for programming languages. This gives developers the multi-version flexibility they expect (e.g., `pyenv install 3.11`, `rustup target add wasm32`) while keeping the rest of the system managed by Nix.

| Language | Version Manager | Install Location | Why This Manager |
|----------|----------------|------------------|------------------|
| Go | Direct tarball from go.dev | `~/go` (GOROOT), `~/gopath` (GOPATH) | Go's official distribution is a single tarball; no version manager needed for most workflows |
| Rust | `rustup` (official) | `~/.rustup`, `~/.cargo` | The standard Rust toolchain manager; handles stable/nightly/beta, cross-compilation targets |
| Python | `pyenv` | `~/.pyenv` | Compiles Python from source, supports arbitrary versions, integrates with virtualenv |
| Ruby | `rbenv` + `ruby-build` | `~/.rbenv` | Lightweight, uses shims, `ruby-build` provides version recipes |
| Node.js | Keep in Nix (already working) | Via Nix Home Manager | Already stable at Node 22; no multi-version need identified |

All version managers install entirely within `$HOME`, so everything persists across workstation reboots naturally — no `/nix` copy step needed.

## Requirements

### R1: Boot script `07b-languages.sh`

Create `~/boot/07b-languages.sh` (runs after `07-apps.sh`, before `08-workspaces.sh`) to install and verify language toolchains. The script must:

1. **Be idempotent** — safe to run on every boot. First boot installs everything; subsequent boots verify and optionally update.
2. **Run as user** — all installs use `runuser -u user` (not root), since everything lives in `$HOME`.
3. **Log to `~/logs/language-install.log`** — timestamped, same format as existing boot scripts.
4. **Install in parallel where possible** — Go, Rust, Python, and Ruby installs are independent.

#### R1.1: Go Installation

- Download latest stable Go tarball from `https://go.dev/dl/` (detect latest version from `https://go.dev/VERSION?m=text`)
- Extract to `~/go` (GOROOT)
- Set `GOPATH=~/gopath`, create `~/gopath/{bin,src,pkg}`
- On subsequent boots: check if installed version matches latest; update if newer available
- Verification: `go version` returns a valid version string

#### R1.2: Rust Installation (rustup)

- Install `rustup` via `https://sh.rustup.rs` with `-y --default-toolchain stable --no-modify-path`
- Installs to `~/.rustup` (toolchains) and `~/.cargo` (binaries, registry)
- On subsequent boots: run `rustup update` to get latest stable
- Verification: `rustc --version` and `cargo --version` return valid versions

#### R1.3: Python Installation (pyenv)

- Install `pyenv` via git clone to `~/.pyenv` from `https://github.com/pyenv/pyenv.git`
- Install build dependencies (may need apt packages: `build-essential`, `libssl-dev`, `zlib1g-dev`, `libbz2-dev`, `libreadline-dev`, `libsqlite3-dev`, `libffi-dev`, `liblzma-dev`)
- Install latest stable Python 3.x (e.g., 3.12.x) and set as global default
- On subsequent boots: `git -C ~/.pyenv pull` to update pyenv; skip Python rebuild unless requested
- Verification: `python --version` returns the pyenv-managed version

#### R1.4: Ruby Installation (rbenv + ruby-build)

- Install `rbenv` via git clone to `~/.rbenv` from `https://github.com/rbenv/rbenv.git`
- Install `ruby-build` as rbenv plugin via git clone to `~/.rbenv/plugins/ruby-build`
- Install latest stable Ruby 3.x and set as global default
- On subsequent boots: `git pull` to update rbenv and ruby-build; skip Ruby rebuild unless requested
- Verification: `ruby --version` returns the rbenv-managed version

### R2: Build dependencies in `cloud-build-setup.sh`

Update `cloud-build-setup.sh` (or create a sub-step) to install apt build dependencies required by pyenv and rbenv for compiling Python and Ruby from source:

```
build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev
libsqlite3-dev libffi-dev liblzma-dev libncurses-dev libgdbm-dev
libyaml-dev tk-dev
```

These packages must be installed before `07b-languages.sh` runs. Since the Docker image is ephemeral, these must be reinstalled on every boot or baked into the Docker image.

**Decision point:** Either:
- (A) Add apt installs to the Docker image (adds ~200MB but faster boot), or
- (B) Install via apt in a boot script (slower boot but keeps image lean)

Recommended: **(B)** — add a `07a-lang-deps.sh` boot script that installs apt dependencies, keeping the Docker image minimal per project convention.

### R3: Shell integration (.zshrc PATH additions)

Update `05-shell.sh` to add the following PATH entries to `.zshrc`:

```bash
# Go
export GOROOT="$HOME/go"
export GOPATH="$HOME/gopath"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
```

These must appear **before** the Starship init (which should remain last).

### R4: Persistence

All version managers and language installations live entirely within `$HOME` on the 500GB persistent SSD:

| Component | Path | Survives Reboot? |
|-----------|------|-----------------|
| Go binary | `~/go/` | Yes |
| Go workspace | `~/gopath/` | Yes |
| Rust toolchains | `~/.rustup/` | Yes |
| Cargo binaries | `~/.cargo/` | Yes |
| pyenv + Python builds | `~/.pyenv/` | Yes |
| rbenv + Ruby builds | `~/.rbenv/` | Yes |
| Build deps (apt) | System packages | No — reinstalled by boot script |

No `/nix` copy step is needed for any of these. The only ephemeral component is the apt build dependencies, which are reinstalled on each boot by the dependency script.

### R5: Update behavior

| Event | Go | Rust | Python | Ruby |
|-------|----|------|--------|------|
| First boot (fresh install) | Download + extract latest | rustup install stable | pyenv install latest 3.x | rbenv install latest 3.x |
| Subsequent boot | Check for newer version, update if available | `rustup update` | `git pull` pyenv (skip Python rebuild) | `git pull` rbenv + ruby-build (skip Ruby rebuild) |
| Manual version change | User runs: download specific version | `rustup install nightly` | `pyenv install 3.11.0` | `rbenv install 3.2.0` |

Language rebuilds (Python, Ruby) are expensive (5-10 min each) and should NOT happen automatically on boot. Only the version manager itself is updated. Users install additional versions manually.

## Acceptance Criteria

- [ ] AC1: `go version` returns Go 1.22+ after boot
- [ ] AC2: `rustc --version` returns a stable Rust version after boot
- [ ] AC3: `cargo --version` returns a valid Cargo version after boot
- [ ] AC4: `python --version` returns Python 3.12+ (pyenv-managed) after boot
- [ ] AC5: `pyenv install 3.11.0` succeeds (build deps present, pyenv functional)
- [ ] AC6: `ruby --version` returns Ruby 3.3+ (rbenv-managed) after boot
- [ ] AC7: `gem install bundler` succeeds (Ruby gem system functional)
- [ ] AC8: All language binaries are on PATH in a new ZSH shell (no manual sourcing)
- [ ] AC9: Boot script is idempotent — running twice produces no errors and no duplicate installs
- [ ] AC10: All installations survive a full workstation stop/start cycle
- [ ] AC11: Boot script completes in under 2 minutes on subsequent boots (first boot may take 10-15 min for Python/Ruby compilation)
- [ ] AC12: Installations verified on at least 2 GCP projects

## Out of Scope

- IDE language extensions (Go, Rust-analyzer, Python/Pylance) — users install per-project
- Language-specific linters or formatters (golangci-lint, black, rubocop) — users install per-project
- Virtual environment management (venv, pipenv, poetry) — users set up per-project
- Moving Node.js from Nix to nvm — Node.js is stable in Nix, no change needed
- Language server protocol (LSP) configuration — per-user/per-project concern
- Container/Docker-based development environments (devcontainers)

## Dependencies

- F-0033: Persistent disk bootstrap architecture (boot script framework)
- F-0030/F-0031: Shell integration (ZSH + .zshrc must exist before adding PATH entries)

## Open Questions

- Should apt build dependencies be baked into the Docker image (faster boot, larger image) or installed on every boot (slower boot, lean image)? **Recommendation: boot script (option B)** to stay consistent with the lean Docker image philosophy.
- Should we pin specific language versions or always install latest stable? **Recommendation: latest stable** — the version managers make it easy to install additional versions as needed.
- Should Go use a version manager like `gvm` or `goenv` instead of direct tarball? **Recommendation: direct tarball** — Go releases are self-contained, and multi-version Go is rare in practice. Users can install `gvm` separately if needed.
