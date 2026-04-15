# F-0095: Foot Terminal CWD Regression — No Longer Starts in /home/user

**Type:** Bug
**Priority:** P0 (critical)
**Status:** Draft
**Requested by:** PO
**Date:** 2026-04-15

## Problem

Newly spawned foot terminals are no longer starting with their working
directory set to `/home/user`. Instead, foot inherits whatever working
directory its launcher (sway, the autostart workspace script, or a wofi
invocation) happened to have — typically a repo path or `/`. This means
`$mod+Return`, `$mod+t`, and sway startup all drop the user into the wrong
directory, forcing a manual `cd ~` on every new terminal.

This bug has already been fixed twice:

- **`0dd33b3` — "fix: start foot terminal in /home/user by default"**
  added `--working-directory=/home/user` to every foot invocation in
  `workstation-image/boot/08-workspaces.sh` and
  `workstation-image/configs/sway/config`.
- **`e7236a8` — "fix(sway): foot terminals start in $HOME (F-0087)"**
  wrapped sway bindings with `cd ~ && $nix/foot …` and added a `10-tests.sh`
  assertion that the binding contains the `cd ~` guard.

The regression has resurfaced on the current workstation, which means one
of those guarantees has been silently undone. Because the bug has now
recurred twice, the fix this time must not only restore the behavior but
also make the regression detectable at boot so a future drift fails the
boot-test summary instead of shipping silently.

## Reproduction

On the current workstation:

1. Reboot (or run `ws.sh teardown && ws.sh setup` followed by login).
2. Press `$mod+Return` (or `$mod+t`) inside sway.
3. In the new foot window, run `pwd`.

**Expected:** `/home/user`
**Actual:** foot's CWD is whatever sway was launched from — typically a
project directory under `~/dev/my-workspace/…` or `/` — not `/home/user`.

The same is observed for foot instances spawned by the autostart workspace
script (`08-workspaces.sh`) on first login.

## Root-Cause Hypothesis

Per the **three-places rule** in `CLAUDE.md` (repo config +
`~/.config/home-manager/sway-config` + `scripts/cloud-build-setup.sh`), a
config change only persists if all three are updated in lockstep. The most
likely explanations, in priority order:

1. **H1 — Home Manager sway-config drift.** The repo's
   `workstation-image/configs/sway/config` still contains the `cd ~ &&`
   (or `--working-directory=/home/user`) guard from `0dd33b3` / `e7236a8`,
   but `~/.config/home-manager/sway-config` on the live workstation does
   not. On every boot, `home-manager switch` symlinks the stale version
   into `~/.config/sway/config`, overwriting the correct config.
2. **H2 — `cloud-build-setup.sh` drift.** Fresh-project setups deploy a
   version of the sway config (or of `08-workspaces.sh`) that predates
   `0dd33b3` / `e7236a8`, so the regression is baked into new projects
   from the first boot.
3. **H3 — `08-workspaces.sh` regression.** The autostart script lost its
   `--working-directory=/home/user` flags during a later edit (e.g. a
   Nix-path refactor or a copy-paste from a stale source) even though the
   sway keybinding path is intact.
4. **H4 — A re-introduced Home Manager foot/sway module** is emitting a
   competing `~/.config/sway/config` or wrapping foot without the CWD
   argument, analogous to how F-0094's foot font config got re-asserted
   by a Home Manager module.

The SWE picking up F-0095 must confirm which hypothesis is the real cause
by diffing the three sources against the commits `0dd33b3` and `e7236a8`
before applying a fix.

## Requirements

1. **R1 — Foot always opens in `/home/user`.** Every foot invocation
   reachable by the user (sway `$mod+Return`, `$mod+t`, any other sway
   bindings, and every foot spawned by the autostart workspace script)
   must start with `pwd == /home/user`, regardless of the launcher's CWD.
2. **R2 — Three-places rule compliance.** The fix must be applied to
   all three sources of truth and they must match byte-for-byte on the
   relevant lines:
   - `workstation-image/configs/sway/config` (repo source of truth),
   - `~/.config/home-manager/sway-config` on the live workstation (and
     re-applied via `home-manager switch`),
   - `scripts/cloud-build-setup.sh` so fresh-project setups deploy the
     correct config.
   If `08-workspaces.sh` is also involved, the same rule applies to its
   repo copy and `~/boot/08-workspaces.sh`.
