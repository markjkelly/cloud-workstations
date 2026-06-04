# GEMINI.md — Cloud Workstation Project Context

This project manages the lifecycle and configuration of a GPU-powered Cloud Workstation on Google Cloud Platform (GCP). It provides a high-performance development environment with a Sway (Wayland) desktop, accessible via a browser using noVNC or remotely via Chrome Remote Desktop.

## Project Overview

-   **Purpose:** To provide a consistent, high-performance, GPU-enabled development environment in the cloud.
-   **Core Technologies:**
    -   **GCP Services:** Cloud Workstations, Cloud Build, Cloud Scheduler, Artifact Registry, Cloud Functions.
    -   **Desktop Environment:** Sway (Wayland) accessible via browser using noVNC, or nested inside a virtual X11 server on display `:20` using Chrome Remote Desktop.
    -   **Package Management:** Nix (Home Manager) for persistent tool installation on the home directory.
    -   **Shell:** ZSH + Starship, tmux.
    -   **Containerization:** Docker for the base workstation image.
    -   **Profiles:** Composable installation profiles (`minimal`, `dev`, `ai`, `full`) to control build time and features.

## Project Structure

-   `workstation-image/`: Contains the definition of the workstation environment.
    -   `Dockerfile`: Defines the base system (Ubuntu-based).
    -   `boot/`: Numbered shell scripts (`00-12`) that run sequentially during the workstation's bootstrap process. These handle Nix restoration, service setup, app installation, synchronization, verification tests, and Chrome Remote Desktop setup.
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

1.  **Nix Restoration (`01-nix.sh`):** Bind-mounts the persistent Nix store from `/home/user/nix` to `/nix` to ensure package persistence.
2.  **NVIDIA GPU Setup (`02-nvidia.sh`):** Configures library paths for host GPU driver compatibility when a GPU is attached.
3.  **Service Setup (`03-sway.sh`):** Configures and starts `sway-desktop` (headless) and `wayvnc` as systemd user services.
4.  **Font Deployment (`04-fonts.sh`):** Deploys custom developer fonts to the persistent home directory.
5.  **Shell Configuration (`05-shell.sh`):** Configures ZSH shell preferences, plugins, and custom aliases.
6.  **Terminal Prompt (`06-prompt.sh`):** Configures the Starship prompt and the `foot` terminal emulator styling.
7.  **Tailscale VPN (`06a-tailscale.sh`):** Sets up Tailscale client for secure networking if a Tailscale authentication key is present.
8.  **Tmux Multiplexer (`06b-tmux.sh`):** Sets up tmux with a Tokyo Night aesthetic, custom mappings, and helper utilities.
9.  **App Installation (`07-apps.sh`):** Installs AI tools and application updates (runs asynchronously as a systemd service).
10. **Language dependencies (`07a-lang-deps.sh`):** Sets up development libraries for language runtimes.
11. **Language runtimes (`07b-languages.sh`):** Installs runtimes (Go, Rust, Python, Ruby) using direct binaries or local managers (pyenv, rbenv, rustup).
12. **Auto-Launch (`08-workspaces.sh`):** Opens default apps across Sway workspaces (VS Code on ws2, Terminal on ws3/ws4, Chrome on ws5).
13. **Snippet Picker (`09-snippets.sh`):** Configures the lightweight snippet picker utility and custom configuration.
14. **Sway Sync (`09-sync.sh`):** Synchronizes boot scripts and Sway config from the git repo on every boot to apply changes.
15. **Application Launcher (`09-wofi.sh`):** Deploys wofi menu with Tokyo Night colors.
16. **Environment Verification (`10-tests.sh`):** Runs 160+ automated integration tests to ensure workspace health (results at `~/logs/boot-test-results.txt`).
17. **Custom Tools (`11-custom-tools.sh`):** Deploys custom CLI binaries (Terraform, gh, etc.) and sets up the `gh` wrapper to prevent dummy GITHUB_TOKEN overrides.
18. **Chrome Remote Desktop (`12-crd.sh`):** Provisions Chrome Remote Desktop, configures a nested Sway display session on `:20`, and deploys the `crd-resize` utility.

## Development Conventions

-   **Branching & PRs:** For new work, always use a feature branch and submit changes via a Pull Request (PR) to the repository. Avoid committing directly to the `main` branch.
-   **Idempotency:** All scripts (both infrastructure and boot scripts) are designed to be idempotent. They check for existing resources or states before attempting to create or modify them.
-   **Persistence:** The root filesystem is ephemeral. All persistent data and configurations must reside in `/home/user`. Nix is specifically used to keep installed packages persistent by storing the store on the home disk.
-   **Logging:** Bootstrap logs are tagged with `ws-bootstrap` and specific script tags. Test results are stored in `~/logs/`.
-   **Profiles:** The workstation behavior adapts to the profile defined in `/home/user/.ws-modules`. Use `ws_module_enabled <module_name>` in scripts to gate functionality.

## Useful Commands

-   **Connect to Workstation:** Get the URL via `gcloud workstations describe dev-workstation --format="value(host)"` and open in a browser.
-   **Tailscale SSH:** If configured, SSH via `ssh user@<tailscale-hostname>`.
-   **Debug Bootstrap:** Logs are visible via `journalctl` or by checking the output of the bootstrap scripts during start-up.
-   **Run Boot Tests Manually:** `bash /home/user/boot/10-tests.sh`.
-   **Resize CRD Session Resolution:** Run `crd-resize <width> <height>` (e.g., `crd-resize 2560 1440`) within a Chrome Remote Desktop session to adjust both X11 resolution and nested Sway output.

## Maintenance

-   **Updating the Image:** Modify the `Dockerfile` or boot scripts and re-run `bash scripts/ws.sh setup`. Cloud Build will rebuild the image and update the workstation configuration.
-   **Adding New Modules:** Add the module logic to `workstation-image/scripts/ws-modules.sh` and update the mapping in `workstation-image/boot/setup.sh`.
