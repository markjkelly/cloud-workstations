# F-0138: Remove GitHub Copilot CLI

**Type:** Refactor
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-06-04

## Problem

GitHub Copilot CLI extension (`gh-copilot`) is no longer desired for installation on the workstation. The boot tests occasionally fail/warn due to missing Copilot credentials or missing setup step completion, which generates benign noise. We want to completely remove this extension and its associated boot-time checks, setup-time installation steps, and documentation references.

## Requirements

1. The workstation boot-time script `07-apps.sh` must not attempt to install or upgrade `github/gh-copilot`.
2. The initial provisioning script `cloud-build-setup.sh` must not attempt to install or test `gh-copilot`.
3. The verification script `10-tests.sh` must not contain tests or skip markers verifying `gh-copilot` presence or check logging updates for it.
4. The repository README must not advertise `GitHub Copilot CLI` as one of the included AI Tools.

## Acceptance Criteria

- [ ] `07-apps.sh` is free of `gh-copilot` installation/update commands.
- [ ] `10-tests.sh` contains no checks or skipped test markers referring to `gh-copilot` or its update logs.
- [ ] `cloud-build-setup.sh` has all `gh-copilot` installation, verification, and output lines removed.
- [ ] `README.md` is updated.
- [ ] Modified scripts pass `bash -n` syntax validation.
- [ ] Automated tests run successfully on the live workstation with no copilot errors/warnings.

## Out of Scope

- Removing other AI tools (Claude Code, Gemini CLI, OpenCode, Aider, Cody CLI, pi-coding-agent remain intact).

## Dependencies

- None.

## Open Questions

- None.
