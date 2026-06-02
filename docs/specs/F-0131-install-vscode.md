# F-0131: Install VS Code + Reconcile home.nix Drift

**Type:** Feature + Enhancement
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-06-02

## Problem

VS Code (`code`) is not on PATH on the live workstation. The boot test suite has a
`check_binary "VSCode" "code"` check (~line 97 of `10-tests.sh`) that FAILs on every
boot because `code` was never installed into the live home.nix.

Separately, the live `~/.config/home-manager/home.nix` is a minimal ~30-line stub that
diverges significantly from the generated full-profile home.nix emitted by
`scripts/cloud-build-setup.sh`. This drift means:

1. `home-manager switch` (run by `07-apps.sh` on every boot) installs only the minimal
   package set, not the full baseline.
2. `home.sessionVariables` (EDITOR, VISUAL, BROWSER), `programs.zsh` shell config,
   `programs.starship`, and all `home.file` config symlinks are absent from the live
   home.nix — features intended to be managed by home-manager are silently bypassed.
3. The sway config (`~/.config/sway/config`) is a plain file, not a home-manager
   managed symlink — manual edits to it would drift again the next time cloud-build-setup
   runs and re-deploys it.

## PO Decisions (non-negotiable)

1. **Install method:** `pkgs.vscode` (MS proprietary build). `allowUnfree = true` already
   set. NOT vscodium, NOT a tarball.
2. **IDE scope:** VS Code ONLY. The 4 other IDEs (`jetbrains.idea-oss`, `code-cursor`,
   `windsurf`, `zed-editor`) are NOT installed on the live workstation via this feature.
   F-0126 retains ownership of deciding what to do with the stale test checks for those 4
   tools.
3. **Config takeover (parity guard):** Only adopt a `home.file` directive when the source
   file provably exists; never add a directive that would break `home-manager switch`.

## Requirements

1. VS Code (`pkgs.vscode`) must be installed via home.nix on the live workstation.
2. The live `~/.config/home-manager/home.nix` must be reconciled to include:
   - `home.packages` = BASE_PKGS + `vscode` (no other IDEs)
   - `programs.zsh` with shell aliases, `initContent` sourcing Nix profile, timezone,
     PATH additions, pyenv/rbenv, starship, and user customization hooks
   - `home.sessionVariables` (EDITOR, VISUAL, BROWSER)
   - `programs.starship.enable = true`
   - `home.file` for sway config (source exists, byte-matches live — safe to adopt)
   - `home.file` for nvim init.lua (source deployed from repo canonical file — safe to adopt)
   - Waybar `home.file` directives OMITTED (this box uses swaybar, not waybar; no source
     files exist; deploying stale waybar configs would be misleading)
3. `home-manager switch` must succeed cleanly (exit 0) after the reconciled home.nix is
   written.
4. The sway config must be unchanged in content after the switch (home-manager manages it
   as a symlink; content is identical to the pre-switch file).
5. The 4 other IDEs (`cursor`, `windsurf`, `idea-oss`, `zeditor`) must NOT be installed.
6. A VS Code version check must be added to `10-tests.sh` alongside other version checks.
7. `10-tests.sh` must be synced to `~/boot/10-tests.sh`.

## home.file Directive Decisions

| Directive | Decision | Rationale |
|-----------|----------|-----------|
| `.config/sway/config` | ADOPT | Source `~/.config/home-manager/sway-config` exists; byte-matches live config; idempotent — content unchanged |
| `.config/nvim/init.lua` | ADOPT | Source deployed from `workstation-image/configs/nvim/init.lua`; nvim is installed but has no config; canonical config from repo |
| `.config/waybar/config` | OMIT | Source `~/.config/home-manager/waybar-config.json` does not exist; box uses swaybar not waybar |
| `.config/waybar/style.css` | OMIT | Source `~/.config/home-manager/waybar-style.css` does not exist; not applicable on this box |

## Acceptance Criteria

- [x] `code --version` works after `home-manager switch`
- [x] `home-manager switch` completes with exit code 0
- [x] `~/.config/sway/config` content is unchanged (only converted to a symlink)
- [x] `swaymsg reload` succeeds without errors after switch
- [x] `command -v cursor idea-oss windsurf zeditor` — all absent (4 other IDEs NOT installed)
- [x] `10-tests.sh` VSCode binary + version + sway-grep checks all PASS
- [x] No new FAIL regressions in boot test run
- [x] `10-tests.sh` synced to `~/boot/10-tests.sh`

## Residual Divergences (documented, owned by other items)

1. **IDE_PKGS in cloud-build-setup.sh still contains all 5 IDEs** for ai/full profiles.
   The live home.nix now only has `vscode`. This means a `ws.sh setup` on a new workstation
   would install all 5 IDEs (generated profile), but the live box now only has 1. This
   divergence is acceptable and tracked under **F-0126**, which owns the decision of whether
   to prune the other 4 from IDE_PKGS.

2. **Waybar directives omitted** from the live home.nix because the box uses swaybar, not
   waybar. The generated home.nix (from cloud-build-setup.sh) still includes waybar
   directives. **F-0127** owns any further waybar/generated-vs-live reconciliation.

3. **Stale boot-test checks for `idea-oss`, `cursor`, `windsurf`, `zeditor`** remain FAILs
   per-boot. These are tracked under **F-0126** (do not touch here).

## Out of Scope

- Installing or testing `jetbrains.idea-oss`, `code-cursor`, `windsurf`, `zed-editor`
- Modifying `IDE_PKGS` in `cloud-build-setup.sh` (F-0126)
- Reconciling all remaining home.nix drift patterns (F-0127)
- Full resolution of all other boot-test FAILs (F-0126–F-0130)

## Dependencies

- F-0123 — `home-manager switch` in `07-apps.sh` must work (fixed; this feature relies on it)
- F-0126 — owns stale IDE test cleanup (not a blocker; those tests remain as FAILs)
- F-0127 — owns remaining home.nix drift patterns (not a blocker)

## Open Questions

- None. All PO decisions have been made and implemented.
