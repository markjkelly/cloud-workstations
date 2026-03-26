# F-0034: One-Click Cloud Workstation Setup via Cloud Build

**Type:** Feature
**Priority:** P0 (critical)
**Status:** Approved
**Requested by:** PO (Your Name)
**Date:** 2026-03-20

## Problem

Setting up the Cloud Workstation currently requires manual execution of dozens of gcloud commands across multiple sessions. This makes it impossible for colleagues to replicate the setup. The PO wants a single script that any GCP Project Owner can run to get a fully configured Cloud Workstation — identical to the current setup.

Cloud Shell is unreliable (idle timeouts, disconnects, laptop closure), so all heavy work must run inside Cloud Build, which persists independently of the user's terminal.

## Requirements

### R1: Single launcher script (`setup.sh`)

A shell script at the repo root that the user runs from Cloud Shell (or any terminal with `gcloud` authenticated):

```bash
bash setup.sh -p PROJECT_ID
```

The script must:
1. Parse `-p` / `--project` mandatory argument for PROJECT_ID
2. Validate `gcloud auth` is active (fail with clear message if not)
3. Validate the user has Owner role on the project
4. Enable Cloud Build API
5. Grant Cloud Build default SA (`PROJECT_NUMBER@cloudbuild.gserviceaccount.com`) the Owner role
6. Clone the repo (or use local copy if running from repo checkout)
7. Submit `cloudbuild-setup.yaml` to Cloud Build with `--async` and `--timeout=7200s`
8. Print the Cloud Console URL to track the build
9. Print instructions for checking status: `gcloud builds log BUILD_ID --stream --project=PROJECT_ID`
10. Exit immediately (user can close terminal)

### R2: Cloud Build config (`cloudbuild-setup.yaml`)

A Cloud Build configuration that performs the ENTIRE setup from scratch in an empty GCP project. Steps:

1. **Enable APIs**: workstations, artifactregistry, compute, cloudscheduler, cloudresourcemanager
2. **Create Artifact Registry**: `workstation-images` repo in us-west1
3. **Build Docker image**: Build and push the workstation image from `workstation-image/`
4. **Create Cloud NAT**: Cloud Router + Cloud NAT for internet access (required by org policies blocking public IPs)
5. **Create Workstation Cluster**: `workstation-cluster` in us-west1
6. **Create Workstation Config**: `ws-config` with n1-standard-16, nvidia-tesla-t4, 500GB pd-ssd, 4h idle/12h run, no public IP, Shielded VM
7. **Create Workstation**: `dev-workstation`
8. **Start Workstation**: Start and wait for RUNNING state
9. **Install Nix**: SSH into workstation, install Nix package manager on persistent disk
10. **Install Home Manager + apps**: Set up Nix Home Manager with all packages (neovim, tmux, zsh, chromium, chrome, vscode, intellij, sway, foot, etc.)
11. **Deploy boot scripts**: Copy `workstation-image/boot/` to `~/boot/` on persistent disk
12. **Deploy fonts**: Copy `dev-fonts/` to `~/boot/fonts/` on persistent disk
13. **Run initial setup**: Execute `~/boot/setup.sh` to configure everything (fonts, ZSH, Starship, foot, app updates)
14. **Deploy configs**: Sway config, sway-status, Neovim init.lua
15. **Install AI tools**: Claude Code + Gemini CLI via npm
16. **Install Antigravity**: Download and install from antigravity.google
17. **Create Cloud Scheduler**: `ws-daily-start` job (7AM PT daily)
18. **Stop Workstation**: Stop to save costs (user starts when ready)
19. **Print summary**: Workstation URL, connection instructions

Every step must be **idempotent** (safe to re-run if the build is resubmitted).

### R3: Bulletproof error handling

- Pre-flight checks in `setup.sh`: gcloud authenticated, project exists, user has Owner role
- Each Cloud Build step checks if the resource already exists before creating
- Clear error messages with remediation steps
- Build log captures all output for debugging
- If a step fails, subsequent steps should handle missing dependencies gracefully

### R4: No local dependencies

- `setup.sh` only requires `gcloud` CLI (pre-installed in Cloud Shell)
- All heavy work runs in Cloud Build (Docker images, gcloud commands, SSH)
- Repo is cloned inside Cloud Build (not uploaded from local)
- No Terraform, Ansible, or other tools required

## Acceptance Criteria

- [ ] AC1: A new user with Owner role on an empty GCP project can run `gcloud auth login && bash setup.sh -p PROJECT_ID` and get a fully configured Cloud Workstation
- [ ] AC2: The user can close their terminal immediately after running setup.sh — Cloud Build continues independently
- [ ] AC3: The setup produces an identical workstation to the current one (Sway, Tokyo Night, fonts, ZSH, Starship, all apps, workspace auto-launch)
- [ ] AC4: Re-running setup.sh on an already-configured project is safe (idempotent)
- [ ] AC5: Build completes within 2 hours
- [ ] AC6: Clear progress tracking via Cloud Console and `gcloud builds log`

## Out of Scope

- Multi-workstation support (single `dev-workstation` per project)
- Custom machine types or GPU selection (hardcoded to n1-standard-16 + T4)
- Teardown/cleanup script (future item)
- CI/CD pipeline for the setup itself

## Dependencies

- All Milestone 1-4 features (the setup script recreates the full stack)
- GitHub repo must be public (or the Cloud Build step needs auth to clone)

## Open Questions

- Should the repo be public so anyone can clone it, or should setup.sh upload the local checkout?
- Should we parameterize region (default us-west1) or keep it hardcoded?
- Should the script create a dedicated service account or use the default compute SA?
