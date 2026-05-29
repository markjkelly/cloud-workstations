# F-0097: Xwayland `-rootless` Flag Lost After Reboot (F-0096 Regression)

**Type:** Bug
**Priority:** P0 (critical)
**Status:** Draft
**Requested by:** PO
**Date:** 2026-04-15

## Problem

F-0096 shipped in v1.17.1 and changed `workstation-image/boot/08-workspaces.sh`
to launch Xwayland with `-rootless` so the bare X root window would no longer
tile onto workspace 1. Static inspection of both the repo and the live
workstation confirms the flag is present in the script:

```
sway_cmd exec "/usr/bin/Xwayland -rootless :0"
```

However, after a reboot of the running workstation, the bug from F-0096
returns:

- `pgrep -af Xwayland` on the live system shows
  `/usr/bin/Xwayland :0` — **no `-rootless` flag** on the running process.
- `10-tests.sh` reports
  `FAIL: Xwayland root window(s) present in sway tree: 1 (F-0096 regression)`.
- Workspace 1 is once again split 50/50 between the Xwayland root window and
  the foot terminal.

At the same time, the boot-test assertion that was added as part of F-0096
(static grep for `-rootless` in `08-workspaces.sh`) still **PASSES**. In other
words, the file on disk is correct, the test we added confirms the file on
disk is correct, but the Xwayland process that actually runs is the old
non-rootless invocation. Our test was too weak: it proved the flag was typed
into the script, not that the flag was ever honored at runtime.

This is a P0 regression of F-0096 and a P0 test-coverage gap.

## Reproduction

1. On a workstation that already has v1.17.1 deployed, confirm the repo and
   the live copy of `~/boot/08-workspaces.sh` both contain
   `/usr/bin/Xwayland -rootless :0`.
2. `sudo reboot` (or `ws.sh teardown && ws.sh setup` + login).
3. After login, run:
   ```
   pgrep -af Xwayland
   swaymsg -t get_tree | jq '.. | select(.app_id? == "org.freedesktop.Xwayland")'
   cat ~/logs/boot-test-summary.txt
   ```

**Expected:**
- The Xwayland process line includes `-rootless`.
- No node in the sway tree has `app_id == "org.freedesktop.Xwayland"`.
- Boot-test summary is all PASS.

**Actual:**
- Xwayland process line is `/usr/bin/Xwayland :0` (flag missing).
- Sway tree contains an Xwayland root window on ws1.
- `10-tests.sh` prints
  `FAIL: Xwayland root window(s) present in sway tree: 1 (F-0096 regression)`.

## Root Cause Hypothesis

`08-workspaces.sh` guards its Xwayland launch with a `pgrep -f "Xwayland :0"`
check. When the guard sees an already-running Xwayland process, it skips the
launch and the rootless invocation in the script **never executes**. The flag
sitting in the source file is therefore dead code under any path where
something else has already started Xwayland.

On this workstation, Sway is configured to spawn Xwayland on demand (Sway's
default behavior: the first time an X11 client connects, Sway forks an
Xwayland under its own management, without `-rootless`). By the time
`08-workspaces.sh` runs, either:

- Sway has already auto-spawned Xwayland in response to an early X11 client
  (e.g. an autostart, the waybar tray, an IME daemon, or the foot terminal
  pulling in a D-Bus service with X11 hooks), OR
- a different autostart script has launched Xwayland non-rootless earlier in
  the boot sequence.

In either case, our guard fires "already running, skip" and the `-rootless`
version is never started. The running process that the tests and users see is
Sway's on-demand Xwayland, launched without any flags.

This hypothesis matches the observation that the static grep passes (file is
correct) while the runtime process args are wrong (our launch never happened).

## Proposed Fix Options

The SWE owning F-0097 should pick one and record the reasoning in the commit
body. Options are ordered roughly by directness of root-cause fix.

### Option A — Disable Sway's on-demand Xwayland and own the launch ourselves

