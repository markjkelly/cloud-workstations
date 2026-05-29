# F-0116: Remove Antigravity IDE and fix Hub window placement on workspace 1

**Type:** Bug / Enhancement
**Priority:** P0 (critical — Hub blank/disappearing on ws1 is the primary user symptom)
**Status:** Done
**Requested by:** PO (Mark Kelly)
**Date:** 2026-05-29

## Problem

The Antigravity Hub (ws1) was showing "logged in, then goes blank, then disappears" at boot.
Investigation confirmed the root cause is a **sway app_id collision** between the Hub and the
Antigravity IDE:

- Hub binary: `~/.local/bin/antigravity-hub` → `~/.local/share/antigravity-hub/antigravity`
  - sway `app_id`: `antigravity`
- IDE binary: `/usr/bin/antigravity` → `/usr/share/antigravity/antigravity`
  - sway `app_id`: `antigravity`

Both Electron apps report the same `app_id = "antigravity"` to sway. Because no
`for_window [app_id="antigravity"]` placement rule existed, the Hub's window mapping was
subject to a race condition:

1. The Hub maps its BrowserWindow **asynchronously** — only after the bundled `language_server`
   starts, picks a dynamic HTTPS port, and fires "[Auto-Restart] Port changed! Reloading all
   windows."
2. At cold boot this async mapping happens after `launch_and_wait 1 90` times out (90s), by
   which time focus has drifted to later-launched apps (foot terminals on ws3/ws4).
3. The Hub window therefore maps on whichever workspace is focused at that point — NOT ws1 —
   making it appear to vanish.

The `--class=antigravity-hub` launch flag does NOT change the Electron `app_id` on the
installed Hub build. The only path to a deterministic fix is:

1. Remove the IDE (eliminating the collision), then
2. Add `for_window [app_id="antigravity"] move container to workspace number 1` — now
   unambiguous because the IDE is gone — which pins the Hub to ws1 regardless of when its
   window maps.

The PO has approved "remove only, no reinstall."

## Requirements

1. The Antigravity IDE (`/usr/bin/antigravity`, `/usr/share/antigravity`) MUST be removed from
   all install paths: Dockerfile, `07-apps.sh`, `scripts/cloud-build-setup.sh`.
2. The Antigravity Hub (`~/.local/bin/antigravity-hub`) MUST remain installed and working.
3. `08-workspaces.sh` MUST no longer launch the IDE on ws2. The ws2 launch block MUST be
   removed (ws2 is left empty — no replacement).
4. The `$ANTIGRAVITY` variable MUST be removed from `08-workspaces.sh`.
5. The sway config keybindings pointing at `/usr/bin/antigravity` (`$mod+n`, `$mod+g`) MUST
   be removed.
6. `workstation-image/configs/sway/config` MUST gain:
   `for_window [app_id="antigravity"] move container to workspace number 1`
7. The three-places persistence rule MUST be satisfied:
   - Repo: `workstation-image/configs/sway/config`
   - Home-manager source: `~/.config/home-manager/sway-config`
   - Setup script: `scripts/cloud-build-setup.sh` (deploying the sway config)
8. Boot scripts on disk (`~/boot/`) MUST be updated to match the repo.
9. `10-tests.sh` MUST be updated: remove IDE-presence assertions, add IDE-absence and
   Hub-placement-rule assertions.

## Acceptance Criteria

- [ ] `/usr/bin/antigravity` is NOT present on the workstation (or is not installed on fresh setup)
- [ ] `~/.local/bin/antigravity-hub` IS present and functional
- [ ] `08-workspaces.sh` does NOT launch `$ANTIGRAVITY` or any `launch_and_wait 2 ...` IDE call
- [ ] Sway config contains `for_window [app_id="antigravity"] move container to workspace number 1`
- [ ] Sway config does NOT contain keybindings referencing `/usr/bin/antigravity`
- [ ] Three sway config copies are byte-identical on the relevant lines
- [ ] Boot tests pass: IDE-absent, rule-present, removed-keybindings-absent
- [ ] Hub window (app_id `antigravity`) lands on ws1 and stays after relaunch

## Out of Scope

- Installing any replacement IDE on ws2
- Modifying the Hub binary, its launch flags, or its auth flow
- Changing workspace numbering or other keybindings

## Dependencies

- F-0112 (Hub on ws1, Chrome on ws5)
- F-0115 (keyring for Hub OAuth token persistence)

## Open Questions

- None — PO has approved the removal-only approach.
