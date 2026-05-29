# F-0114: Hub stale singleton lock cleanup before launch

**Type:** Bug
**Priority:** P0 (critical)
**Status:** Done
**Requested by:** PO
**Date:** 2026-05-29

## Problem

After an unclean shutdown or reboot, the Antigravity Hub (ws1) can fail to appear entirely.
Root cause (diagnosed live by the orchestrator):

1. The Hub's user-data-dir (`~/.config/Antigravity-Hub`) retains stale Electron singleton
   files from the previous session: `SingletonLock` (symlink to `sway-workstation-<pid>`),
   `SingletonCookie`, and `SingletonSocket`.
2. On the next boot, Electron detects the stale `SingletonLock` and refuses to start a new
   instance — or, even when it starts, the bundled `language_server` never reports its
   dynamic port back to Electron, so Electron never creates a BrowserWindow, no Wayland
   surface appears on ws1, and `launch_and_wait` times out after 90 s.
3. Additionally, orphaned `antigravity-hub` / `language_server` processes lingering from
   an earlier unclean shutdown can hold the lock or interfere with the new instance.

The orchestrator recovered the wedged boot live by: killing all Hub processes + the Hub's
`language_server`, deleting `~/.config/Antigravity-Hub/Singleton*`, and relaunching. The
window mapped in ~4 s, confirming the stale lock (not the timeout) is the root cause.

## Requirements

1. Before launching the Hub on ws1, `08-workspaces.sh` must kill any pre-existing Hub
   processes using safe, targeted process matching (not a broad `pkill -f` pattern that
   could self-terminate the boot script).
2. Before launching the Hub on ws1, `08-workspaces.sh` must remove stale Electron
   singleton lock files from `~/.config/Antigravity-Hub/`.
3. The cleanup must be logged using the existing `log()` helper.
4. The process-kill must use safe patterns: `pgrep` filtered by exe path for
   `antigravity-hub/antigravity`, and cmdline-filtered pgrep for `language_server`
   instances belonging to `antigravity-hub/resources`.
5. A test in `10-tests.sh` must verify the stale-lock cleanup is present in the script.

## Acceptance Criteria

- [ ] `08-workspaces.sh` contains a cleanup block immediately before the Hub
      `launch_and_wait` call that removes `~/.config/Antigravity-Hub/Singleton*`.
- [ ] The cleanup block kills orphaned Hub processes safely (no broad `pkill -f` that
      matches the boot script's own command line).
- [ ] A log message reports how many processes were reaped and confirms lock removal.
- [ ] `10-tests.sh` has a new test section verifying the cleanup lines are present in
      `~/boot/08-workspaces.sh`.
- [ ] The repo copy, `~/boot/08-workspaces.sh` (live), and `scripts/cloud-build-setup.sh`
      (fresh-project setup) are all consistent.

## Out of Scope

- Hub sign-in / authentication ("You are not logged into Antigravity" in LS log) — that
  is a separate manual concern and NOT caused by this bug.
- IDE (`~/.config/Antigravity`) stale-lock cleanup — the IDE did not exhibit this failure;
  keeping scope tight to the reported regression.

## Dependencies

- F-0111 (Hub user-data-dir isolation — established `--user-data-dir=/home/user/.config/Antigravity-Hub`)
- F-0112 (Hub moved to ws1)

## Open Questions

None — root cause fully confirmed by live recovery.
