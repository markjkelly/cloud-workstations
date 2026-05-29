# F-0096: Xwayland Root Window Splits Workspace 1 at Boot

**Type:** Bug
**Priority:** P0 (critical)
**Status:** Draft
**Requested by:** PO
**Date:** 2026-04-15

## Problem

On first login after boot, Sway workspace 1 is expected to show a single
foot terminal filling the workspace. Instead, ws1 consistently shows two
tiled windows side-by-side:

- **Left half:** the Xwayland root window
  (`app_id=org.freedesktop.Xwayland`, `name=Xwayland on :0`)
- **Right half:** the foot terminal spawned by the autostart workspace
  script

Live inspection via `swaymsg -t get_tree` on the running workstation
confirmed the two siblings on ws1. The PO expects ws1 to contain exactly
one window — the foot terminal — just like every other autostart
workspace (ws2=Chrome, ws3=Antigravity, ws4=foot).

## Reproduction

1. Fresh boot (or `ws.sh teardown && ws.sh setup` followed by login).
2. Wait for `08-workspaces.sh` to finish the autostart sequence.
3. Focus workspace 1.

**Expected:** a single fullscreen foot terminal fills ws1.
**Actual:** two tiled windows split ws1 50/50 — Xwayland on the left,
foot on the right.

Inspection command that demonstrates the bug:

```
swaymsg -t get_tree | jq '.nodes[] | .. | select(.type? == "workspace" and .name == "1") | .nodes[] | {app_id, name}'
```

returns two entries, one with `app_id == "org.freedesktop.Xwayland"`.

## Root Cause

`workstation-image/boot/08-workspaces.sh:70` executes:

```
sway_cmd exec "/usr/bin/Xwayland :0"
```

This was added to provide an X11 display server for IntelliJ and other
X11-only apps (DISPLAY=:0). Because the command is run via `sway_cmd
exec` while ws1 is the active workspace, the Xwayland process creates a
visible **root window** that Sway tiles onto ws1 alongside the foot
terminal. Xwayland is running without `-rootless`, so it paints a
workspace-sized window instead of acting as a transparent X-to-Wayland
bridge for individual X11 clients.

## Requirements

1. **R1 — Single window on ws1 at boot.** After `08-workspaces.sh`
   completes, Sway workspace 1 must contain exactly one visible window:
   the foot terminal. No Xwayland root window, no other stray clients.
2. **R2 — X11 app support preserved.** IntelliJ and other X11 apps that
   rely on `DISPLAY=:0` must continue to launch correctly. The fix must
   not regress F-0027 or F-0056 (IntelliJ keybinding) — `DISPLAY=:0`
   must still resolve to a working X server when X11 apps start.
3. **R3 — Three-places-rule compliance.** If the fix changes any config
   that lives in more than one source of truth, all three must be
   updated in lockstep:
   - the **repo** copy under `workstation-image/`,
   - the **live** copy on the workstation (e.g. `~/boot/`, or
     `~/.config/home-manager/sway-config`),
   - `scripts/cloud-build-setup.sh` so fresh-project setups deploy the
     fixed version.
4. **R4 — Mandatory boot-test coverage.** Extend
   `workstation-image/boot/10-tests.sh` so every boot asserts:
   - no window with `app_id == "org.freedesktop.Xwayland"` is present
     on any workspace after `08-workspaces.sh` completes, AND
   - `DISPLAY=:0` still points at a reachable X server (a lightweight
     check such as `xdpyinfo -display :0 >/dev/null` or equivalent,
     guarded so it does not require a logged-in graphical session when
     run from a non-graphical context — use whatever the rest of
     `10-tests.sh` already uses for Xwayland-reachability checks).
   Failures must surface in `~/logs/boot-test-summary.txt`.
5. **R5 — No live-only fixes.** Changes must be committed to the repo
   and verified through `ws.sh setup` so teardown + re-setup yields a
   working ws1 layout.

## Implementation Options (SWE to choose one)

The bug admits three plausible fixes. The SWE owning F-0096 should pick
one based on ergonomics, survivability across boots, and minimal blast
radius. Record the chosen option and the reasoning in the commit body.

### Option 1 — Sway `for_window` rule to hide the Xwayland root

Add a rule to the sway config that matches the Xwayland root window and
either moves it to the scratchpad or marks it as unmanaged, e.g.:

```
for_window [app_id="org.freedesktop.Xwayland"] move to scratchpad, kill
```

or

```
for_window [app_id="org.freedesktop.Xwayland"] floating enable, move scratchpad
```

