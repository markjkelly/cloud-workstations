# Cloud Workstation

GPU-powered Cloud Workstation in GCP with Sway desktop, Nix package manager, and a full dev environment — accessible from any browser via noVNC.

## Quick Start

1. Clone this repo
2. Run `bash scripts/configure.sh` to set your GCP project details
3. Run `bash scripts/ws.sh setup -p YOUR_PROJECT_ID`

## Setup

### Prerequisites

1. A GCP project where you have **Owner** role
2. **NVIDIA T4 GPU quota** in `us-west1` (at least 1) — [check/request quota here](https://console.cloud.google.com/iam-admin/quotas?metric=NVIDIA_T4_GPUS)
3. **Cloud Shell** (recommended) or any terminal with `gcloud` CLI

### Step 1: Authenticate

Open [Cloud Shell](https://shell.cloud.google.com) and run:

```bash
gcloud auth login
```

### Step 2: Clone and configure

```bash
git clone https://github.com/your-github-username/cloud-workstations.git
cd cloud-workstations
bash scripts/configure.sh
```

This will prompt you for your GCP project ID, project number, org domain, name, and email, then update all config files with your values.

### Step 3: Run setup

```bash
bash scripts/ws.sh setup -p YOUR_PROJECT_ID
```

Replace `YOUR_PROJECT_ID` with the project ID you entered during configuration.

**You can close your terminal immediately after the script prints the build ID.** All work runs inside Cloud Build and will continue independently.

### Step 4 (optional): Get notified when it's done

#### Google Chat webhook

1. Open [Google Chat](https://chat.google.com) → Create a Space → Space name → **Apps & integrations** → **Manage webhooks** → Copy URL

```bash
bash scripts/ws.sh setup -p YOUR_PROJECT_ID -w "YOUR_WEBHOOK_URL"
```

#### Email

```bash
bash scripts/ws.sh setup -p YOUR_PROJECT_ID -e "you@example.com"
```

#### Both

```bash
bash scripts/ws.sh setup -p YOUR_PROJECT_ID -w "YOUR_WEBHOOK_URL" -e "you@example.com"
```

You'll receive notifications when:
- Build starts (with link to Cloud Console)
- Docker image is built
- Workstation is running
- Setup completes (with workstation URL) or fails (with error details)

### Track progress

The setup script prints a Cloud Console link. You can also stream logs:

```bash
gcloud builds log BUILD_ID --stream --project=YOUR_PROJECT_ID --region=us-west1
```

Setup takes approximately **30-45 minutes**.

## After Setup

### Start your workstation

The setup script stops the workstation at the end to save costs. Start it when you're ready:

```bash
gcloud workstations start dev-workstation \
  --config=ws-config \
  --cluster=workstation-cluster \
  --region=us-west1 \
  --project=YOUR_PROJECT_ID
```

### Connect via browser

Get the workstation URL:

```bash
gcloud workstations describe dev-workstation \
  --config=ws-config \
  --cluster=workstation-cluster \
  --region=us-west1 \
  --project=YOUR_PROJECT_ID \
  --format="value(host)"
```

Open `https://<host>` in your browser. The noVNC desktop loads automatically with 4 pre-launched workspaces.

### Daily auto-start

A Cloud Scheduler job starts the workstation every day at **7:00 AM Pacific**. No action needed.

## What's Included

| Component | Details |
|-----------|---------|
| **Machine** | n1-standard-16 (60GB RAM) + NVIDIA Tesla T4 GPU (16GB VRAM) |
| **Storage** | 500GB persistent SSD (all data survives reboots) |
| **Desktop** | Sway (Wayland) with Tokyo Night theme, accessed via noVNC in browser |
| **Terminal** | foot terminal, ZSH + Starship prompt, Operator Mono Book font (size 18) |
| **Fonts** | Operator Mono, CascadiaCode, CaskaydiaCove Nerd Font, FiraCodeiScript |
| **Browsers** | Google Chrome, Chromium |
| **IDEs** | VS Code, Neovim (custom config) |
| **AI Tools** | Claude Code, Gemini CLI |
| **Apps** | Antigravity, tmux, ripgrep, fd, jq, ffmpeg, wofi, thunar |
| **Auto-start** | Cloud Scheduler starts workstation daily at 7AM PT |
| **Boot apps** | 4 workspaces auto-launch: terminal, Chrome, Antigravity, terminal |
| **Packages** | Managed via Nix Home Manager on persistent disk |

## Keyboard Shortcuts

All shortcuts use `CTRL+SHIFT` as the modifier (works through noVNC in browser).

| Shortcut | Action |
|----------|--------|
| `CTRL+SHIFT+Enter` | New terminal |
| `CTRL+SHIFT+B` | Chrome browser |
| `CTRL+SHIFT+N` | Antigravity |
| `CTRL+SHIFT+Y` | VS Code |
| `CTRL+SHIFT+R` | App launcher (wofi) |
| `CTRL+SHIFT+E` | File manager |
| `CTRL+SHIFT+Q` | Close window |
| `CTRL+SHIFT+F` | Toggle fullscreen |
| `CTRL+SHIFT+U/I/O/P` | Switch to workspace 1/2/3/4 |
| `CTRL+SHIFT+H/J/K/L` | Switch to workspace 5/6/7/8 |

## Re-running Setup

The setup is fully **idempotent**. If it fails or you want to update, just run it again:

```bash
bash scripts/ws.sh setup -p YOUR_PROJECT_ID
```

Existing resources are detected and skipped. Only missing components are created.

## Teardown / Cleanup

To delete **all** resources created by setup (workstation, cluster, images, NAT, scheduler):

```bash
bash scripts/ws.sh teardown -p YOUR_PROJECT_ID
```

Add `-y` to skip the confirmation prompt. Add `-w` / `-e` for notifications.

This is useful for:
- Testing setup from scratch
- Cleaning up a project you no longer need
- Freeing GPU quota for another project

After teardown, you can re-run `setup.sh` to recreate everything.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No GPU quota" | [Request NVIDIA_T4_GPUS quota](https://console.cloud.google.com/iam-admin/quotas) in us-west1 (at least 1) |
| Build fails mid-way | Re-run `setup.sh` — it picks up where it left off |
| Can't connect via noVNC | Ensure workstation is started, wait 30s for Sway + wayvnc to boot |
| Apps not on workspaces | Wait 15-20s after boot for auto-launch to complete |
| Cloud Shell disconnected | No problem — Cloud Build continues independently. Check progress in Cloud Console |
