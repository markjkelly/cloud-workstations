# F-0112: Swap Chrome and Hub Workspace Assignments

**Type:** Enhancement
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-05-29

## Problem

Since F-0110 and F-0111, the Antigravity Hub is on ws5 and Chrome is on ws1. The Hub is the primary
working surface (OAuth entry point, main app UI), and Chrome is a background dependency needed mainly
for IDE OAuth flows. Having to navigate to ws5 to reach the Hub on every boot is backwards — the user
lands on ws1 (Chrome) when they should land on the Hub.

The desired default: boot drops focus on ws1 = Hub, with Chrome available on ws5 as a background app.

## Requirements

1. `08-workspaces.sh` must launch the Antigravity Hub on workspace 1 (not ws5).
2. Google Chrome must be launched on workspace 5 (not ws1).
3. All F-0110 and F-0111 flags, timeouts, and log-redirection for the Hub must travel with it to ws1.
4. Chrome retains its `--disable-gpu` flag (F-0111) and its 15s timeout.
5. The Antigravity IDE (ws2) and both foot terminals (ws3, ws4) are unchanged.
6. End-of-boot focus logic: the user lands on ws1 (now the Hub) after a successful boot. The F-0110
   "leave focus on the Hub's workspace if it timed out" intent still applies — but "Hub's workspace"
   is now ws1. On both success and timeout, the final focused workspace is ws1 (Hub).
7. The header comment block in `08-workspaces.sh` must reflect the new layout.
8. `10-tests.sh` must be updated: tests that assert Chrome on ws1 or Hub on ws5 must be corrected
   to Chrome on ws5 / Hub on ws1. The F-0110 Hub-timeout grep test must reference ws1 (not ws5).

## Launch Order Decision

The IDE on ws2 needs Chrome available for its OAuth flow. To preserve that dependency:

- Launch Chrome (ws5) FIRST — 15s timeout, quick to start, gives IDE a browser to OAuth against.
- Launch Hub (ws1) SECOND — 90s timeout, may need OAuth itself.
- Launch IDE (ws2) THIRD — 30s timeout.
- Launch foot (ws3, ws4) FOURTH/FIFTH.

This means focus visits ws5 → ws1 → ws2 → ws3 → ws4 during boot, ending on ws1 (Hub).

## Acceptance Criteria

- [ ] `launch_and_wait 1 90 "$HUB" ...` (Hub on ws1, 90s timeout)
- [ ] `launch_and_wait 5 15 google-chrome-stable ...` (Chrome on ws5, 15s timeout)
- [ ] Hub launch flags intact: `--no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage --user-data-dir=/home/user/.config/Antigravity-Hub`
- [ ] Chrome launch flags intact: `--ozone-platform=wayland --disable-dev-shm-usage --disable-gpu`
- [ ] Hub log-redirect block targets ws1.
- [ ] End-of-boot focus: ws1 (Hub) regardless of success or timeout.
- [ ] Header comment: `ws1 = Hub, ws2 = Antigravity IDE, ws3 = foot, ws4 = foot, ws5 = Chrome`
- [ ] `bash -n` passes on updated `08-workspaces.sh`.
- [ ] `10-tests.sh` Hub grep test references `launch_and_wait 1 90`.
- [ ] `10-tests.sh` ws1 = Hub, ws5 = Chrome assertions correct.
- [ ] `~/boot/08-workspaces.sh` and `~/boot/10-tests.sh` updated live (three-places rule).
- [ ] `docs/STARTUP_SCRIPTS.md` workspace-layout description updated.

## Out of Scope

- Changing the IDE (ws2) or foot terminals (ws3, ws4).
- Sway config `$mod+h` keybinding (currently `workspace number 5`). After this swap ws5 = Chrome,
  not Hub. The keybinding will still work (it navigates to ws5) but the semantic label is now
  "Chrome workspace". A follow-up spec can remap this; it is not broken, just mislabeled.

## Dependencies

- F-0110 (Hub 90s timeout, log redirect, conditional focus)
- F-0111 (--disable-gpu, --user-data-dir for Hub)
