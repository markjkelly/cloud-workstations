# F-0001: Cloud Workstation with GPU, Antigravity, and Desktop via noVNC

**Type:** Feature
**Priority:** P0 (critical)
**Status:** Draft
**Requested by:** PO (Your Name)
**Date:** 2026-03-19

## Problem

The PO needs a cloud-based development workstation in GCP with a full graphical desktop environment, GPU acceleration, and Google Antigravity installed. The workstation must persist all user data, installed applications, and configurations across restarts using a persistent disk. Currently no such environment exists in the `YOUR_PROJECT_ID` GCP project.

Reference blog: https://medium.com/google-cloud/running-antigravity-on-a-browser-tab-6298bb7e47c4

## Requirements

### R1: Cloud Workstation Cluster

The system must create a Cloud Workstation cluster in the `YOUR_PROJECT_ID` GCP project.

- Region: `us-west1`
- Network: default VPC
- Cluster name: `workstation-cluster` (or similar descriptive name)

**Acceptance Criteria:**
- [ ] A Cloud Workstation cluster exists in `us-west1` within the default VPC
- [ ] The cluster is in a RUNNING state and healthy
- [ ] The cluster is accessible via the Cloud Workstations API

### R2: Artifact Registry Repository

The system must create an Artifact Registry Docker repository to host the custom workstation container image.

- Repository format: Docker
- Region: `us-west1`
- Repository name: `workstation-images` (or similar)

**Acceptance Criteria:**
- [ ] An Artifact Registry Docker repository exists in `us-west1`
- [ ] Docker images can be pushed to and pulled from the repository
- [ ] The Cloud Workstation service agent has read access to pull images

### R3: Custom Docker Image (Dockerfile)

The system must build a custom Docker image using a multi-stage Dockerfile.

- **Base image:** `us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base`
- **Stage 1 — noVNC build:**
  - Clone and build noVNC v1.5.0
  - Clone and build websockify v0.12.0
- **Stage 2 — Final image:**
  - Based on the predefined Cloud Workstations base image
  - Install systemd, GNOME desktop environment, GDM
  - Install Google Antigravity from `us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/`
  - Install Google Chrome (with launch flags: `--no-sandbox --no-zygote --disable-gpu --disable-dev-shm-usage`)
  - Install TigerVNC server
  - Copy noVNC + websockify from Stage 1
  - Include required assets from the `cloud-workstations-custom-image-examples` repository (supervisor configs, entrypoint scripts, desktop configuration files)
  - Image must be minimal — heavy application installs go on the persistent disk, not baked into the image
  - The image should configure VNC to listen on port 5901 and noVNC to proxy on port 6080

**Acceptance Criteria:**
- [ ] Dockerfile builds successfully with `docker build` or `cloud-build`
- [ ] The resulting image is pushed to the Artifact Registry repo from R2
- [ ] The image contains systemd, GNOME, GDM, Antigravity, Chrome, TigerVNC, noVNC, and websockify
- [ ] noVNC v1.5.0 and websockify v0.12.0 are the exact versions used
- [ ] Chrome desktop shortcut is configured with the required flags (`--no-sandbox --no-zygote --disable-gpu --disable-dev-shm-usage`)
- [ ] The image size is kept as small as practical (application installs deferred to persistent disk)

### R4: Workstation Configuration (Machine Type)

The system must create a Cloud Workstation configuration specifying the compute resources.

- Machine type: `g2-standard-16` (16 vCPU, 64 GB RAM)
- GPU: NVIDIA L4 (1x, attached via the g2-standard-16 machine type)
- Container image: the custom image from R3
- Idle timeout: configurable (suggest 4 hours)
- Running timeout: configurable (suggest 12 hours)

**Acceptance Criteria:**
- [ ] Workstation config uses `g2-standard-16` machine type
- [ ] The machine has 16 vCPU and 64 GB RAM
- [ ] An NVIDIA L4 GPU is attached and accessible from within the workstation
- [ ] The config references the custom Docker image from R3
- [ ] Idle and running timeouts are set to reasonable values

### R5: Persistent Disk (500 GB pd-ssd, HOME Mount)

The system must attach a 500 GB SSD persistent disk to the workstation with the user's HOME directory mounted on it.

- Disk type: `pd-ssd`
- Disk size: 500 GB
- Mount point: user HOME directory (`/home/user` or as configured by Cloud Workstations)
- All user-installed applications, configurations, and data persist across workstation stop/start cycles
- The persistent disk is the canonical storage for all mutable state

**Acceptance Criteria:**
- [ ] A 500 GB `pd-ssd` persistent disk is attached to the workstation
- [ ] The HOME directory is mounted on the persistent disk
- [ ] Data written to HOME survives workstation stop and restart
- [ ] Applications installed to HOME (e.g., via Nix) persist across restarts
- [ ] Disk performance is consistent with SSD expectations

### R6: Software Stack (Antigravity, Chrome, GNOME, TigerVNC, noVNC)

The system must provide a fully functional graphical desktop environment accessible via a web browser.

- **GNOME desktop** with GDM display manager, running under systemd
- **Google Antigravity** installed from the official APT repository (`us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/`)
- **Google Chrome** installed with a desktop shortcut; launch flags: `--no-sandbox --no-zygote --disable-gpu --disable-dev-shm-usage`
- **TigerVNC** server providing the VNC backend (display :1, port 5901)
- **noVNC v1.5.0** serving the browser-based VNC client on port 6080
- **websockify v0.12.0** bridging WebSocket (noVNC) to TCP (VNC)

