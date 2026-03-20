# Cloud Workstation

GPU-powered Cloud Workstation in GCP with Sway desktop, Nix package manager, and a full dev environment — accessible from any browser via noVNC.

## Quick Start

### Prerequisites

- A GCP project with **Owner** permissions
- **NVIDIA T4 GPU quota** in `us-west1` (at least 1) — [request quota](https://console.cloud.google.com/iam-admin/quotas)
- **Cloud Shell** or any terminal with `gcloud` CLI installed

### Setup (one command)

```bash
# 1. Authenticate with your GCP account
gcloud auth login

# 2. Run the setup script
git clone https://github.com/ameer00/cloud-workstations.git
cd cloud-workstations
bash scripts/setup.sh -p YOUR_PROJECT_ID
```

That's it. The script submits a Cloud Build job that does everything. **You can close your terminal** — the build runs independently in GCP.

### Get notified when it's done (optional)

Add a Google Chat webhook to receive notifications on progress and completion:

```bash
bash scripts/setup.sh -p YOUR_PROJECT_ID --webhook "https://chat.googleapis.com/v1/spaces/XXXXX/messages?key=YYY&token=ZZZ"
```

To create a webhook: Google Chat → Create Space → Space name → Apps & integrations → Manage webhooks → Copy URL.

You'll receive messages when:
- Build starts
- Infrastructure is ready (Docker image built)
- Workstation is running (SSH ready)
- Setup completes (with PASS/FAIL summary and workstation URL)
- Setup fails (with error details and retry instructions)

### Track Progress

The script prints a Cloud Console URL. You can also check via CLI:

```bash
gcloud builds log BUILD_ID --stream --project=YOUR_PROJECT_ID --region=us-west1
```

Setup takes ~30-45 minutes (cluster creation + Nix package installation).

### Connect

Once setup completes, start your workstation and open the URL in a browser:

```bash
# Start the workstation
gcloud workstations start dev-workstation \
  --config=ws-config --cluster=workstation-cluster \
  --region=us-west1 --project=YOUR_PROJECT_ID

# Get the URL
gcloud workstations describe dev-workstation \
  --config=ws-config --cluster=workstation-cluster \
  --region=us-west1 --project=YOUR_PROJECT_ID \
  --format="value(host)"
```

Open `https://<host>` in your browser. The noVNC desktop loads automatically.

## What You Get

| Component | Details |
|-----------|---------|
| **Machine** | n1-standard-16 (60GB RAM) + NVIDIA Tesla T4 GPU |
| **Storage** | 500GB persistent SSD (survives reboots) |
| **Desktop** | Sway (Wayland) with Tokyo Night theme via noVNC |
| **Terminal** | ZSH + Starship prompt + Operator Mono font (size 18) |
| **Browsers** | Google Chrome, Chromium |
| **IDEs** | VS Code, Neovim (with custom config) |
| **AI Tools** | Claude Code, Gemini CLI |
| **Apps** | Antigravity, tmux, ripgrep, fd, jq, ffmpeg |
| **Auto-start** | Cloud Scheduler starts workstation daily at 7AM PT |
| **Boot apps** | 4 workspaces auto-launch: terminal, Chrome, Antigravity, terminal |

## Re-running Setup

The setup is fully idempotent. If it fails or you want to update, just run it again:

```bash
bash scripts/setup.sh -p YOUR_PROJECT_ID
```

Existing resources are detected and skipped. Only missing components are created.
