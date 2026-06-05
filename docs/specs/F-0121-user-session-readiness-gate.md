# F-0121: Gate boot scripts on user-session readiness

**Type:** Bug Fix / Enhancement
**Priority:** P0 (critical)
**Status:** Done (Part A)
**Requested by:** PO
**Date:** 2026-05-29

## Problem

Two distinct but related timing failures occur on every cold boot:

### Confirmed bug: 07-apps.sh runs ~83s before the user session exists

A live cold-boot trace (boot at 20:10:10 PDT) shows the following timeline:

- **+32s (20:10:42):** `07-apps.sh` runs (as root, via `setup.sh`). Every
  `runuser -u user -- …` call fails with:
  > `runuser: user user does not exist or the user entry does not contain all
  > the required fields`

  `getent passwd user` cannot resolve the user entry because `user@1000.service`
  (the systemd user manager) hasn't started yet — NSS/PAM infrastructure is
  not up.

- **+115s (20:12:05):** `user@1000.service` comes up — D-Bus session bus socket,
  gnome-keyring socket, "Startup finished".

- **+115s–present:** Hub launches, retry succeeds, session fully ready.

**Impact:** ALL app updates (npm globals, Antigravity CLI, GitHub Copilot,
OpenCode, `home-manager switch`) silently fail on every cold boot. Worse,
`07-apps.sh` logs a false `"… complete"` unconditionally after each failing
`runuser`, so the logs claim success when the commands never ran.

### Strong hypothesis: Hub launches before D-Bus/keyring/portal session is ready

- **+118s (20:12:08):** `ws-autolaunch.service` starts — only 3s after
  `user@1000.service`.
- **+128s (20:12:18):** Hub launches; its first `language_server --standalone`
  spawn fails (no process, blank ws1) while D-Bus session is still activating
  portals/gvfs/keyring (20:12:16–17).
- **+234s (20:14:01):** Hub Attempt 2 (F-0117 retry) succeeds — by now the
  session is fully ready.

This is a strong correlation with the recurring blank-ws1 cold-boot bug, but
not yet proven. The F-0117 retry backstop must be kept in place.

## Requirements

1. A reusable `wait_for_user_session` helper must be defined in both affected
   scripts (no shared sourced library exists; duplication is acceptable and
   documented).
2. The helper must poll until BOTH of these hold or a timeout elapses:
   - `runuser -u user -- true` returns 0 (user entry resolvable, PAM session
     can open), AND
   - The user D-Bus session bus is reachable (`dbus-send` probe on
     `unix:path=/run/user/1000/bus`; fall back to `busctl` or `gdbus` if
     absent; all three are confirmed present on this Ubuntu 24.04 base)
3. Timeout is 120 seconds. Fail-open: after timeout, log a WARNING and
   continue — never block boot forever.
4. Poll interval is 2 seconds. Each poll outcome and final state (ready
   after Ns / timed out after Ns) must be logged.
5. **Part A — 07-apps.sh:** call `wait_for_user_session` before the first
   `runuser` update operation. If timed out, SKIP updates with a clear
   WARNING (do not run them into a broken session).
6. **Part A — fix silent-failure logging:** every update step must check the
   exit status of its `runuser` command and log real success or failure.
   No more unconditional `"… complete"` after a step. Apply to all steps:
   npm globals, Antigravity Hub, Antigravity CLI, GitHub Copilot, OpenCode,
   Nix/home-manager.
7. **Part B — 08-workspaces.sh:** call `wait_for_user_session` after "Sway
   is ready" and before the F-0115 gnome-keyring block and Hub launch block.
   Fail-open. Log how long the wait took.
8. All existing resilience mechanisms (F-0117 retry, F-0118 diagnostics,
   F-0119/F-0120 shim, F-0114 singleton cleanup) must be preserved intact.

## Acceptance Criteria

- [ ] **AC1 — real per-step success/failure in 07-apps.sh:** `app-update.log`
  shows per-step PASS/FAIL lines; no step logs `"complete"` when its `runuser`
  failed.
- [ ] **AC2 — 07-apps waits for session:** `app-update.log` shows
  `wait_for_user_session` log lines (polling and final ready/timeout) on a
  cold boot where `07-apps.sh` runs before `user@1000.service`.
- [ ] **AC3 — 08-workspaces waits for session:** `08-workspaces.sh` log
  shows `wait_for_user_session` log lines before the Hub launch block.
- [ ] **AC4 (hypothesis, validate on reboot):** Next cold boot: first
  `--standalone` spawn reaches the shim (`~/logs/ls-spawn.log` shows a
  `--standalone` header on Attempt 1) and `Port changed!` fires without
  needing Attempt 2.
- [ ] **AC5 — fail-open:** a 120s timeout in `wait_for_user_session` must
  log a WARNING and allow the script to proceed, never hang indefinitely.
- [ ] **AC6 — three-places parity:** repo scripts, `~/boot/` scripts, and
  `scripts/cloud-build-setup.sh` coverage all confirmed.

## Out of Scope

- Changing the `runuser -u user` mechanism (it works once the session is up).
- Modifying `ws-autolaunch.service` directly (boot-script-only change).
- Removing the F-0117 retry loop (kept as a backstop).

## Dependencies

- F-0117 (Hub retry loop — preserved, not changed)
- F-0118, F-0119, F-0120 (LS diagnostics/shim — preserved, not changed)

## Open Questions

- Whether Part B (D-Bus readiness gate before Hub launch) is the root cause
  of blank-ws1 at cold boot, or merely a contributing factor. The F-0118
  sampler and F-0119/F-0120 shim will provide ground-truth evidence on the
  next cold boot. Validate by checking `~/logs/ls-spawn.log` (first
  `--standalone` attempt) and `~/logs/hub-launch.log` (`Port changed!` on
  Attempt 1 vs Attempt 2).
