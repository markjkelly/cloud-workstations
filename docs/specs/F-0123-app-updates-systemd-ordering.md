# F-0123: Robust fix for skipped app updates on slow boots (systemd ordering)

**Type:** Bug / Enhancement
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-06-02

## Problem

`07-apps.sh` updates all dev tools on boot (npm globals, Antigravity CLI, Copilot, OpenCode, Hub
install, `home-manager switch`). It runs **as root** inline in `setup.sh`'s sequential boot-script
loop at approximately boot+34s. It guards every `runuser` operation behind `wait_for_user_session`
— a 120-second poll that fails open if both PAM and D-Bus are not ready.

`user@1000.service` (the systemd user manager providing PAM + the D-Bus user bus) starts at a
**highly variable** time — observed boot+115s and boot+203s. On a slow boot the 120-second wait
expires before the user session is ready → the script logs:

```
WARNING — user session NOT ready after 120s; skipping all app updates
```

and exits 0, silently skipping **all** dev-tool updates. F-0121 made the logging honest but left
the fundamental race in place. Raising the timeout (option 1) is a stopgap — on an especially slow
boot, any fixed timeout can expire first.

## Requirements

1. `07-apps.sh` MUST be invoked by a systemd unit (`ws-app-updates.service`) ordered
   `After=user@1000.service network-online.target` so the OS-level ordering guarantee eliminates
   the race rather than papering over it with a larger timeout.
2. `setup.sh` MUST skip `07-apps.sh` from its inline loop (add it to the skip list alongside
   `08-workspaces.sh` and `10-tests.sh`).
3. `loginctl enable-linger user` MUST be called in `03-sway.sh` so `user@1000.service` comes up
   reliably at boot independent of interactive login — this is required for the `After=` ordering
   to be meaningful.
4. `07-apps.sh` MUST retain `wait_for_user_session` as a **defensive backstop** (it will now
   succeed in seconds because the unit ordering guarantees readiness). The comment block must be
   updated to document the new role of the wait (backstop, not primary mechanism).
5. The change MUST survive three scenarios: reboot, teardown+setup, and fresh-project setup.
   `ws-app-updates.service` is created by `03-sway.sh` on every boot (like the other services),
   so no explicit step in `cloud-build-setup.sh` is required beyond the existing boot-dir tarball.

## Acceptance Criteria

- [ ] AC1: On a boot where user@1000 reaches `active` at +200s, `~/logs/app-update.log` shows the
       run proceeding (not SKIPPED) and per-step OK.
- [ ] AC2: `ws-app-updates.service` exists at `/etc/systemd/system/ws-app-updates.service`, is
       enabled (symlink in `multi-user.target.wants/`), and its unit file contains
       `After=user@1000.service`.
- [ ] AC3: `setup.sh` no longer runs `07-apps.sh` inline — the skip guard is present.
- [ ] AC4: The change survives reboot, teardown+setup, and fresh-project setup:
       - boot scripts match repo (three-places rule for boot scripts)
       - `cloud-build-setup.sh` deploys the boot dir via tarball, picking up `03-sway.sh`
         automatically (no extra step needed)
       - `03-sway.sh` creates the service unit at every boot — unit re-creation is idempotent
- [ ] AC5: Boot tests in `10-tests.sh` pass for the new F-0123 section (static assertions on
       service unit file, enabled symlink, `After=` line, `setup.sh` skip guard, `03-sway.sh`
       grep; best-effort runtime check on `app-update.log`).

## Out of Scope

- Raising the `wait_for_user_session` timeout (stopgap rejected — a fixed timeout cannot
  guarantee success on an arbitrarily slow boot).
- Moving other boot scripts to systemd (only `07-apps.sh` has the user-session dependency that
  creates the race).
- Changes to `09-sync.sh` ordering (09-sync runs as root with no `runuser` ops; its comment
  "runs after 07-apps … so the user exists" is misleading — the user directory exists
  independently, and 09-sync does not depend on 07-apps output).

## Dependencies

- F-0121 (introduced `wait_for_user_session` in `07-apps.sh`; retained as backstop)

## Open Questions

- AC1 (runtime validation on a slow-boot scenario) and AC4 (teardown+setup / fresh-project)
  cannot be exercised without rebooting or rebuilding the live workstation. These are deferred
  to the next deployment cycle per established project convention.