Add `xwayland disable` to the sway config and keep `08-workspaces.sh`'s
`-rootless` launch as the **only** Xwayland starter on the system.

- **Pros:** single source of truth for Xwayland args; no race with Sway's
  auto-spawn; guarantees our `-rootless` invocation is the one that runs.
  Directly eliminates the unknown "who started Xwayland first?" question.
- **Cons:** any X11 client that starts before `08-workspaces.sh` finishes
  will fail to connect (no DISPLAY yet). Need to verify boot ordering: the
  autostart script must run before anything that touches `DISPLAY=:0`.
  Touches two files under the three-places rule (sway config lives in the
  repo, in `~/.config/home-manager/sway-config`, and in
  `scripts/cloud-build-setup.sh`).

### Option B — Detect-and-replace guard in `08-workspaces.sh`

Change the guard so that if an Xwayland `:0` process is already running
**without** `-rootless`, the script kills it and relaunches with `-rootless`.
Pseudocode:

```
existing=$(pgrep -af "Xwayland :0" || true)
if [ -n "$existing" ] && ! echo "$existing" | grep -q -- -rootless; then
    pkill -f "Xwayland :0" || true
    sleep 1
fi
if ! pgrep -f "Xwayland -rootless :0" >/dev/null; then
    sway_cmd exec "/usr/bin/Xwayland -rootless :0"
fi
```

- **Pros:** no sway-config change; contained to the script we already
  modified for F-0096; tolerant of whatever spawns Xwayland first.
- **Cons:** treats the symptom. Killing Sway's on-demand Xwayland may disrupt
  any X11 client that has already attached (brief flicker or reconnect). Adds
  ordering fragility — if an X11 client attaches between the pkill and the
  relaunch, it sees no display.

### Option C — Keep-and-tolerate: accept Sway's on-demand Xwayland, hide the root window

If the real user-visible complaint is "ws1 is split," we can leave Xwayland's
launch to whoever wins and instead suppress the root window via a sway
`for_window` rule:

```
for_window [app_id="org.freedesktop.Xwayland"] kill
```

- **Pros:** smallest change; no process lifecycle juggling.
- **Cons:** this was explicitly rejected in F-0096 in favor of the
  root-cause fix. Re-adopting it would reverse that decision and leaves the
  non-rootless Xwayland running for any future edge case. Keep on the table
  only as a defensive layer on top of A or B.

### Recommendation

Option A is the cleanest root-cause fix and matches how Wayland compositors
are typically configured when the user wants full control over Xwayland args.
Option B is an acceptable fallback if boot-ordering verification for A
uncovers early X11 clients we cannot reorder. Option C should only be layered
on top, not chosen alone.

## Requirements

1. **R1 — Running Xwayland uses `-rootless`.** After every boot, the single
   Xwayland process bound to `:0` must have `-rootless` in its command line.
   No non-rootless Xwayland may be running on `:0`.
2. **R2 — F-0096 acceptance preserved.** Workspace 1 shows exactly one
   window (the foot terminal) after `08-workspaces.sh` completes. No
   `org.freedesktop.Xwayland` node in the sway tree.
3. **R3 — X11 apps still work.** IntelliJ and any other X11 client launched
   via `DISPLAY=:0` must connect successfully (F-0027, F-0056 preserved).
4. **R4 — Runtime boot-test coverage.** `workstation-image/boot/10-tests.sh`
   must assert at runtime, not only by static grep:
   - `pgrep -af Xwayland` returns exactly one process, and its command line
     contains `-rootless`.
   - `swaymsg -t get_tree` contains zero nodes with
     `app_id == "org.freedesktop.Xwayland"`.
   - `DISPLAY=:0` is reachable (existing xdpyinfo-style check).
   Failures must surface in `~/logs/boot-test-summary.txt`. The existing
   static-grep assertion may remain, but it is not sufficient on its own.