**Pros:** one-line fix, no change to Xwayland invocation, fully
contained in the sway config (so the three-places rule reduces to "keep
repo and `~/.config/home-manager/sway-config` in sync").
**Cons:** treats the symptom, not the cause — the root window still
spawns, just gets hidden. Feels hacky. Relies on Sway rule evaluation
timing being reliable.

### Option 2 — Launch Xwayland with `-rootless`

Change `08-workspaces.sh:70` so Xwayland runs in rootless mode:

```
sway_cmd exec "/usr/bin/Xwayland -rootless :0"
```

In rootless mode, Xwayland does not create a visible root window; it
only creates surfaces for individual X11 clients, which is the correct
behavior under a Wayland compositor.

**Pros:** fixes the root cause — no phantom window ever spawns. Matches
how most Wayland compositors drive Xwayland. One-line change, no sway
config churn.
**Cons:** behavior under `-rootless` must be verified with IntelliJ
(F-0027/F-0056) to make sure the existing X11 launch path still works.
Needs `08-workspaces.sh` updated in the repo AND the live `~/boot/`
copy.

### Option 3 — Launch Xwayland outside of `sway_cmd exec`

Move the Xwayland startup out of `08-workspaces.sh` into a dedicated
systemd user service (or into `03-sway.sh`) so it runs alongside
`sway-desktop.service` without being owned by a workspace. Sway still
auto-attaches when X11 clients connect, but the spawn is not bound to
ws1.

**Pros:** clean separation of concerns — display server lifecycle
managed by systemd, not by an autostart script. Side-steps the "current
workspace at spawn time" question entirely.
**Cons:** largest blast radius — new systemd unit, new boot script,
ordering dependencies to manage (Xwayland must be up before IntelliJ
launches). Might conflict with Sway's own Xwayland management.

**Recommendation:** Option 2 is the lowest-risk root-cause fix. Option
1 is acceptable as a defensive belt-and-braces addition on top of
Option 2, but not as a standalone fix. Option 3 should only be chosen
if Options 1 and 2 are both shown to fail during verification.

## Acceptance Criteria

- [ ] AC1: After boot + `08-workspaces.sh` completion,
      `swaymsg -t get_tree` shows ws1 containing exactly one foot
      terminal and zero Xwayland root windows.
- [ ] AC2: IntelliJ still launches via its sway keybinding
      (`CTRL+SHIFT+M`, F-0056) and renders correctly under
      `DISPLAY=:0`. No regression in VSCode or other IDE keybindings.
- [ ] AC3: The new `10-tests.sh` assertion (no Xwayland root window on
      any workspace, X server reachable at `:0`) passes and appears as
      PASS in `~/logs/boot-test-summary.txt`. Manually undoing the fix
      (e.g. reverting `-rootless`, or removing the `for_window` rule)
      and re-running the tests produces a FAIL.
- [ ] AC4: Persistence verified in all three scenarios:
      (a) `reboot` on the current workstation,
      (b) `ws.sh teardown && ws.sh setup` on the current project,
      (c) fresh project setup on a new GCP project disk with a clean
          persistent home — ws1 still shows only the foot terminal.
- [ ] AC5: Reviewer confirms the three-places rule is satisfied for
      whichever files the fix touches (sway config, `08-workspaces.sh`,
      or both, plus their home-manager/`~/boot/` counterparts and
      `scripts/cloud-build-setup.sh`).
- [ ] AC6: `docs/BACKLOG.md` and `docs/RELEASENOTES.md` updated per the
      mandatory pipeline. `docs/STARTUP_SCRIPTS.md` updated if the fix
      changes any boot script's purpose, ordering, or adds a new unit.

## Out of Scope

- Replacing Xwayland with a different X11 bridge.
- Changing the default ws1 app away from foot.
- Moving Xwayland to a different DISPLAY number.
- Broader refactor of `08-workspaces.sh` — changes are scoped to the
  Xwayland invocation line and, if chosen, a single sway `for_window`
  rule.

## Dependencies

- **F-0027** — weekday auto-start / boot orchestration. This bug is
  only visible because F-0027 brings the workstation up unattended; the
  fix must not regress that flow.
- **F-0029** — autostart workspaces (`08-workspaces.sh`). The line
  under suspicion lives in the script introduced here.
- **F-0056** — IDE keybindings (IntelliJ on `DISPLAY=:0`). The fix
  must preserve the X11 launch path this feature relies on.
- **F-0073** — boot test script (`10-tests.sh`). R4's drift guard
  plugs into the existing test harness.

## Open Questions

- Does Xwayland `-rootless` behave identically to the current invocation
  for IntelliJ on this workstation? SWE must verify before committing.
- Should Option 1's `for_window` rule be added as a defense-in-depth
  layer even when Option 2 is the primary fix, or would it mask a
  future regression? Recommendation: skip it so a future regression
  still surfaces, but record the decision in the commit body.
