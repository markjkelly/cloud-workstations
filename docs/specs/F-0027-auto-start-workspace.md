# F-0027: Auto-Start Workspace with App Updates and Pre-Launched Apps

**Type:** Feature
**Priority:** P0 (critical)
**Status:** Draft
**Requested by:** PO
**Date:** 2026-03-20

## Problem

The PO (Your Name) wants the Cloud Workstation to be fully ready every morning by 7AM Pacific time without manual intervention. Currently, the workstation must be manually started, apps must be manually updated, and Sway workspaces must be manually opened. This wastes time every morning and creates friction. The workstation should boot itself, update all key tools to latest versions, and pre-launch apps across 4 Sway workspaces so that when the PO connects via VNC, everything is ready to go.

## Requirements

### R1: Cloud Scheduler Job (7AM PT Daily Start)

- Create a GCP Cloud Scheduler job that fires daily at 7:00 AM Pacific time (cron: `0 7 * * *` in timezone `America/Los_Angeles`).
- The scheduler triggers a mechanism (Cloud Functions, Cloud Workflows, or direct HTTP target) that calls the GCP Workstations API `startWorkstation` endpoint for the `dev-workstation` instance.
- If the workstation is already running, the start call should be a no-op (the API returns success without error when the workstation is already started).
- The scheduler job must be created in region `us-west1` within GCP project `YOUR_PROJECT_ID`.

### R2: App Update Startup Script

- Create a startup script (e.g., `workstation-image/assets/etc/workstation-startup.d/200_update-apps.sh`) that runs on each workstation boot and updates the following apps to their latest versions:
  - **Claude Code**: `npm update -g @anthropic-ai/claude-code` (installed in `~/.npm-global/bin`)
  - **Gemini CLI**: `npm update -g @anthropic-ai/gemini-cli` (installed in `~/.npm-global/bin`)
  - **VSCode**: Updated via `nix-channel --update && home-manager switch` (declared in home.nix)
  - **IntelliJ IDEA**: Updated via `nix-channel --update && home-manager switch` (declared in home.nix)
  - **Antigravity**: Check the latest version from `antigravity.google`, compare with the installed version in `~/.antigravity/`, and re-download/install if a newer version is available.
- The script must run as the workstation user (not root), since all apps are installed in the persistent home directory.
- The script must log its output for debugging (e.g., to `~/logs/app-update.log`).
- The script must be idempotent and safe to run multiple times.

### R3: Auto-Launch 4 Sway Workspaces with Apps

- Create a startup script (e.g., `workstation-image/assets/etc/workstation-startup.d/210_launch-workspaces.sh`) that runs after Sway is ready and launches apps across 4 workspaces:
  - **Workspace 1**: `foot` terminal emulator
  - **Workspace 2**: Google Chrome browser (`google-chrome-stable`)
  - **Workspace 3**: Antigravity (`~/.antigravity/antigravity`)
  - **Workspace 4**: `foot` terminal emulator
- The script must wait for Sway to be fully initialized before launching apps (poll `swaymsg -t get_tree` or similar).
- Use `swaymsg` commands to:
  1. Switch to each workspace
  2. Launch the app
  3. Wait briefly for the app window to appear
  4. Move to the next workspace
- After all apps are launched, switch back to Workspace 1 so the PO lands on the terminal.
- The script must handle the case where apps take time to start (especially Chrome and Antigravity which are Electron apps needing `--disable-gpu --disable-dev-shm-usage --no-sandbox` flags).
- The script must be idempotent: if workspaces already have apps open, it should not launch duplicates.

## Acceptance Criteria

- [ ] AC1: A Cloud Scheduler job exists in `YOUR_PROJECT_ID` (us-west1) with cron `0 7 * * *` in `America/Los_Angeles` timezone, targeting the Workstations API `startWorkstation` for `dev-workstation`
- [ ] AC2: The workstation auto-starts within 5 minutes of the scheduler trigger firing
- [ ] AC3: On each boot, all 5 apps (Claude Code, Gemini CLI, VSCode, IntelliJ, Antigravity) are updated to their latest available versions, with update logs written to `~/logs/app-update.log`
- [ ] AC4: When the PO connects via VNC after auto-start, 4 Sway workspaces are populated: ws1 = foot terminal, ws2 = Chrome browser, ws3 = Antigravity, ws4 = foot terminal
- [ ] AC5: If the workstation is already running when the scheduler fires, no error occurs (idempotent start)
- [ ] AC6: The app update script is idempotent and safe to run multiple times without side effects
- [ ] AC7: The workspace launch script is idempotent and does not launch duplicate app instances

## Out of Scope

- Auto-shutdown / idle timeout configuration (already handled by workstation config: 4h idle, 12h max run)
- Installing new apps (only updating existing ones)
- Configuring Cloud Scheduler alerting/monitoring
- Changing the workstation machine type or disk size

## Dependencies

- F-0025 (Sway auto-start on boot) -- Sway must be running on boot for workspace auto-launch to work
- F-0016 (Sway + foot + supporting apps installed via Nix)
- F-0018 (Claude Code and Gemini CLI installed via npm)
- F-0017 (VSCode and IntelliJ installed via Nix Home Manager)

## Open Questions

- Should the scheduler also handle auto-shutdown at a specific time (e.g., 11PM PT) to save costs, or rely on the existing 4h idle timeout?
- Should there be a health-check mechanism that verifies apps actually launched successfully and sends a notification (e.g., via Cloud Monitoring) if something failed?
- What is the best method for checking the latest Antigravity version -- is there a version API, or do we need to scrape the download page?
