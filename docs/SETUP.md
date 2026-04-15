# Cloud Workstation Setup Guide

Complete guide for recreating the Cloud Workstation from scratch in the `YOUR_PROJECT_ID` GCP project. This covers every component: GCP infrastructure, Docker image, Nix package manager, Sway desktop, application suite, and Antigravity.

> **Machine spec (current deployment):** `n2-standard-8` (8 vCPU, 32GB RAM), 200GB `pd-balanced` persistent disk, no GPU. The GPU sections below (`02-nvidia.sh`, waybar GPU module, etc.) are preserved for reference — `02-nvidia.sh` is a no-op when no GPU is present.

**Reference blog:** https://medium.com/google-cloud/running-antigravity-on-a-browser-tab-6298bb7e47c4

> **Tip:** Use `--profile` to control what gets installed. See [Install Profiles](#install-profiles) below.

---

## Install Profiles

Choose a profile to control build time and installed components:

| Profile | What's Included | Build Time |
|---------|----------------|------------|
| `minimal` | Sway desktop, ZSH, Chrome, Antigravity, dev tools | ~14 min |
| `dev` | minimal + tmux + Claude Code | ~25 min |
| `ai` | dev + AI IDEs + AI CLI tools | ~35 min |
| `full` | Everything including Go, Rust, Python, Ruby | ~55 min |

```bash
# Default (full profile)
bash scripts/ws.sh setup -p YOUR_PROJECT_ID

# Minimal profile (fastest)
bash scripts/ws.sh setup -p YOUR_PROJECT_ID --profile minimal

# AI profile (IDEs + AI tools, no languages)
bash scripts/ws.sh setup -p YOUR_PROJECT_ID --profile ai

# Custom modules
bash scripts/ws.sh setup -p YOUR_PROJECT_ID --profile custom --modules "ides,ai-tools"
```

The selected profile creates a `~/.ws-modules` config file on the workstation. Boot scripts check this file and skip disabled modules. Tests report SKIP for disabled modules instead of FAIL.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Infrastructure Setup](#2-infrastructure-setup)
3. [Docker Image](#3-docker-image)
4. [Workstation Configuration](#4-workstation-configuration)
5. [Create and Start Workstation](#5-create-and-start-workstation)
6. [Install Nix Package Manager](#6-install-nix-package-manager)
7. [Nix Home Manager](#7-nix-home-manager)
8. [Sway Desktop Environment](#8-sway-desktop-environment)
9. [Configure Applications](#9-configure-applications)
10. [AI CLI Tools](#10-ai-cli-tools)
11. [Antigravity](#11-antigravity)
12. [GPU Setup](#12-gpu-setup)
13. [Troubleshooting](#13-troubleshooting)
14. [Architecture Reference](#14-architecture-reference)

---

## 1. Prerequisites

### GCP Project

- **Project ID:** `YOUR_PROJECT_ID`
- **Project Number:** `YOUR_PROJECT_NUMBER`
- **Organization:** `your-org.example.com`
- **Region:** `us-west1`
- **Identity:** `admin@your-org.example.com` (or use `owner-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com` if available)

### Required APIs

Enable these APIs in the GCP project:

```bash
gcloud services enable workstations.googleapis.com \
    --project=YOUR_PROJECT_ID

gcloud services enable artifactregistry.googleapis.com \
    --project=YOUR_PROJECT_ID

gcloud services enable compute.googleapis.com \
    --project=YOUR_PROJECT_ID

gcloud services enable cloudbuild.googleapis.com \
    --project=YOUR_PROJECT_ID
```

### GPU Quota

You need GPU quota in `us-west1` for NVIDIA Tesla T4. Check your quota:

```bash
gcloud compute regions describe us-west1 \
    --project=YOUR_PROJECT_ID \
    --format="table(quotas.filter(metric='NVIDIA_T4_GPUS'))"
```

If quota is 0, request an increase via the GCP Console under IAM & Admin > Quotas. You need at least 1 NVIDIA T4 GPU.

### gcloud CLI

Install and authenticate:

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud config set compute/region us-west1
```

### Clone the Assets Repository

The Docker image uses assets from Google's example repo:

```bash
git clone https://github.com/GoogleCloudPlatform/cloud-workstations-custom-image-examples.git
cd cloud-workstations-custom-image-examples/examples/images/gnome/noVnc/
```

The `assets/` folder from this repo provides entrypoint scripts, systemd services, and noVNC configuration.

---

## 2. Infrastructure Setup

### 2.1 Workstation Cluster

Create a Cloud Workstation cluster in `us-west1` using the default VPC:

```bash
gcloud workstations clusters create workstation-cluster \
    --region=us-west1 \
    --project=YOUR_PROJECT_ID
```

This takes 5-10 minutes. Verify:

```bash
gcloud workstations clusters describe workstation-cluster \
    --region=us-west1 \
    --project=YOUR_PROJECT_ID
```

### 2.2 Artifact Registry Repository

Create a Docker repository to host the custom workstation image:

```bash
gcloud artifacts repositories create workstation-images \
    --repository-format=docker \
    --location=us-west1 \
    --project=YOUR_PROJECT_ID \
    --description="Cloud Workstation Docker images"
```

### 2.3 Cloud Router and Cloud NAT

The organization has a `constraints/compute.vmExternalIpAccess` policy that prevents public IPs. Cloud NAT is required for internet access from inside the workstation (needed for Nix package downloads, apt updates, etc.):

```bash
# Create Cloud Router
gcloud compute routers create ws-router \
    --network=default \
    --region=us-west1 \
    --project=YOUR_PROJECT_ID

# Create Cloud NAT
gcloud compute routers nats create ws-nat \
    --router=ws-router \
    --region=us-west1 \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges \
    --project=YOUR_PROJECT_ID
```

### 2.4 IAM Configuration

Grant the Cloud Workstations service agent read access to Artifact Registry so it can pull the custom image:

```bash
# Get the service agent email (format: service-PROJECT_NUMBER@gcp-sa-workstations.iam.gserviceaccount.com)
SERVICE_AGENT="service-YOUR_PROJECT_NUMBER@gcp-sa-workstations.iam.gserviceaccount.com"

gcloud artifacts repositories add-iam-policy-binding workstation-images \
    --location=us-west1 \
    --member="serviceAccount:${SERVICE_AGENT}" \
    --role="roles/artifactregistry.reader" \
    --project=YOUR_PROJECT_ID
```

The `roles/workstations.user` role is granted automatically at the workstation level when creating a workstation.

---

## 3. Docker Image

### 3.1 Dockerfile Walkthrough

The Dockerfile is at `workstation-image/Dockerfile`. It uses a multi-stage build:

**Stage 1 -- noVNC Builder:**

```dockerfile
FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/base as novnc-builder

ARG NOVNC_BRANCH=v1.5.0
ARG WEBSOCKIFY_BRANCH=v0.12.0

WORKDIR /out

RUN git clone --quiet --depth 1 --branch $NOVNC_BRANCH https://github.com/novnc/noVNC.git && \
  cd noVNC/utils && \
  git clone  --quiet --depth 1 --branch $WEBSOCKIFY_BRANCH https://github.com/novnc/websockify.git
```

This clones noVNC v1.5.0 and websockify v0.12.0 for the browser-based VNC client.

**Stage 2 -- Final Image:**

The main image starts from the Cloud Workstations predefined base image and installs:

1. **systemd** -- Init system for managing services. Masks unnecessary services (apache2, getty, ldconfig, ssh) to avoid boot conflicts.

2. **GNOME Desktop** -- `ubuntu-desktop-minimal` with supporting packages. Removes `gnome-initial-setup` and `cloud-init`.

3. **Google Antigravity** -- Installed from Google's APT repo at `us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/`. Requires GPG key setup.

4. **Google Chrome** -- Installed from Google's official APT repo. A wrapper script is created using `dpkg-divert` so Chrome always launches with `--no-sandbox --no-zygote --disable-gpu --disable-dev-shm-usage`.

5. **TigerVNC** -- VNC server (tigervnc-standalone-server, tigervnc-common, tigervnc-scraping-server, tigervnc-xorg-extension) plus dbus-x11 and python3-numpy.

6. **noVNC** -- Copied from Stage 1, serves the browser-based VNC client.

7. **Assets** -- Copied from `assets/` directory. Includes:
   - `/google/scripts/entrypoint.sh` -- Custom entrypoint that runs startup scripts, follows journalctl, and starts systemd with a persisted machine ID
   - `/etc/systemd/system/tigervnc.service` -- TigerVNC systemd unit
   - `/etc/systemd/system/novnc.service` -- noVNC systemd unit
   - `/etc/workstation-startup.d/100_add-xstartup.sh` -- Creates VNC xstartup script for GNOME session
   - `/etc/workstation-startup.d/100_persist-machine-id.sh` -- Persists machine-id to HOME disk
   - `/etc/workstation-startup.d/200_persist-nix.sh` -- Restores /nix bind mount and nvidia PATH on boot
   - `/opt/noVNC/index.html` -- Auto-redirect to VNC client with `?autoconnect=true&resize=remote`
   - `/opt/setup-nix.sh` -- One-time Nix installer script

8. **Service enablement** -- TigerVNC and noVNC services are symlinked to `multi-user.target.wants/` and enabled.

9. **Entrypoint** -- `/google/scripts/entrypoint.sh` which runs `/usr/bin/workstation-startup`, follows journalctl for cloud logging, and execs into systemd.

### 3.2 Startup Scripts

Three startup scripts run on every boot (in `/etc/workstation-startup.d/`, executed by `workstation-startup`):

**`100_persist-machine-id.sh`** -- Saves `/etc/machine-id` to `/home/.workstation/machine-id` on first boot. On subsequent boots, the entrypoint passes this ID to systemd so services maintain consistent identity.

**`100_add-xstartup.sh`** -- Creates `~/.vnc/xstartup` if it does not exist. Configures the VNC session to launch a GNOME desktop (used when TigerVNC is the active display server; Sway replaces this in our setup).

**`200_persist-nix.sh`** -- The critical persistence script:

```bash
#!/bin/bash
# Restore /nix bind mount from persistent disk on boot
# Nix store lives on persistent HOME disk at /home/user/nix
# Container root resets on restart, so we re-create the mount each boot
# NOTE: Nix does NOT allow /nix to be a symlink -- must use bind mount

if [ -d /home/user/nix ] && ! mountpoint -q /nix 2>/dev/null; then
    rm -rf /nix 2>/dev/null
    mkdir -p /nix
    mount --bind /home/user/nix /nix
    echo "Restored /nix bind mount from /home/user/nix"
fi

# Restore nvidia PATH/LD_LIBRARY_PATH for GPU access
if [ -d /var/lib/nvidia/bin ]; then
    cat > /etc/profile.d/nvidia.sh << 'EOF'
export PATH=/var/lib/nvidia/bin:$PATH
export LD_LIBRARY_PATH=/var/lib/nvidia/lib64:$LD_LIBRARY_PATH
EOF
    echo "Restored nvidia profile script"
fi
```

### 3.3 Build and Push with Cloud Build

```bash
cd workstation-image/

# Submit to Cloud Build (builds in GCP, no local Docker needed)
gcloud builds submit \
    --tag us-west1-docker.pkg.dev/YOUR_PROJECT_ID/workstation-images/workstation:latest \
    --project=YOUR_PROJECT_ID \
    --region=us-west1
```

Alternatively, build locally and push:

```bash
# Configure Docker for Artifact Registry
gcloud auth configure-docker us-west1-docker.pkg.dev

# Build locally
docker build -t us-west1-docker.pkg.dev/YOUR_PROJECT_ID/workstation-images/workstation:latest .

# Push
docker push us-west1-docker.pkg.dev/YOUR_PROJECT_ID/workstation-images/workstation:latest
```

---

## 4. Workstation Configuration

Create the workstation configuration with the correct machine type and GPU:

```bash
gcloud workstations configs create ws-config \
    --cluster=workstation-cluster \
    --region=us-west1 \
    --machine-type=n1-standard-16 \
    --accelerator-type=nvidia-tesla-t4 \
    --accelerator-count=1 \
    --pd-disk-size=500 \
    --pd-disk-type=pd-ssd \
    --container-custom-image=us-west1-docker.pkg.dev/YOUR_PROJECT_ID/workstation-images/workstation:latest \
    --idle-timeout=14400 \
    --running-timeout=43200 \
    --disable-public-ip-addresses \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --project=YOUR_PROJECT_ID
```

### Configuration Details

| Parameter | Value | Notes |
|-----------|-------|-------|
| Machine type | `n2-standard-8` | 8 vCPU, 32 GB RAM (current deployment) |
| GPU | None | Not required. `02-nvidia.sh` is a no-op when no GPU is present |
| Persistent disk | 200 GB `pd-balanced` | Mounted at `/home`, persists across stop/start |
| Idle timeout | 14400 seconds (4 hours) | Integer only, no `s` suffix |
| Running timeout | 43200 seconds (12 hours) | Maximum session length |
| Public IP | Disabled | Required by org policy `constraints/compute.vmExternalIpAccess` |
| Shielded VM | All three enabled | Required by org policy `constraints/compute.requireShieldedVm` |

---

## 5. Create and Start Workstation

### Create the Workstation

```bash
gcloud workstations create dev-workstation \
    --config=ws-config \
    --cluster=workstation-cluster \
    --region=us-west1 \
    --project=YOUR_PROJECT_ID
```

### Start the Workstation

```bash
gcloud workstations start dev-workstation \
    --config=ws-config \
    --cluster=workstation-cluster \
    --region=us-west1 \
    --project=YOUR_PROJECT_ID
```

### Access the Workstation

The workstation is accessible via the Cloud Workstations proxy. The URL format is:

```
https://dev-workstation.cluster-<CLUSTER_ID>.cloudworkstations.dev
```

You can find the exact URL with:

```bash
gcloud workstations describe dev-workstation \
    --config=ws-config \
    --cluster=workstation-cluster \
    --region=us-west1 \
    --project=YOUR_PROJECT_ID \
    --format="value(host)"
```

The noVNC client auto-redirects via `/opt/noVNC/index.html` to `/vnc.html?autoconnect=true&resize=remote`.

### SSH into the Workstation

```bash
gcloud workstations ssh dev-workstation \
    --config=ws-config \
    --cluster=workstation-cluster \
    --region=us-west1 \
    --project=YOUR_PROJECT_ID
```

### Stop the Workstation

```bash
gcloud workstations stop dev-workstation \
    --config=ws-config \
    --cluster=workstation-cluster \
    --region=us-west1 \
    --project=YOUR_PROJECT_ID
```

---

## 6. Install Nix Package Manager

Nix is installed on the persistent HOME disk so all packages survive workstation restarts.

### 6.1 First-Time Installation

SSH into the workstation and run:

```bash
sh <(curl -L https://nixos.org/nix/install) --no-daemon
```

This installs Nix in single-user mode. The Nix store goes to `/nix/store` by default.

### 6.2 Move Nix Store to Persistent Disk

The `/nix` directory is on the ephemeral container filesystem and resets on reboot. Move it to the persistent HOME disk:

```bash
# Copy /nix to persistent disk
cp -a /nix /home/user/nix
```

The `200_persist-nix.sh` startup script (already in the Docker image) handles restoring the bind mount on every boot:

```bash
# On each boot, 200_persist-nix.sh does:
mkdir -p /nix
mount --bind /home/user/nix /nix
```

**IMPORTANT:** Nix does NOT allow `/nix` to be a symlink. You MUST use a bind mount. If you try `ln -s /home/user/nix /nix`, Nix will reject it and refuse to operate.

### 6.3 Source Nix Profile

Add to `~/.bashrc` (or `~/.zshrc` after zsh is installed):

```bash
if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then
    . $HOME/.nix-profile/etc/profile.d/nix.sh
fi
```

### 6.4 Verify

```bash
nix --version
# Expected: nix (Nix) 2.34.2 (or later)

nix-env -iA nixpkgs.hello
hello
# Expected: Hello, world!
```

---

## 7. Nix Home Manager

Home Manager provides declarative, reproducible management of all user packages and dotfiles.

### 7.1 Install Home Manager

```bash
# Add the Home Manager channel
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

# Install Home Manager
nix-shell '<home-manager>' -A install
```

### 7.2 Create home.nix

Create `~/.config/home-manager/home.nix` on the workstation:

```nix
{ config, pkgs, ... }:

{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  # Allow unfree packages (Chrome, VSCode, etc.)
  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # --- Desktop / Window Manager ---
    sway
    foot
    wofi
    thunar
    clipman
    wl-clipboard
    wayvnc

    # --- Browsers ---
    chromium
    google-chrome

    # --- Dev Tools ---
    neovim
    tmux
    tree
    zsh
    ripgrep
    fd
    jq
    ffmpeg

    # --- IDEs ---
    vscode
    jetbrains.idea-community-bin   # or idea-oss if community-bin unavailable

    # --- Runtime ---
    nodejs_22
  ];
}
```

**Notes:**
- `nixpkgs.config.allowUnfree = true` is required for Google Chrome, VS Code, and other proprietary packages.
- `jetbrains.idea-community` was removed from nixpkgs; use `jetbrains.idea-oss` or `jetbrains.idea-community-bin` as available.
- Cursor IDE is not in nixpkgs; install via AppImage or alternative method if needed.

### 7.3 Apply Configuration

```bash
home-manager switch
```

This installs all packages and creates symlinks in `~/.nix-profile/bin/`.

### 7.4 Verify All Packages

```bash
nvim --version        # NVIM v0.11.x
tmux -V               # tmux 3.6a
zsh --version         # zsh 5.9
ffmpeg -version       # ffmpeg 8.x
chromium --version    # Chromium 146.x
google-chrome-stable --version  # Google Chrome 146.x
code --version        # 1.111.x
sway --version        # sway 1.11
foot --version        # foot 1.26.x
node --version        # v22.x
```

---

## 8. Sway Desktop Environment

The workstation uses Sway (Wayland compositor) with a Tokyo Night theme, running on a headless wlroots backend with wayvnc for VNC access.

### 8.1 Sway Configuration

Deploy the Sway config to `~/.config/sway/config`. The full configuration is at `workstation-image/configs/sway/config` in this repository.

Key features:
- **Tokyo Night color palette** with 10 color variables
- **Gaps:** 6px inner, 12px outer, smart_gaps on
- **Borders:** 2px pixel (no title bars), Tokyo Night themed
- **Headless output:** `HEADLESS-1` at 1920x1080 for wayvnc
- **CTRL+SHIFT modifier** for all keybindings (browser/noVNC friendly; Super key is unreliable through noVNC)
- **Nix path prefix:** All exec commands use full paths via `$nix` variable (`/home/user/.nix-profile/bin`) because Sway's systemd service PATH does not include Nix profile directories
- **Xwayland** started for X11 apps
- **Clipboard manager** autostart (wl-paste + clipman)

### 8.2 Sway Keybindings (33 Total)

**General -- Launch Applications:**

| Key | Action |
|-----|--------|
| `CTRL+SHIFT+Return` | Open Terminal (foot) |
| `CTRL+SHIFT+T` | Open Terminal (foot) |
| `CTRL+SHIFT+R` | Application Launcher (wofi) |
| `CTRL+SHIFT+E` | Open File Manager (Thunar) |
| `CTRL+SHIFT+B` | Open Web Browser (Chrome) |
| `CTRL+SHIFT+N` | Open Antigravity |
| `CTRL+SHIFT+M` | Open IntelliJ IDEA |
| `CTRL+SHIFT+Y` | Open VS Code |
| `CTRL+SHIFT+A` | Clipboard history picker |
| `CTRL+SHIFT+S` | Snippet picker |

**General -- Window Management:**

| Key | Action |
|-----|--------|
| `CTRL+SHIFT+Q` | Close active window |
| `CTRL+SHIFT+F` | Toggle fullscreen |
| `Super+F` | Toggle fullscreen |
| `CTRL+SHIFT+D` | Toggle floating window |
| `CTRL+SHIFT+Escape` | Exit Sway (with confirmation) |

**Navigation:**

| Key | Action |
|-----|--------|
| `CTRL+SHIFT+Left` | Move focus left |
| `CTRL+SHIFT+Right` | Move focus right |
| `CTRL+SHIFT+Up` | Move focus up |
| `CTRL+SHIFT+Down` | Move focus down |

**Window Resize:**

| Key | Action |
|-----|--------|
| `CTRL+SHIFT+,` | Grow window width (20px) |
| `CTRL+SHIFT+.` | Shrink window width (20px) |
| `CTRL+SHIFT+-` | Shrink window height (20px) |
| `CTRL+SHIFT+=` | Grow window height (20px) |

**Switch Workspace (CTRL+SHIFT + key):**

| Key | Workspace |
|-----|-----------|
| `CTRL+SHIFT+U` | 1 |
| `CTRL+SHIFT+I` | 2 |
| `CTRL+SHIFT+O` | 3 |
| `CTRL+SHIFT+P` | 4 |
| `CTRL+SHIFT+H` | 5 |
| `CTRL+SHIFT+J` | 6 |
| `CTRL+SHIFT+K` | 7 |
| `CTRL+SHIFT+L` | 8 |

**Move Window to Workspace (CTRL+SHIFT+ALT + key):**

| Key | Workspace |
|-----|-----------|
| `CTRL+SHIFT+ALT+U` | 1 |
| `CTRL+SHIFT+ALT+I` | 2 |
| `CTRL+SHIFT+ALT+O` | 3 |
| `CTRL+SHIFT+ALT+P` | 4 |
| `CTRL+SHIFT+ALT+H` | 5 |
| `CTRL+SHIFT+ALT+J` | 6 |
| `CTRL+SHIFT+ALT+K` | 7 |
| `CTRL+SHIFT+ALT+L` | 8 |

### 8.3 Swaybar Status Script

The status bar uses swaybar (Sway's built-in bar) with the i3bar JSON protocol for color-coded output. The script is at `workstation-image/configs/swaybar/sway-status`.

Deploy to `~/.local/bin/sway-status` and make executable:

```bash
chmod +x ~/.local/bin/sway-status
```

**Modules (left to right):** NET, GPU, CPU, MEM, DISK, Clock

**Color-coded thresholds:**
- Green (`#9ece6a`): Normal (below warning threshold)
- Yellow (`#e0af68`): Warning (CPU >= 50%, MEM >= 60%, DISK >= 70%)
- Red (`#f7768e`): Critical (CPU >= 80%, MEM >= 80%, DISK >= 85%)

**Module details:**
- **NET:** Ping-based connectivity check to 8.8.8.8
- **GPU:** Uses `/var/lib/nvidia/bin/nvidia-smi` (full path required) to show T4 temperature and utilization
- **CPU:** Real-time calculation via `/proc/stat` delta sampling (500ms interval)
- **MEM:** Used/total from `/proc/meminfo`
- **DISK:** `/home` partition usage from `df`
- **Clock:** `%a %b %d  %H:%M` format

The script outputs the i3bar JSON protocol:
```json
{"version":1}
[
[],
[{"name":"network","full_text":"NET UP","color":"#9ece6a",...}, ...],
```

Refresh interval: 2 seconds.

### 8.4 Waybar (Future Use)

Waybar configs are prepared for future activation when the wlr-layer-shell rendering issue on wayvnc headless is resolved. Files are at:

- `workstation-image/configs/waybar/config.jsonc` -- Module configuration (workspaces, cpu, memory, disk, network, custom/gpu, clock)
- `workstation-image/configs/waybar/style.css` -- Tokyo Night CSS with semi-transparent background, pill-shaped modules (12px border-radius), hover effects, urgent-pulse animation

Deploy to `~/.config/waybar/config` and `~/.config/waybar/style.css` respectively.

To switch from swaybar to Waybar, replace the `bar { ... }` block in the Sway config with:

```
bar {
    swaybar_command /home/user/.nix-profile/bin/waybar
}
```

### 8.5 Systemd Services for Sway Desktop

Create two systemd services for the Sway desktop:

**`/etc/systemd/system/sway-desktop.service`:**

```ini
[Unit]
Description=Sway Wayland Desktop
After=network.target

[Service]
Type=simple
User=user
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=LD_LIBRARY_PATH=/var/lib/nvidia/lib64
ExecStart=/home/user/.nix-profile/bin/sway
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

**`/etc/systemd/system/wayvnc.service`:**

```ini
[Unit]
Description=wayvnc VNC Server
After=sway-desktop.service
Requires=sway-desktop.service

[Service]
Type=simple
User=user
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/home/user/.nix-profile/bin/wayvnc --output=HEADLESS-1 0.0.0.0 5901
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable sway-desktop wayvnc
sudo systemctl start sway-desktop wayvnc
```

---

## 9. Configure Applications

### 9.1 Neovim

Deploy `init.lua` to `~/.config/nvim/init.lua`. The full configuration is at `docs/specs/neovim-config/init.lua` in this repository.

**Key settings:**
- **Theme:** `habamax` with transparent background
- **Leader key:** Space
- **Line numbers:** Relative
- **Tabs:** 2 spaces (4 for Lua/Python)
- **Undo:** Persistent undo to `~/.vim/undodir`
- **Clipboard:** System clipboard integration (`unnamedplus`)
- **Floating terminal:** `<Space>t` toggles a centered floating terminal (80% width/height, rounded border)

**Neovim keybindings:**

| Key | Action |
|-----|--------|
| `<Space>e` | Open file explorer (netrw) |
| `<Space>c` | Clear search highlights |
| `<Space>t` | Toggle floating terminal |
| `Ctrl+h/j/k/l` | Move between windows |
| `<Space>sv` | Split vertically |
| `<Space>sh` | Split horizontally |
| `<Space>bn` | Next buffer |
| `<Space>bp` | Previous buffer |
| `<Space>tn` | New tab |
| `<Space>tx` | Close tab |
| `Y` | Yank to end of line |
| `<` / `>` (visual) | Indent and stay in visual mode |
| `Ctrl+d/u` | Half page scroll (centered) |
| `n/N` | Search results (centered) |
| `Esc` (terminal) | Close floating terminal |

### 9.2 tmux

tmux is installed via Nix Home Manager. Configure in `~/.tmux.conf` as desired.

### 9.3 zsh

zsh is installed via Nix Home Manager. To set as default shell:

```bash
echo "/home/user/.nix-profile/bin/zsh" | sudo tee -a /etc/shells
chsh -s /home/user/.nix-profile/bin/zsh
```

### 9.4 foot (Terminal Emulator)

foot is the default Wayland-native terminal. Configure in `~/.config/foot/foot.ini`. Launched via `CTRL+SHIFT+Return` or `CTRL+SHIFT+T`.

---

## 10. AI CLI Tools

AI CLI tools are installed via npm (Node.js is provided by Nix).

### 10.1 Install Node.js via Nix

Node.js 22 is included in the `home.nix` packages. Verify:

```bash
node --version   # v22.22.x
npm --version    # 10.x
```

### 10.2 Set npm Global Prefix

To avoid permission issues and keep global installs on the persistent disk:

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
```

Add to `~/.bashrc` (or `~/.zshrc`):

```bash
export PATH="$HOME/.npm-global/bin:$PATH"
```

### 10.3 Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
claude --version
# Expected: 2.1.80 (or later)
```

### 10.4 Install Gemini CLI

```bash
npm install -g @anthropic-ai/gemini-cli  # or the correct package name
gemini --version
# Expected: 0.34.0 (or later)
```

---

## 11. Antigravity

Google Antigravity is a proprietary Electron app from Google's APT repo. It is NOT in nixpkgs and must be managed separately.

### 11.1 Copy to Persistent Disk

Antigravity is installed to `/usr/share/antigravity/` by apt in the Docker image. Copy it to the persistent HOME disk:

```bash
cp -a /usr/share/antigravity ~/.antigravity/antigravity
```

### 11.2 Launch with Correct Flags

Antigravity is an Electron app and requires specific flags to run in the containerized Wayland environment:

```bash
~/.antigravity/antigravity/antigravity \
    --no-sandbox \
    --ozone-platform=wayland \
    --disable-gpu \
    --disable-dev-shm-usage
```

**Why each flag is needed:**

| Flag | Reason |
|------|--------|
| `--no-sandbox` | Container environment lacks the kernel features for Chromium's sandbox |
| `--ozone-platform=wayland` | Force Wayland backend (without this, Electron tries X11 and fails with "Missing X server or $DISPLAY") |
| `--disable-gpu` | Disable GPU compositing for VNC rendering stability (CUDA compute is unaffected) |
| `--disable-dev-shm-usage` | `/dev/shm` is only 64MB in k8s containers; Chromium's renderer OOMs on shared memory. This flag uses `/tmp` (~31GB) instead |

The Sway keybinding `CTRL+SHIFT+N` launches Antigravity with all these flags.

### 11.3 Verify

After launching, Antigravity should report version (e.g., v1.107.0) and be fully functional in the browser via noVNC.

---

## 12. GPU Setup

### 12.1 NVIDIA Driver Location

Cloud Workstations with GPU accelerators have NVIDIA drivers pre-installed at a non-standard location:

- **Binaries:** `/var/lib/nvidia/bin/` (contains `nvidia-smi`, `nvidia-debugdump`, etc.)
- **Libraries:** `/var/lib/nvidia/lib64/` (contains `libcuda.so`, `libnvidia-*.so`, etc.)

These are on the ephemeral container filesystem and are always available after boot -- no installation needed.

### 12.2 Profile Script

The `200_persist-nix.sh` startup script creates `/etc/profile.d/nvidia.sh` on each boot:

```bash
export PATH=/var/lib/nvidia/bin:$PATH
export LD_LIBRARY_PATH=/var/lib/nvidia/lib64:$LD_LIBRARY_PATH
```

This ensures `nvidia-smi` and CUDA libraries are available in interactive shells.

### 12.3 System-Wide Library Registration

For applications that don't use `LD_LIBRARY_PATH` (e.g., Electron apps), register the NVIDIA libs system-wide:

```bash
echo "/var/lib/nvidia/lib64" | sudo tee /etc/ld.so.conf.d/nvidia.conf
sudo ldconfig
```

**Note:** This change is on the ephemeral filesystem and must be re-applied after each restart. To persist, add it to the `200_persist-nix.sh` startup script or create a dedicated startup script.

### 12.4 Verify GPU

```bash
/var/lib/nvidia/bin/nvidia-smi
```

Expected output:

```
+-------------------------------------------------------------------+
| NVIDIA-SMI 535.288.01   Driver Version: 535.288.01  CUDA Version: 12.2 |
|-------------------------------------------------------------------+
| GPU  Name             | Tesla T4                                  |
| GPU  Memory           | 15360MiB                                  |
+-------------------------------------------------------------------+
```

### 12.5 Sway Desktop GPU Access

The `sway-desktop.service` systemd unit includes `Environment=LD_LIBRARY_PATH=/var/lib/nvidia/lib64` so that Sway and applications launched from it can access NVIDIA libraries.

The `sway-status` bar script uses the full path `/var/lib/nvidia/bin/nvidia-smi` since the Sway process PATH doesn't include `/var/lib/nvidia/bin`.

---

## 13. Troubleshooting

### /dev/shm is Only 64MB

**Symptom:** Electron/Chromium apps crash with renderer process exit code 5. Error: shared memory allocation failure.

**Cause:** Kubernetes containers default to a 64MB `/dev/shm` tmpfs. Chromium's renderer uses shared memory heavily and OOMs.

**Fix:** Add `--disable-dev-shm-usage` to all Electron/Chromium app launch commands. This redirects shared memory operations to `/tmp` which has ~31GB available.

Affected apps: Antigravity, VS Code, Google Chrome, Chromium.

### Nix Rejects Symlink for /nix

**Symptom:** `nix-env` or `nix-build` fails with errors about `/nix` being a symlink.

**Cause:** Nix explicitly checks that `/nix` is a real directory, not a symlink.

**Fix:** Use a bind mount instead:

```bash
mkdir -p /nix
mount --bind /home/user/nix /nix
```

The `200_persist-nix.sh` startup script handles this automatically.

### PATH Isolation in Sway

**Symptom:** Keybindings fail silently. Apps launched from Sway keybindings cannot be found. "exec foot" does nothing.

**Cause:** Sway runs as a systemd service whose PATH only includes system directories (`/usr/bin`, `/usr/local/bin`, etc.), not Nix profile paths. Nix-installed binaries at `~/.nix-profile/bin/` are invisible to Sway.

**Fix:** Use absolute paths for all `exec` commands in the Sway config. Define a convenience variable:

```
set $nix /home/user/.nix-profile/bin
bindsym $mod+Return exec $nix/foot
```

This applies to ALL Nix-installed binaries: foot, wofi, thunar, code, swaynag, swaymsg, clipman, swaybar, wl-paste.

### Electron Apps Need Wayland Flags

**Symptom:** Electron apps (Antigravity, VS Code) crash with "Missing X server or $DISPLAY".

**Cause:** Electron defaults to X11 backend. In a pure Sway/Wayland environment without a running X server on the expected display, this fails.

**Fix:** Add these flags to all Electron app launches:

```
--no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage
```

### Waybar Layer-Shell Does Not Render

**Symptom:** Waybar starts but its bar is invisible on the screen.

**Cause:** Waybar uses the wlr-layer-shell Wayland protocol to render as an overlay. The headless wlroots backend used with wayvnc does not properly support layer-shell surface rendering.

**Fix:** Use swaybar (Sway's built-in bar) instead. Swaybar renders as part of the Sway compositor and works correctly with the headless backend. The Waybar config files are preserved for future use when/if this issue is resolved.

### floating_modifier Must Be a Single Key

**Symptom:** Sway config fails to load with error about `floating_modifier`.

**Cause:** `floating_modifier Ctrl+Shift` is invalid -- Sway only accepts a single modifier key for `floating_modifier`.

**Fix:** Use `floating_modifier Mod4 normal` (Super key) instead.

### Cloud NAT Required for Internet

**Symptom:** `curl`, `apt-get update`, `nix-env`, or any outbound network request times out from inside the workstation.

**Cause:** The org policy `constraints/compute.vmExternalIpAccess` disables public IPs on VMs. Without a public IP, the workstation has no route to the internet.

**Fix:** Create Cloud Router and Cloud NAT (see Section 2.3). This provides outbound internet access through NAT without requiring a public IP.

### g2 Machine Type and L4 GPU Not Supported

**Symptom:** Creating a workstation config with `--machine-type=g2-standard-16` or `--accelerator-type=nvidia-l4` fails.

**Cause:** Cloud Workstations does not support g2 machine types or L4 accelerators. These are available for regular Compute Engine VMs but not for workstation instances.

**Fix:** Use `n1-standard-16` with `nvidia-tesla-t4` instead. The n1-standard-16 provides 16 vCPU and 60GB RAM (close to the 64GB target). The Tesla T4 provides 16GB VRAM which is sufficient for Antigravity and GPU workloads.

### Swaybar Not Spawning

**Symptom:** Sway loads but no bar appears at the top of the screen.

**Cause:** The default `swaybar` command resolves via the system PATH, which doesn't include Nix-installed binaries.

**Fix:** Use the explicit path in the Sway config:

```
bar {
    swaybar_command /home/user/.nix-profile/bin/swaybar
    status_command /home/user/.local/bin/sway-status
    ...
}
```

### nvidia-smi Shows N/A in Status Bar

**Symptom:** The GPU module in the swaybar shows "GPU N/A" even though the GPU is working.

**Cause:** The sway-status script used bare `nvidia-smi` which is not in the Sway process PATH.

**Fix:** Use the full path `/var/lib/nvidia/bin/nvidia-smi` in the sway-status script.

### Idle Timeout Flag Format

**Symptom:** `gcloud workstations configs create` fails with `--idle-timeout=14400s`.

**Cause:** The `--idle-timeout` flag expects an integer (seconds), not a string with an `s` suffix.

**Fix:** Use `--idle-timeout=14400` (no suffix).

---

## 14. Architecture Reference

### Component Overview

```
Browser (noVNC client)
    |
    | HTTPS (Cloud Workstations proxy)
    |
    v
noVNC (port 80, serves vnc.html)
    |
    | WebSocket -> TCP (websockify)
    |
    v
TigerVNC / wayvnc (port 5901)
    |
    | VNC protocol
    |
    v
Sway Compositor (WLR_BACKENDS=headless)
    |
    +-- swaybar (status bar, top)
    |       +-- sway-status (i3bar JSON protocol)
    +-- foot (terminal emulator)
    +-- wofi (app launcher)
    +-- Antigravity (Electron)
    +-- VS Code (Electron)
    +-- Chrome / Chromium
    +-- IntelliJ IDEA
    +-- Thunar (file manager)
    +-- Xwayland :0 (X11 app compatibility)
```

### Ports

| Port | Service | Protocol | Notes |
|------|---------|----------|-------|
| 80 | noVNC proxy | HTTP/WebSocket | Main access point, serves VNC web client |
| 5901 | TigerVNC / wayvnc | VNC (RFB) | VNC server on display :1 |
| 6080 | noVNC (alternative) | HTTP/WebSocket | Alternative noVNC port (novnc.service listens on 80) |

### Persistent vs Ephemeral Storage

| Location | Storage Type | Survives Restart | Contents |
|----------|-------------|-----------------|----------|
| `/home/user/` | Persistent (200GB pd-balanced) | Yes | User data, configs, Nix store backup, Antigravity, npm globals |
| `/home/user/nix/` | Persistent | Yes | Nix store contents (bind-mounted to /nix) |
| `/home/user/.nix-profile/` | Persistent | Yes | Nix profile symlinks |
| `/home/user/.config/` | Persistent | Yes | Sway, Waybar, Neovim, foot configs |
| `/home/user/.antigravity/` | Persistent | Yes | Antigravity binary |
| `/home/user/.npm-global/` | Persistent | Yes | Claude Code, Gemini CLI |
| `/nix/` | Ephemeral (bind mount restored on boot) | Restored | Bind mount target from /home/user/nix |
| `/etc/profile.d/nvidia.sh` | Ephemeral (recreated on boot) | Recreated | NVIDIA PATH/LD_LIBRARY_PATH |
| `/var/lib/nvidia/` | Ephemeral (provided by GPU driver) | Re-provisioned | NVIDIA drivers, libraries, nvidia-smi |
| `/usr/`, `/opt/`, `/etc/` | Ephemeral (container image) | Reset to image | System packages, systemd services, noVNC |

### Key File Paths (On Workstation)

| Path | Purpose |
|------|---------|
| `~/.config/sway/config` | Sway window manager configuration |
| `~/.local/bin/sway-status` | Swaybar status script (i3bar JSON) |
| `~/.config/waybar/config` | Waybar config (future use) |
| `~/.config/waybar/style.css` | Waybar CSS (future use) |
| `~/.config/nvim/init.lua` | Neovim configuration |
| `~/.config/home-manager/home.nix` | Nix Home Manager declaration |
| `~/.antigravity/antigravity/antigravity` | Antigravity binary |
| `~/.npm-global/bin/claude` | Claude Code CLI |
| `~/.npm-global/bin/gemini` | Gemini CLI |
| `/var/lib/nvidia/bin/nvidia-smi` | NVIDIA system management |
| `/etc/workstation-startup.d/200_persist-nix.sh` | Boot script: Nix bind mount + nvidia profile |
| `/etc/workstation-startup.d/100_add-xstartup.sh` | Boot script: VNC xstartup for GNOME |
| `/etc/workstation-startup.d/100_persist-machine-id.sh` | Boot script: Persist machine-id |
| `/google/scripts/entrypoint.sh` | Container entrypoint (startup + systemd) |

### Key File Paths (In Repository)

| Path | Purpose |
|------|---------|
| `workstation-image/Dockerfile` | Docker image definition |
| `workstation-image/configs/sway/config` | Sway config (source of truth) |
| `workstation-image/configs/swaybar/sway-status` | Swaybar status script (source of truth) |
| `workstation-image/configs/waybar/config.jsonc` | Waybar config (source of truth) |
| `workstation-image/configs/waybar/style.css` | Waybar CSS (source of truth) |
| `workstation-image/assets/etc/workstation-startup.d/200_persist-nix.sh` | Nix persistence script |
| `workstation-image/assets/etc/workstation-startup.d/100_add-xstartup.sh` | VNC xstartup script |
| `workstation-image/assets/etc/workstation-startup.d/100_persist-machine-id.sh` | Machine-id persistence |
| `workstation-image/assets/google/scripts/entrypoint.sh` | Container entrypoint |
| `workstation-image/assets/etc/systemd/system/tigervnc.service` | TigerVNC systemd unit |
| `workstation-image/assets/etc/systemd/system/novnc.service` | noVNC systemd unit |
| `workstation-image/assets/opt/noVNC/index.html` | noVNC auto-redirect page |
| `workstation-image/assets/opt/setup-nix.sh` | One-time Nix installer |
| `docs/specs/neovim-config/init.lua` | Neovim config (source of truth) |