**Acceptance Criteria:**
- [ ] GNOME desktop is fully functional when accessed via noVNC in a browser
- [ ] Google Antigravity launches and runs correctly from the desktop
- [ ] Chrome opens with the specified flags and is usable
- [ ] TigerVNC is running on display :1 (port 5901)
- [ ] noVNC is accessible on port 6080 and renders the desktop in the browser
- [ ] websockify correctly proxies between noVNC and TigerVNC
- [ ] All services start automatically when the workstation boots

### R7: Nix Package Manager on Persistent Disk

The system must install the Nix package manager with its store and configuration located on the persistent disk so that all Nix-installed packages persist across workstation restarts.

- Nix installed to the persistent HOME directory (e.g., `/home/user/.nix` or similar)
- Nix store symlinked or bind-mounted from the persistent disk
- Nix profile sourced automatically on login (e.g., via `.bashrc` or `.profile`)
- User can install packages with `nix-env -iA` or `nix profile install` and they persist

**Acceptance Criteria:**
- [ ] `nix --version` returns a valid version after workstation start
- [ ] `nix-env -iA nixpkgs.<package>` successfully installs packages
- [ ] Packages installed via Nix persist across workstation stop/start cycles
- [ ] Nix store resides on the persistent disk, not the ephemeral boot disk
- [ ] Nix is available immediately on login without manual setup

### R8: Workstation Creation and VNC Access

The system must create an actual Cloud Workstation instance from the configuration and provide instructions for accessing the desktop.

- Workstation name: descriptive (e.g., `dev-workstation`)
- User can start/stop the workstation from the GCP Console or `gcloud`
- VNC access via noVNC is available through the Cloud Workstations proxy or port forwarding
- Documentation or scripts provided for connecting

**Acceptance Criteria:**
- [ ] A workstation instance is created and can be started
- [ ] The user can access the GNOME desktop via noVNC in a web browser
- [ ] Instructions or a script for connecting are provided
- [ ] The workstation can be stopped and restarted without data loss

### R9: Network and IAM Configuration

The system must configure appropriate network and IAM settings for the workstation.

- The workstation runs in the default VPC in `us-west1`
- The `owner-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com` service account is used for provisioning
- The PO's Google account (`your-email@example.com` / `your-org.example.com`) has access to use the workstation
- Firewall rules allow VNC/noVNC traffic as needed (or use Cloud Workstations built-in TCP proxy)
- IAM roles: `roles/workstations.user` for the PO, `roles/workstations.admin` for the service account

**Acceptance Criteria:**
- [ ] The workstation is reachable from the PO's browser
- [ ] IAM permissions are correctly scoped (principle of least privilege for users, admin for provisioning SA)
- [ ] No unnecessary ports are exposed to the public internet
- [ ] Cloud Workstations TCP proxy or IAP is used for secure access

### R10: GPU Drivers (NVIDIA L4)

The system must ensure NVIDIA GPU drivers are installed and functional for the L4 GPU.

- NVIDIA drivers compatible with the L4 GPU must be available inside the workstation
- CUDA toolkit should be accessible (installed via Nix on persistent disk or baked into image if required for boot)
- `nvidia-smi` must report the L4 GPU correctly
- GPU is available for Antigravity and any other GPU-accelerated workloads

**Acceptance Criteria:**
- [ ] `nvidia-smi` runs successfully and shows the NVIDIA L4 GPU
- [ ] NVIDIA driver version is compatible with the L4 GPU
- [ ] GPU-accelerated applications (including Antigravity) can utilize the GPU
- [ ] CUDA toolkit is available (either via Nix or pre-installed)
- [ ] GPU drivers persist or are re-initialized correctly on workstation restart

## Out of Scope

- **Auto-scaling:** This is a single-user workstation; no auto-scaling or multi-instance support
- **CI/CD pipelines:** No automated build/deploy pipelines for the Docker image; builds are manual or scripted
- **Multi-user support:** Only the PO (Your Name) will use this workstation; no multi-tenancy
- **GCP Free Tier:** This workstation uses a `g2-standard-16` with GPU and 500GB SSD, which is NOT within the GCP free tier. The PO has approved the associated costs
- **High availability:** Single instance, no failover or redundancy
- **Custom domain / TLS:** Access is via Cloud Workstations built-in proxy; no custom domain setup

## Dependencies

- GCP project `YOUR_PROJECT_ID` must be active with billing enabled
- Cloud Workstations API must be enabled in the project
- Artifact Registry API must be enabled in the project
- Compute Engine API must be enabled (for GPU quota)
- Sufficient GPU quota in `us-west1` for NVIDIA L4 (g2-standard-16)
- Access to the Antigravity APT repository (`us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/`)
- Access to the Cloud Workstations base image (`us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base`)
- Access to `cloud-workstations-custom-image-examples` GitHub repository for asset files

## Open Questions

1. **VNC password:** Should a VNC password be set, or rely solely on Cloud Workstations IAM for access control?
2. **Nix installation method:** Single-user or multi-user Nix install? Single-user is simpler for persistent disk but multi-user is more robust.
3. **CUDA version:** Which CUDA toolkit version is required for Antigravity? Or is the base driver sufficient?
4. **Idle timeout:** What idle timeout does the PO prefer before the workstation auto-stops? (Suggested: 4 hours)
5. **Image rebuild strategy:** When the base image or Antigravity updates, should the custom image be rebuilt manually or is a Cloud Build trigger desired (currently out of scope)?
6. **Region for Artifact Registry:** Should the Artifact Registry repo be in `us-west1` (same as workstation) or `us-central1` (same as base image source)? Spec assumes `us-west1` for locality.
