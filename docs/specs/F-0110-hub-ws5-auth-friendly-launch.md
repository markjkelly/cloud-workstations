# F-0110: Hub WS5 Auth-Friendly Launch

**Type:** Bug Fix / Enhancement
**Priority:** P1 (important)
**Status:** In Progress
**Requested by:** PO
**Date:** 2026-05-29

## Problem

Antigravity Hub (workspace 5) starts via `08-workspaces.sh` but its window never
registers within the 30-second `launch_and_wait` timeout. Hub's first-paint is
delayed because it must complete a Google OAuth flow before it renders a window.

Live evidence from `journalctl -u ws-autolaunch.service`:
```
WARNING: Timeout (30s) waiting for window on ws5: ...antigravity-hub...
All workspaces launched, switched to workspace 1
```

When the timeout fires, `08-workspaces.sh` switches focus back to ws1, so the OAuth
window (which eventually does paint) is hidden from the user. The user must manually
switch to ws5 to complete authentication — if they even know to look.

Additionally, Hub stderr output is not captured anywhere, making it impossible to
diagnose why first-paint is delayed.

## Requirements

1. The system must allow Hub at least 90 seconds to display its first window
   (OAuth flow can take 30–60 seconds on the first run).
2. The system must NOT switch focus to ws1 after the boot sequence if the Hub
   `launch_and_wait` timed out (non-zero return). Focus must remain on ws5 so the
   OAuth window is visible when it eventually paints.
3. The system must capture Hub's stdout and stderr to `~/logs/hub-launch.log`
   (append mode, with a timestamp header per boot), so failures can be diagnosed
   without re-running the service.

## Acceptance Criteria

- [ ] AC1: Hub timeout in `08-workspaces.sh` is 90 seconds (was 30s). All other
      workspace timeouts are unchanged (ws1=15, ws2=30, ws3=5, ws4=5).
- [ ] AC2: After the boot sequence, if Hub's `launch_and_wait` timed out (non-zero
      return), focus is left on ws5, not switched to ws1. If Hub launched successfully,
      focus switches to ws1 as before (existing behaviour unchanged).
- [ ] AC3: Hub stdout and stderr are redirected to `~/logs/hub-launch.log` in append
      mode. Each boot appends a timestamp header followed by the Hub process output.
      The redirection is applied at the Hub call site only; the generic
      `launch_and_wait` function signature is not changed.
- [ ] AC4: Boot tests in `10-tests.sh` verify all three changes:
      (a) Hub timeout is 90 — grep for `launch_and_wait 5 90` in `~/boot/08-workspaces.sh`.
      (b) Hub stderr redirect to `hub-launch.log` is present in the script.
      (c) The conditional ws1 focus-switch logic is present (grep for the gating
          pattern that only switches to ws1 when Hub succeeded).
- [ ] AC5: The existing false-positive test "Hub ws5 auto-launch in 08-workspaces.sh"
      is updated: the old pattern `launch_and_wait 5 30.*antigravity-hub.*--use-gl=swiftshader`
      no longer matches (Hub args are redirected/wrapped); the new test matches
      `launch_and_wait 5 90` and `\$HUB` (or the Hub variable reference).
- [ ] AC6: Script passes `bash -n` syntax check with no errors.
- [ ] AC7: Other workspace timeouts (ws1=15, ws2=30, ws3=5, ws4=5) are unchanged.

## Out of Scope

- Fixing the underlying OAuth first-paint delay in the Hub binary itself.
- Adding Hub-specific retry logic.
- Capturing stdout/stderr for other workspace apps (Chrome, Antigravity IDE, foot).

## Dependencies

- F-0107 (Hub ws5 auto-launch — must be present; this is a fixup of that feature)

## Open Questions

- None at implementation time.