3. **R3 — Do not silence via shell aliases or profile hacks.** The fix
   must live in the sway / workspace-autostart config, not in
   `~/.zshrc`, `~/.profile`, or a foot wrapper that `cd`s on launch.
   Those hide the drift instead of preventing it.
4. **R4 — Mandatory test coverage (boot-level).** Extend
   `workstation-image/boot/10-tests.sh` so that on every boot it asserts:
   - the sway keybindings for `$mod+Return` and `$mod+t` in the active
     `~/.config/sway/config` contain the `--working-directory=/home/user`
     flag **or** the `cd ~ &&` guard (whichever the fix chooses —
     pick one and be consistent across both bindings),
   - every `foot` invocation in `workstation-image/boot/08-workspaces.sh`
     (the repo copy) carries the same guard,
   - the repo sway config and `~/.config/home-manager/sway-config` are
     byte-identical on the lines that launch foot (drift guard for H1).
   Failures must surface in `~/logs/boot-test-summary.txt` so a future
   third regression is caught on the next boot, not by the PO.
5. **R5 — Runtime assertion.** Add a test that launches `foot --help`
   is-not-enough; instead, assert via `grep` / `awk` on the deployed
   config files that the guard is present. A headless `foot -e pwd`
   smoke test is out of scope for boot tests (it requires a display).

## Acceptance Criteria

- [ ] AC1: On a freshly rebooted workstation, pressing `$mod+Return`
      opens a foot window whose `pwd` is `/home/user`. Same for `$mod+t`.
- [ ] AC2: On first login after boot, every foot terminal spawned by the
      autostart workspace script (`08-workspaces.sh`) has `pwd ==
      /home/user`.
- [ ] AC3: The new `10-tests.sh` assertions pass and appear as PASS in
      `~/logs/boot-test-summary.txt`. Manually corrupting one of the
      three sources (e.g. removing `cd ~ &&` from
      `~/.config/home-manager/sway-config`) and re-running the test
      suite produces a FAIL — verifying the drift guard works.
- [ ] AC4: Persistence verified in all three scenarios:
      (a) `reboot` on the current workstation,
      (b) `ws.sh teardown && ws.sh setup` on the current project,
      (c) fresh project setup on a new GCP project disk with a clean
          persistent home — foot still opens in `/home/user`.
- [ ] AC5: Reviewer confirms the three-places rule is satisfied —
      `workstation-image/configs/sway/config`,
      `~/.config/home-manager/sway-config`, and
      `scripts/cloud-build-setup.sh` are consistent with respect to the
      foot-launch lines. Same for `08-workspaces.sh` repo vs `~/boot/`.
- [ ] AC6: `docs/STARTUP_SCRIPTS.md` updated if the fix changes any
      boot script's behavior or ordering, and `docs/BACKLOG.md` /
      `docs/RELEASENOTES.md` updated per the mandatory pipeline.

## Out of Scope

- Changing the default shell, shell prompt, or `~/.zshrc` CWD behavior.
- Changing the foot font (covered by F-0094).
- Replacing foot with another terminal.
- Adding a generic "launcher-CWD-sanitizer" wrapper around all GUI apps;
  the fix is scoped to foot and to the three-places discipline.

## Dependencies

- F-0087 (`e7236a8`) — previous fix for the same class of bug, now
  regressed. The 10-tests.sh assertion added in F-0087 must be extended,
  not replaced.
- Prior commit `0dd33b3` — the earlier `--working-directory` fix. The
  SWE must decide whether to standardize on `cd ~ &&` (F-0087 style) or
  `--working-directory=/home/user` (`0dd33b3` style) and apply that
  choice uniformly across sway config and `08-workspaces.sh`.
- F-0094 (foot font regression) — same persistence-failure pattern;
  the drift-guard approach in R4 mirrors the lesson from F-0094.

## Open Questions

- Which hypothesis (H1–H4) is the real root cause? The SWE must diff
  the three sources against `0dd33b3` / `e7236a8` and record the
  finding in the commit body so a future fourth regression has a
  concrete precedent.
- Should the standard be `cd ~ && $nix/foot` or
  `$nix/foot --working-directory=/home/user`? Both work; picking one
  and enforcing it in the boot test is what matters. Recommendation:
  use `--working-directory=/home/user` because it is explicit, does
  not depend on shell expansion, and is equally applicable to
  `08-workspaces.sh` invocations.
