# F-0093: Claude Code Auto-Update Fix (Persistent npm Prefix)

**Type:** Bug
**Priority:** P1
**Status:** Draft
**Requested by:** PO
**Date:** 2026-04-15

## Problem

Claude Code's status bar reports **"Auto-update failed"** on the live
workstation. The in-process auto-updater shells out to
`npm install -g @anthropic-ai/claude-code` and fails with:

```
EACCES: permission denied, mkdir '/usr/lib/node_modules/@anthropic-ai'
```

Root cause (per SWE-1 diagnosis on task #1):

- `workstation-image/boot/11-custom-tools.sh::install_claude_code`
  installs Claude Code with `npm install -g ... --prefix ~/.npm-global`,
  which scopes the prefix **only to that single invocation**.
- The prefix is never persisted — `~/.npmrc` does not exist and
  `NPM_CONFIG_PREFIX` is unset.
- Consequently `npm config get prefix` on the workstation returns
  `/usr` (the base-image default).
- When Claude's auto-updater runs `npm install -g ...` later, it uses
  that default prefix, tries to write into `/usr/lib/node_modules`
  (owned by root, and also on the ephemeral image layer), and fails.

The fix is to make the user's npm prefix **persistently** point at
`~/.npm-global` via `~/.npmrc`, so every `npm -g` invocation — including
Claude's auto-updater — targets the persistent disk.

## Requirements

1. `workstation-image/boot/11-custom-tools.sh::install_claude_code` must
   ensure `~/.npmrc` contains `prefix=/home/user/.npm-global` before
   (or as part of) the `npm install -g` step.
2. The `.npmrc` write must be:
   - Owned by `user:user`
   - Idempotent — re-running on every boot must not duplicate or
     corrupt entries, and must leave unrelated keys in `~/.npmrc`
     untouched if any exist.
3. The fix must live in `workstation-image/boot/11-custom-tools.sh`
   (the same module that owns the Claude Code install). No new boot
   script is needed — this is a one-line concern tightly coupled to
   the existing `install_claude_code` function.
4. `workstation-image/boot/10-tests.sh` must include a boot test that
   asserts `npm config get prefix` (as the `user` account) returns
   `/home/user/.npm-global`.
5. The fix must survive all three persistence scenarios (per CLAUDE.md):
   reboot, teardown + `ws.sh setup`, and fresh-project setup.

## Acceptance Criteria

- [ ] On a freshly booted workstation, `cat ~/.npmrc` contains the
      line `prefix=/home/user/.npm-global`.
- [ ] `runuser -u user -- npm config get prefix` returns
      `/home/user/.npm-global` (not `/usr`).
- [ ] Launching Claude Code no longer shows "Auto-update failed" in
      the status bar; the auto-updater completes successfully and the
      updated package lives under `~/.npm-global/lib/node_modules/`.
- [ ] Re-running `11-custom-tools.sh` on an already-configured
      workstation does not duplicate the `prefix=` line in `~/.npmrc`.
- [ ] New boot test in `10-tests.sh` asserts the npm prefix and passes
      (recorded in `~/logs/boot-test-results.txt`).
- [ ] Teardown + `ws.sh setup` on a fresh project produces a
      workstation where the npm prefix is correct and Claude Code
      auto-update succeeds.

## Out of Scope

- Migrating any other npm global tools to the persistent prefix.
  Claude Code is the only npm-installed tool managed by this module;
  no migration is required unless a future feature adds one.
- Changes to the Claude Code install invocation itself beyond what is
  needed to make the prefix persistent (the existing `--prefix` flag
  may be kept or dropped at the implementer's discretion — either
  works once `.npmrc` is correct).
- Upgrading Claude Code to a specific version. This spec only ensures
  the auto-updater *can* run; it does not pin or bump the version.
- System-wide npm configuration (`/etc/npmrc`). The fix is scoped to
  the `user` account only.

## Dependencies

- F-0089 (custom tools module — owns the file being modified)

## Open Questions

- None.