5. **R5 — Three-places rule.** Whichever files the fix touches (sway
   config and/or `08-workspaces.sh`) must be updated in all three locations:
   repo, live copy (`~/boot/` or `~/.config/home-manager/sway-config`), and
   `scripts/cloud-build-setup.sh`.
6. **R6 — No live-only fix.** Changes land in the repo, get pushed, and are
   verified through `ws.sh setup` so a teardown + re-setup reproduces the
   working state.
7. **R7 — STARTUP_SCRIPTS.md updated** if the fix changes any boot script's
   purpose, ordering, or adds a new unit.

## Acceptance Criteria

- [ ] AC1 — **Runtime process check:** After a full reboot,
      `pgrep -af Xwayland | grep -- -rootless` matches exactly one line and
      `pgrep -af Xwayland | grep -v -- -rootless` matches zero lines.
- [ ] AC2 — **Sway tree check:** After `08-workspaces.sh` completes,
      `swaymsg -t get_tree | jq '.. | select(.app_id? == "org.freedesktop.Xwayland")'`
      returns empty.
- [ ] AC3 — **Boot-test harness:** `~/logs/boot-test-summary.txt` shows PASS
      for both the new runtime Xwayland-args check and the existing
      F-0096 sway-tree check. Manually starting a non-rootless Xwayland (or
      reverting the fix) causes the runtime check to report FAIL.
- [ ] AC4 — **X11 apps preserved:** IntelliJ still launches via its sway
      keybinding (F-0056) under `DISPLAY=:0`. No regression in VSCode or
      other IDE keybindings.
- [ ] AC5 — **Persistence across three scenarios:**
      (a) `reboot` on the current workstation,
      (b) `ws.sh teardown && ws.sh setup` on the current project,
      (c) fresh project setup on a new GCP project disk —
      ws1 shows only the foot terminal and the running Xwayland has
      `-rootless` in all three.
- [ ] AC6 — **Three-places rule:** Reviewer confirms repo, live copy, and
      `scripts/cloud-build-setup.sh` are in lockstep for every touched file.
- [ ] AC7 — **Docs updated:** `docs/BACKLOG.md` carries F-0097 through to
      done; `docs/RELEASENOTES.md` has a new version entry; `docs/PROGRESS.md`
      captures the session; `docs/STARTUP_SCRIPTS.md` updated if a boot
      script's purpose or ordering changed.

## Out of Scope

- Removing Xwayland entirely or replacing it with an alternative X11 bridge.
- Moving Xwayland off DISPLAY `:0`.
- Wider refactor of `08-workspaces.sh` beyond the Xwayland guard.
- Revisiting F-0096's choice between Options 1/2/3 for the non-rootless bug —
  F-0097 builds on Option 2 and is concerned only with making that choice
  actually take effect at runtime.

## Dependencies

- **F-0096** — Xwayland root-window-on-ws1 fix. F-0097 is the regression
  follow-up; F-0096's `-rootless` change must remain in the repo.
- **F-0027** — weekday auto-start / boot orchestration. The fix must not
  regress unattended boot.
- **F-0056** — IntelliJ keybinding on `DISPLAY=:0`. X11 launch path must
  keep working.
- **F-0073** — boot test script (`10-tests.sh`). Runtime check extends the
  existing test harness.

## Open Questions

- **Who actually starts Xwayland first on this workstation?** The SWE should
  capture `pgrep -af Xwayland` and `ps -eo pid,ppid,comm,args | grep -i
  xwayland` immediately after boot, before `08-workspaces.sh` runs, to
  confirm whether Sway's on-demand spawn or another autostart wins the race.
  This data drives the choice between Option A and Option B.
- **Does `xwayland disable` in sway cause any early X11 client to fail?** If
  yes, Option A needs a startup-ordering tweak or falls back to Option B.
- **Should the runtime test also verify `-rootless` specifically, or just
  "no Xwayland root window in tree"?** Recommendation: check **both** —
  process args AND sway tree — so a future regression in either direction
  (flag lost, or root window appears despite flag) surfaces immediately.
