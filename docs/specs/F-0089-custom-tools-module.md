# F-0089: Custom Tools Module (Terraform, gh, Java, Eclipse, Claude Code)

**Type:** Feature
**Priority:** P1
**Status:** Done
**Requested by:** PO
**Date:** 2026-04-13

## Problem

Several tools needed for day-to-day work on this workstation are either
not packaged in Nix, not at a usable version in Nix, or must live inside
`$HOME` to survive Docker image rebuilds (the image is minimal by design
— all state lives on the persistent disk):

- **Terraform** and **gh CLI** — versions matter for interop with GCP and
  GitHub; need pinned installs on PATH
- **Java** — workflows need a managed JDK with easy version switching
- **Eclipse IDE** — not in Nix; developers want it available
- **Claude Code** — npm global install needs to live on the persistent
  disk so upgrades and config survive image rebuilds

A dedicated boot script keeps these concerns out of the Nix Home Manager
config and makes the install idempotent on every boot.

## Requirements

1. The system must provide a boot script
   (`workstation-image/boot/11-custom-tools.sh`) that installs:
   - Terraform (pinned) to `~/.local/bin`
   - GitHub CLI (`gh`, pinned) to `~/.local/bin`
   - Java via **SDKMAN** into `$HOME`
   - Eclipse IDE onto the persistent disk
   - Claude Code to `~/.npm-global`
2. All installs must be idempotent — re-running on subsequent boots must
   not reinstall from scratch if the tool is already at the target
   version.
3. All installs must persist across image rebuilds (live under `$HOME`).
4. Workspace auto-launch (pre-launching apps on sway start) must be
   disabled by default in this module so the user chooses what to start.
5. Boot tests in `10-tests.sh` must verify each tool is on PATH after the
   module runs.

## Acceptance Criteria

- [x] `11-custom-tools.sh` exists and is sourced by `setup.sh`
- [x] `terraform`, `gh`, `java`, `eclipse`, `claude` all resolve on PATH
      after boot (when the module is enabled in the active profile)
- [x] Reboot does not re-download tools already at the pinned version
- [x] Boot tests cover each tool
- [x] Teardown + re-setup produces a workstation with all tools working

## Out of Scope

- Gradle/Maven — installed separately via SDKMAN if the user wants them
- IntelliJ (already covered by Nix Home Manager, F-0017)

## Dependencies

- F-0033 persistent bootstrap
- F-0081 composable install profiles (this module is gated by the
  `dev` / `full` profile in v1.15+)

## Open Questions

- None
