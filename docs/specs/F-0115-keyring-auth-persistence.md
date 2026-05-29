# F-0115: Keyring Secret Service for Hub OAuth Token Persistence

**Type:** Bug Fix
**Priority:** P0 (critical)
**Status:** Done
**Requested by:** PO
**Date:** 2026-05-29

## Problem

The Antigravity 2.0 Hub (Electron app on ws1) authenticates successfully on first
paint ("logged in" is briefly visible), then immediately blanks and reverts to the
logged-out state. The window disappears or re-shows the sign-in page on every boot.

Root cause: the Hub's bundled Go `language_server` stores and reloads its OAuth token
via the system Secret Service (freedesktop.org keyring API). There is no Secret Service
provider running in the headless Sway session, so every token persist and reload fails:

```
auth_client.go:332] Failed to persist token to keyring:
    failed to unlock correct collection '/org/freedesktop/secrets/aliases/default'
auth_client.go:106] Background token refresh failed: failed to load token:
    failed to unlock correct collection '/org/freedesktop/secrets/aliases/default'
```

The Hub is also logging: "Failed to connect to the bus: Could not parse server
address" because `DBUS_SESSION_BUS_ADDRESS` is never exported to launched app
processes, even though a session D-Bus socket does exist at `/run/user/1000/bus`.

Confirmed facts (verified live on workstation 2026-05-29):
- Session D-Bus IS running: socket `/run/user/1000/bus`, `dbus-daemon --session`.
- `gnome-keyring-daemon` IS installed at `/usr/bin/gnome-keyring-daemon` but NOT
  running at boot — nothing registers `org.freedesktop.secrets`.
- With `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` exported, running
  `printf '\n' | /usr/bin/gnome-keyring-daemon --unlock --components=secrets`
  successfully registers `org.freedesktop.secrets` on the bus (confirmed via
  `dbus-send --session --dest=org.freedesktop.DBus /org/freedesktop/DBus
   org.freedesktop.DBus.ListNames`).
- The token loss causes the Hub to revert to logged-out state — window blanks and
  reloads.

## Requirements

1. Before any Electron app is launched in `08-workspaces.sh`, start
   `gnome-keyring-daemon --unlock --components=secrets` as the `user` account against
   the session D-Bus, using an empty password (the login keyring lives on the persistent
   home disk at `~/.local/share/keyrings/` and is unlocked with empty password to work
   across reboots without human interaction).

2. The keyring start block MUST be idempotent: if `gnome-keyring-daemon` is already
   running (pgrep guard), skip re-launch and log "Secret service already running".

3. `08-workspaces.sh` MUST export `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`
   in the `env` list of the `launch_and_wait` app-launch line so all launched
   Electron/language_server processes can reach the Secret Service.

4. The keyring block MUST guard on `/usr/bin/gnome-keyring-daemon` existing and log a
   WARNING if the binary is missing (non-fatal — boot continues).

5. The keyring block MUST log its outcome via the existing `log()` helper.

6. Changes MUST survive reboot, teardown+setup, and fresh-project setup (three-places
   rule: repo file is source of truth; deploy to `~/boot/` on live workstation; confirm
   `cloud-build-setup.sh` deploys via tar — no inline edit needed).

7. `workstation-image/boot/10-tests.sh` MUST include grep-based assertions consistent
   with the F-01xx test pattern, verifying the new block is present in
   `~/boot/08-workspaces.sh`.

## Acceptance Criteria

- [ ] `08-workspaces.sh` starts `gnome-keyring-daemon --unlock --components=secrets`
      with empty password before any `launch_and_wait` call.
- [ ] `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` is present in the env
      block of the `launch_and_wait` app-launch line.
- [ ] Idempotent: pgrep guard prevents duplicate daemon launches.
- [ ] Missing binary: logs WARNING and continues (non-fatal).
- [ ] `10-tests.sh` has grep tests for `--components=secrets`, `--unlock`, and
      `DBUS_SESSION_BUS_ADDRESS` in `08-workspaces.sh`.
- [ ] `~/boot/08-workspaces.sh` on live workstation matches the repo file.
- [ ] `scripts/cloud-build-setup.sh` already deploys boot scripts via tar (verified,
      no change needed).

## Out of Scope

- Replacing `gnome-keyring-daemon` with another Secret Service provider (KWallet, etc.).
- Fixing Hub first-run sign-in flow (manual sign-in is still required on first use;
  this fix prevents the token from being lost after a successful sign-in).
- Antigravity IDE (ws2) benefits incidentally from the same running keyring daemon but
  is not the primary target.

## Dependencies

- F-0110 (Hub auth-friendly launch, 90s timeout, stdout logging)
- F-0114 (Hub stale singleton lock cleanup before launch)

## Open Questions

- None. Root cause confirmed and fix mechanism verified on live workstation.
