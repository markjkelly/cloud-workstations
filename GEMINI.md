# GEMINI.md — Cloud Workstation Project Context

This project manages the lifecycle and configuration of a GPU-powered Cloud Workstation on Google Cloud Platform (GCP). It provides a high-performance development environment with a Sway (Wayland) desktop, accessible via a browser using noVNC.

## Project Overview

-   **Purpose:** To provide a consistent, high-performance, GPU-enabled development environment in the cloud.
-   **Core Technologies:**
    -   **GCP Services:** Cloud Workstations, Cloud Build, Cloud Scheduler, Artifact Registry, Cloud Functions.
    -   **Desktop Environment:** Sway (Wayland), wayvnc, noVNC (browser access).
    -   **Package Management:** Nix (Home Manager) for persistent tool installation on the home directory.
    -   **Shell:** ZSH + Starship, tmux.
    -   **Containerization:** Docker for the base workstation image.
    -   **Profiles:** Composable installation profiles (`minimal`, `dev`, `ai`, `full`) to control build time and features.

## Project Structure

-   `workstation-image/`: Contains the definition of the workstation environment.
    -   `Dockerfile`: Defines the base system (Ubuntu-based).
    -   `boot/`: Numbered shell scripts (`00-11`) that run sequentially during the workstation's bootstrap process. These handle Nix restoration, service setup, app installation, and tests.
    -   `configs/`: Configuration files for Sway, waybar, tmux, nvim, etc.
    -   `scripts/`: Internal scripts like `claude-tmux` and `snippet-picker`.
-   `scripts/`: Management scripts for the GCP infrastructure.
    -   `ws.sh`: The primary entry point for `setup` and `teardown` of all GCP resources.
    -   `cloud-build-setup.sh`: The script executed inside Cloud Build to provision the infrastructure and build the image.
-   `docs/`: Extensive documentation, including feature specifications (`specs/`) and progress tracking.
-   `dev-fonts/`: A collection of developer-focused fonts (Operator Mono, Cascadia Code, etc.) installed during the boot process.
-   `cloudbuild/`: YAML definitions for Cloud Build jobs.

## Key Workflows

### Infrastructure Management

-   **Setup:** `bash scripts/ws.sh setup -p PROJECT_ID [--profile PROFILE]`
    -   Triggers a Cloud Build job that enables APIs, creates a VPC, Artifact Registry, NAT, and provisions the Workstation Cluster, Config, and Workstation.
-   **Teardown:** `bash scripts/ws.sh teardown -p PROJECT_ID`
    -   Deletes all resources created by the setup script.
-   **Auto-Start/Stop:** Managed via Cloud Scheduler jobs (`ws-weekday-start`, `ws-weekday-stop`) to save costs during off-hours.

### Workstation Bootstrap

When the workstation container starts, it executes `/google/scripts/entrypoint.sh` (from the base image), which eventually triggers the bootstrap process in `workstation-image/boot/setup.sh`.

1.  **Nix Restoration (`01-nix.sh`):** Bind-mounts the persistent Nix store from `/home/user/nix` to `/nix`.
2.  **Service Setup (`03-sway.sh`):** Configures and starts `sway-desktop` and `wayvnc` as systemd services.
3.  **App Installation (`07-apps.sh`):** Installs AI tools and other applications based on the selected profile.
4.  **Auto-Launch (`08-workspaces.sh`):** Automatically opens default apps (Terminal, Chrome, Antigravity) on specific Sway workspaces.
5.  **Verification (`10-tests.sh`):** Runs 80+ automated tests to ensure the environment is healthy. Results are at `~/logs/boot-test-results.txt`.

## Development Conventions

-   **Idempotency:** All scripts (both infrastructure and boot scripts) are designed to be idempotent. They check for existing resources or states before attempting to create or modify them.
-   **Persistence:** The root filesystem is ephemeral. All persistent data and configurations must reside in `/home/user`. Nix is specifically used to keep installed packages persistent by storing the store on the home disk.
-   **Logging:** Bootstrap logs are tagged with `ws-bootstrap` and specific script tags. Test results are stored in `~/logs/`.
-   **Profiles:** The workstation behavior adapts to the profile defined in `/home/user/.ws-modules`. Use `ws_module_enabled <module_name>` in scripts to gate functionality.

## Useful Commands

-   **Connect to Workstation:** Get the URL via `gcloud workstations describe dev-workstation --format="value(host)"` and open in a browser.
-   **Tailscale SSH:** If configured, SSH via `ssh user@<tailscale-hostname>`.
-   **Debug Bootstrap:** Logs are visible via `journalctl` or by checking the output of the bootstrap scripts during start-up.
-   **Run Boot Tests Manually:** `bash /home/user/boot/10-tests.sh`.

## Maintenance

-   **Updating the Image:** Modify the `Dockerfile` or boot scripts and re-run `bash scripts/ws.sh setup`. Cloud Build will rebuild the image and update the workstation configuration.
-   **Adding New Modules:** Add the module logic to `workstation-image/scripts/ws-modules.sh` and update the mapping in `workstation-image/boot/setup.sh`.
