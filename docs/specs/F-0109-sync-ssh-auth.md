# F-0109: Fix SSH authentication in boot sync script

**Type:** Bug Fix
**Priority:** P0 (critical)
**Status:** Done
**Requested by:** PO
**Date:** 2026-05-29

## Problem

Boot sync script `09-sync.sh` runs as root at every boot to pull the latest repo and sync configs. When root runs `git pull`, it uses root's SSH key (`/root/.ssh/`), which doesn't have GitHub access. This causes a silent "Permission denied (publickey)" failure on every boot, preventing config updates from propagating.

The script already gracefully handles git pull failures (doesn't fail the boot), but the result is that live workstations never sync the latest repo changes.

## Requirements

1. Pass the user's SSH key (`/home/user/.ssh/id_ed25519`) explicitly to `git pull` so root can authenticate to GitHub
2. Use `GIT_SSH_COMMAND` environment variable to override SSH behavior without modifying global git config
3. Set `StrictHostKeyChecking=accept-new` to avoid host-key prompts without disabling verification
4. Maintain backward compatibility — script remains non-fatal if git pull fails

## Acceptance Criteria

- [ ] `09-sync.sh` line 35 includes `GIT_SSH_COMMAND` with user's id_ed25519 key
- [ ] Git pull succeeds when `09-sync.sh` runs as root
- [ ] Boot sync log shows "✓ Git pull succeeded"
- [ ] Script survives reboot persistence
- [ ] Test added to `10-tests.sh` asserting `GIT_SSH_COMMAND` is set

## Out of Scope

- Multi-user SSH key handling
- Git config persistence across reboots
- GitHub SSH key rotation

## Dependencies

- None (standalone fix)
