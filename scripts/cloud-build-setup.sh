#!/bin/bash
# =============================================================================
# cloud-build-setup.sh — Main setup script (runs inside Cloud Build or locally)
# =============================================================================
# Creates the ENTIRE Cloud Workstation infrastructure from scratch.
# Every step is idempotent, self-recovering, and tested.
#
# Can run inside Cloud Build (REPO_DIR=/workspace/repo) or locally
# (auto-detects repo root from script location).
# =============================================================================

set -euo pipefail

PROJECT_ID="${1:?Usage: cloud-build-setup.sh PROJECT_ID REGION [WEBHOOK_URL] [EMAIL_FUNC_URL] [EMAIL] [USER_ACCOUNT]}"
REGION="${2:-us-west1}"
WEBHOOK_URL="${3:-}"
EMAIL_FUNC_URL="${4:-}"
EMAIL="${5:-}"
USER_ACCOUNT="${6:-}"
CLUSTER="workstation-cluster"
CONFIG="ws-config"
WORKSTATION="dev-workstation"
AR_REPO="workstation-images"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/workstation:latest"
PASS=0; FAIL=0; WARN=0
START_TIME=$(date +%s)

# Auto-detect repo directory: use /workspace/repo (Cloud Build) or derive from script location
if [ -d "/workspace/repo/scripts" ]; then
    REPO_DIR="/workspace/repo"
else
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

log()  { echo "[$(date '+%H:%M:%S')] $1"; }
step() { echo ""; echo "========================================"; echo "  $1"; echo "========================================"; }

# Send Google Chat / Slack webhook notification
notify_webhook() {
    [ -z "$WEBHOOK_URL" ] && return 0
    local title="$1" subtitle="$2" body="$3"
    curl -s -X POST "$WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "{
            \"cards\": [{
                \"header\": {
                    \"title\": \"${title}\",
                    \"subtitle\": \"${subtitle}\"
                },
                \"sections\": [{
                    \"widgets\": [{
                        \"textParagraph\": {\"text\": \"${body}\"}
                    }]
                }]
            }]
        }" >/dev/null 2>&1 || true
}

# Send email notification via Cloud Function
notify_email() {
    [ -z "$EMAIL_FUNC_URL" ] || [ -z "$EMAIL" ] && return 0
    local subject="$1" body="$2"
    curl -s -X POST "$EMAIL_FUNC_URL" \
        -H "Content-Type: application/json" \
        -d "{\"to\": \"${EMAIL}\", \"subject\": \"${subject}\", \"body\": \"${body}\"}" \
        >/dev/null 2>&1 || true
}

# Send to all configured channels
notify() {
    local title="$1" subtitle="$2" body="$3"
    notify_webhook "$title" "$subtitle" "$body"
    notify_email "$title — $subtitle" "$body"
}

# Send failure notification and exit
notify_and_fail() {
    local elapsed=$(( $(date +%s) - START_TIME ))
    local mins=$(( elapsed / 60 ))
    notify "Setup FAILED" "Project: ${PROJECT_ID}" \
        "Failed at: <b>$1</b><br>After: ${mins} minutes<br>PASS: ${PASS} | FAIL: ${FAIL} | WARN: ${WARN}<br><br>Re-run <code>setup.sh</code> to retry (idempotent)."
    exit 1
}

# Trap unexpected exits
trap 'notify_and_fail "Unexpected error (line $LINENO)"' ERR

# Retry a command up to N times with delay
retry() {
    local max_attempts=$1 delay=$2; shift 2
    for attempt in $(seq 1 "$max_attempts"); do
        if "$@" 2>/dev/null; then return 0; fi
        [ "$attempt" -lt "$max_attempts" ] && { log "  Retry $attempt/$max_attempts (waiting ${delay}s)..."; sleep "$delay"; }
    done
    return 1
}

# Test helper: record pass/fail
test_pass() { PASS=$((PASS + 1)); log "  PASS: $1"; }
test_fail() { FAIL=$((FAIL + 1)); log "  FAIL: $1"; }
test_warn() { WARN=$((WARN + 1)); log "  WARN: $1"; }

# SSH helper with retry and timeout — runs command on workstation
ws_ssh() {
    retry 3 10 timeout 300 gcloud workstations ssh "$WORKSTATION" \
        --project="$PROJECT_ID" --region="$REGION" \
        --cluster="$CLUSTER" --config="$CONFIG" \
        --command="$1"
}

# SSH helper for long-running commands (15 min timeout, fewer retries)
ws_ssh_long() {
    retry 2 15 timeout 900 gcloud workstations ssh "$WORKSTATION" \
        --project="$PROJECT_ID" --region="$REGION" \
        --cluster="$CLUSTER" --config="$CONFIG" \
        --command="$1"
}

# Pipe helper — accepts stdin piped to workstation command
ws_pipe() {
    retry 3 10 timeout 300 gcloud workstations ssh "$WORKSTATION" \
        --project="$PROJECT_ID" --region="$REGION" \
        --cluster="$CLUSTER" --config="$CONFIG" \
        --command="$1"
}

# Source Nix profile — works with both old and new Nix profile paths
NIX_SOURCE='if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then . ~/.nix-profile/etc/profile.d/nix.sh; elif [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; fi; export PATH="$HOME/.nix-profile/bin:$HOME/.local/state/nix/profiles/profile/bin:$PATH"'

PROJECT_NUMBER=""

# =========================================================================
step "Step 1/19: Enable APIs"
# =========================================================================
log "Enabling required GCP APIs..."
retry 3 5 gcloud services enable \
    workstations.googleapis.com \
    artifactregistry.googleapis.com \
    compute.googleapis.com \
    cloudscheduler.googleapis.com \
    cloudresourcemanager.googleapis.com \
    --project="$PROJECT_ID" --quiet

# Verify
for api in workstations artifactregistry compute cloudscheduler; do
    if gcloud services list --enabled --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | grep -q "$api"; then
        test_pass "$api API enabled"
    else
        test_fail "$api API not enabled"
    fi
done

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
log "Project number: $PROJECT_NUMBER"

# =========================================================================
step "Step 2/19: Create Artifact Registry"
# =========================================================================
if gcloud artifacts repositories describe "$AR_REPO" \
    --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Already exists — skipping"
else
    retry 2 5 gcloud artifacts repositories create "$AR_REPO" \
        --repository-format=docker \
        --location="$REGION" \
        --project="$PROJECT_ID" \
        --description="Cloud Workstation Docker images"
fi
# Verify
if gcloud artifacts repositories describe "$AR_REPO" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    test_pass "Artifact Registry '$AR_REPO'"
else
    test_fail "Artifact Registry '$AR_REPO' not created"
fi

# Wait for AR to be fully propagated (GCP eventual consistency)
# Without this, the Docker build may fail to push because AR is not yet visible.
log "Waiting 30s for Artifact Registry propagation..."
sleep 30

# =========================================================================
step "Step 3/19: Build and push Docker image"
# =========================================================================
# Verify AR is accessible before building (guards against GCP eventual consistency)
log "Verifying Artifact Registry accessibility..."
for i in $(seq 1 6); do
    if gcloud artifacts repositories describe "$AR_REPO" \
        --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        log "  AR accessible (attempt $i)"
        break
    fi
    log "  Waiting for AR (attempt $i/6)..."
    sleep 10
done

log "Building Docker image (this takes 10-15 minutes)..."
cd "${REPO_DIR}/workstation-image"
if retry 2 30 gcloud builds submit \
    --tag="$IMAGE" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --timeout=1800 \
    --quiet; then
    test_pass "Docker image built and pushed"
    notify "Progress: Image Built" "Project: ${PROJECT_ID}" "Docker image ready. Creating workstation cluster next (5-10 min)..."
else
    test_fail "Docker image build failed"
    notify_and_fail "Docker image build"
fi
cd "${REPO_DIR}"

# =========================================================================
step "Step 4/19: Ensure default VPC network + Cloud NAT"
# =========================================================================
# Ensure default VPC network exists (required for cluster + NAT)
if gcloud compute networks describe default --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Default VPC network exists"
else
    log "Creating default VPC network..."
    gcloud compute networks create default \
        --subnet-mode=auto --project="$PROJECT_ID" --quiet 2>&1 | head -3
    log "Default network created"
fi

if gcloud compute routers describe ws-router \
    --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Cloud Router already exists — skipping"
else
    retry 2 5 gcloud compute routers create ws-router \
        --network=default --region="$REGION" --project="$PROJECT_ID"
fi

if gcloud compute routers nats describe ws-nat \
    --router=ws-router --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Cloud NAT already exists — skipping"
else
    retry 2 5 gcloud compute routers nats create ws-nat \
        --router=ws-router --region="$REGION" \
        --auto-allocate-nat-external-ips \
        --nat-all-subnet-ip-ranges --project="$PROJECT_ID"
fi
test_pass "Cloud NAT configured"

# =========================================================================
step "Step 5/19: Create Workstation Cluster"
# =========================================================================
if gcloud workstations clusters describe "$CLUSTER" \
    --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Cluster already exists — skipping"
else
    log "Creating cluster (5-10 minutes)..."
    retry 2 30 gcloud workstations clusters create "$CLUSTER" \
        --region="$REGION" --project="$PROJECT_ID"
fi
# Verify
if gcloud workstations clusters describe "$CLUSTER" \
    --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    test_pass "Workstation cluster '$CLUSTER'"
else
    test_fail "Workstation cluster not created"
fi

# =========================================================================
step "Step 6/19: Grant AR access to service accounts"
# =========================================================================
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
WS_SA="service-${PROJECT_NUMBER}@gcp-sa-workstations.iam.gserviceaccount.com"

# Grant AR reader to both the Workstations service agent AND the compute SA
# (compute SA is used as the workstation's service account for image pulling)
for SA in "$WS_SA" "$COMPUTE_SA"; do
    gcloud artifacts repositories add-iam-policy-binding "$AR_REPO" \
        --location="$REGION" \
        --member="serviceAccount:${SA}" \
        --role="roles/artifactregistry.reader" \
        --project="$PROJECT_ID" --quiet --format=none 2>&1 || true
done
test_pass "AR reader granted to Workstations SA and Compute SA"

# =========================================================================
step "Step 7/19: Create Workstation Config"
# =========================================================================
if gcloud workstations configs describe "$CONFIG" \
    --cluster="$CLUSTER" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Config already exists — skipping"
else
    # Must specify --service-account so workstation VMs can pull the custom image
    retry 2 10 gcloud workstations configs create "$CONFIG" \
        --cluster="$CLUSTER" --region="$REGION" \
        --machine-type=n1-standard-16 \
        --accelerator-type=nvidia-tesla-t4 --accelerator-count=1 \
        --pd-disk-size=500 --pd-disk-type=pd-ssd \
        --container-custom-image="$IMAGE" \
        --service-account="$COMPUTE_SA" \
        --idle-timeout=14400 --running-timeout=43200 \
        --disable-public-ip-addresses \
        --shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring \
        --project="$PROJECT_ID"
fi
if gcloud workstations configs describe "$CONFIG" \
    --cluster="$CLUSTER" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    test_pass "Workstation config '$CONFIG'"
else
    test_fail "Workstation config not created"
fi

# =========================================================================
step "Step 8/19: Create and start Workstation"
# =========================================================================
if gcloud workstations describe "$WORKSTATION" \
    --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
    --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Workstation already exists"
else
    retry 2 10 gcloud workstations create "$WORKSTATION" \
        --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
        --project="$PROJECT_ID"
fi

# Check if already running
WS_STATE=$(gcloud workstations describe "$WORKSTATION" \
    --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
    --project="$PROJECT_ID" --format="value(state)" 2>/dev/null || echo "UNKNOWN")

if [ "$WS_STATE" != "STATE_RUNNING" ]; then
    log "Starting workstation (3-5 minutes)..."
    if ! gcloud workstations start "$WORKSTATION" \
        --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
        --project="$PROJECT_ID" 2>&1; then
        test_fail "Workstation start failed"
        notify_and_fail "Workstation start"
    fi
fi

# Wait for SSH with extended timeout
log "Waiting for SSH access..."
SSH_READY=false
for i in $(seq 1 60); do
    if gcloud workstations ssh "$WORKSTATION" \
        --project="$PROJECT_ID" --region="$REGION" \
        --cluster="$CLUSTER" --config="$CONFIG" \
        --command="echo ready" 2>/dev/null | grep -q "ready"; then
        SSH_READY=true
        test_pass "SSH access (attempt $i)"
        break
    fi
    sleep 10
done
if [ "$SSH_READY" = false ]; then
    test_fail "SSH access after 10 minutes"
    notify_and_fail "SSH access to workstation"
fi
notify "Progress: Workstation Running" "Project: ${PROJECT_ID}" "Workstation is up and SSH ready. Installing Nix and packages next (10-15 min)..."

# =========================================================================
step "Step 8b/19: Grant user access to workstation"
# =========================================================================
# Cloud Workstations require workstation-level IAM (not just project-level)
# for users to connect via browser. Grant roles/workstations.user to the
# caller's account so they can access the workstation UI.
if [ -n "$USER_ACCOUNT" ]; then
    log "Granting workstations.user to $USER_ACCOUNT..."
    # Get current policy, add user, set policy
    POLICY_FILE=$(mktemp)
    gcloud workstations get-iam-policy "$WORKSTATION" \
        --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
        --project="$PROJECT_ID" --format=json > "$POLICY_FILE" 2>/dev/null

    # Add user to existing workstations.user binding (or create it)
    if grep -q "roles/workstations.user" "$POLICY_FILE"; then
        # Add user to existing binding if not already present
        if ! grep -q "$USER_ACCOUNT" "$POLICY_FILE"; then
            python3 -c "
import json, sys
p = json.load(open('$POLICY_FILE'))
for b in p.get('bindings', []):
    if b['role'] == 'roles/workstations.user':
        b['members'].append('user:$USER_ACCOUNT')
json.dump(p, open('$POLICY_FILE', 'w'))
"
        fi
    else
        python3 -c "
import json
p = json.load(open('$POLICY_FILE'))
p.setdefault('bindings', []).append({
    'role': 'roles/workstations.user',
    'members': ['user:$USER_ACCOUNT']
})
json.dump(p, open('$POLICY_FILE', 'w'))
"
    fi

    if gcloud workstations set-iam-policy "$WORKSTATION" "$POLICY_FILE" \
        --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
        --project="$PROJECT_ID" --quiet 2>/dev/null; then
        test_pass "Workstation access granted to $USER_ACCOUNT"
    else
        test_warn "Could not grant workstation access to $USER_ACCOUNT"
    fi
    rm -f "$POLICY_FILE"
else
    test_warn "No USER_ACCOUNT provided — skipping workstation IAM grant"
fi

# =========================================================================
step "Step 9/19: Install Nix package manager"
# =========================================================================
# Cloud Workstations mount /nix from the persistent disk during first boot.
# Nix installs to /nix. Step 11 copies to /home/user/nix for restart persistence.
if ws_ssh "command -v nix >/dev/null 2>&1 && echo exists || (${NIX_SOURCE} && command -v nix >/dev/null 2>&1 && echo exists || echo missing)" | grep -q "exists"; then
    log "Nix already installed — skipping"
    test_pass "Nix persistent install"
else
    log "Installing Nix..."
    # Clean up any broken prior install state
    ws_ssh 'rm -rf ~/.nix-profile ~/.local/state/nix ~/.nix-channels ~/.nix-defexpr 2>/dev/null; true'
    # Download installer first (fast, won't timeout)
    if ! ws_ssh 'curl -L -o /tmp/nix-install.sh https://nixos.org/nix/install && chmod +x /tmp/nix-install.sh'; then
        test_fail "Nix installer download"
        notify_and_fail "Nix installer download"
    fi
    # Run installer separately (the long part — use ws_ssh_long)
    if ! ws_ssh_long 'sh /tmp/nix-install.sh --no-daemon'; then
        test_fail "Nix installation"
        notify_and_fail "Nix installation"
    fi
    # Verify
    if ws_ssh "${NIX_SOURCE} && nix --version" 2>/dev/null | grep -q "nix"; then
        test_pass "Nix installed"
    else
        test_fail "Nix installation verification"
        notify_and_fail "Nix installation verification"
    fi
fi

# =========================================================================
step "Step 10/19: Install Nix Home Manager + packages"
# =========================================================================
log "Setting up Home Manager and packages (this takes 5-10 minutes)..."

# Add channels (fast)
log "  Adding home-manager channel..."
if ! ws_ssh "${NIX_SOURCE}"' && if ! nix-channel --list | grep -q home-manager; then nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && nix-channel --update; else echo "channel exists"; fi'; then
    test_fail "Home Manager channel setup"
    notify_and_fail "Home Manager channel setup"
fi

# Install home-manager (medium)
log "  Installing home-manager..."
if ! ws_ssh_long "${NIX_SOURCE}"' && if ! command -v home-manager &>/dev/null; then nix-shell "<home-manager>" -A install; else echo "home-manager exists"; fi'; then
    test_fail "Home Manager install"
    notify_and_fail "Home Manager install"
fi

# Verify home-manager is available
if ws_ssh "${NIX_SOURCE} && home-manager --version" 2>/dev/null | grep -q "[0-9]"; then
    test_pass "Home Manager installed"
else
    test_fail "Home Manager not available after install"
    notify_and_fail "Home Manager verification"
fi

# Create home.nix (fast — use ws_pipe)
log "  Deploying home.nix..."
cat << 'NIXEOF' | ws_pipe "mkdir -p ~/.config/home-manager && cat > ~/.config/home-manager/home.nix"
{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    # Dev tools
    neovim tmux tree ffmpeg git gh curl wget htop ripgrep fd jq unzip

    # Browsers
    chromium google-chrome

    # IDEs
    vscode jetbrains.idea-oss

    # AI IDEs
    code-cursor windsurf zed-editor

    # Sway ecosystem
    sway waybar foot wofi thunar grim slurp wl-clipboard clipman mako swaylock swayidle wayvnc

    # Node.js for CLI tools
    nodejs_22
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -la";
      vim = "nvim";
      vi = "nvim";
      t1 = "claude-tmux 1";
      t2 = "claude-tmux 2";
      t3 = "claude-tmux 3";
      t4 = "claude-tmux 4";
      t5 = "claude-tmux 5";
      t6 = "claude-tmux 6";
      t7 = "claude-tmux 7";
      t8 = "claude-tmux 8";
      t9 = "claude-tmux 9";
      t10 = "claude-tmux 10";
      cc = "claude-tmux";
      ta = "tmux attach";
      tl = "tmux list-sessions";
      tk = "tmux kill-session -t";
      td = "tmux detach";
      tn = "tmux new-session";
      ts = "tmux switch-client -t";
    };
    initContent = ''
      # Nix profile
      if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then . $HOME/.nix-profile/etc/profile.d/nix.sh; fi
      if [ -e $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then . $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh; fi

      # Timezone
      export TZ="America/Los_Angeles"

      # PATH additions
      export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/var/lib/nvidia/bin:$PATH"
      export LD_LIBRARY_PATH=/var/lib/nvidia/lib64:$LD_LIBRARY_PATH

      # Go
      export GOROOT="$HOME/go"
      export GOPATH="$HOME/gopath"
      export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

      # Rust
      export PATH="$HOME/.cargo/bin:$PATH"

      # pyenv
      export PYENV_ROOT="$HOME/.pyenv"
      export PATH="$PYENV_ROOT/bin:$PATH"
      if command -v pyenv &>/dev/null; then
          eval "$(pyenv init -)"
      fi

      # rbenv
      export PATH="$HOME/.rbenv/bin:$PATH"
      if command -v rbenv &>/dev/null; then
          eval "$(rbenv init -)"
      fi

      # Source environment
      if [ -f $HOME/.env ]; then
          set -a
          . $HOME/.env
          set +a
      fi

      # Starship prompt
      if command -v starship &>/dev/null; then
          eval "$(starship init zsh)"
      fi

      # User customizations
      [ -f $HOME/.zshrc.local ] && . $HOME/.zshrc.local
    '';
  };

  home.file.".config/nvim/init.lua".source = /home/user/.config/home-manager/nvim-init.lua;
  home.file.".config/sway/config".source = /home/user/.config/home-manager/sway-config;
  home.file.".config/waybar/config".source = /home/user/.config/home-manager/waybar-config.json;
  home.file.".config/waybar/style.css".source = /home/user/.config/home-manager/waybar-style.css;
  home.file.".config/foot/foot.ini".text = ''
    [main]
    font=monospace:size=11
    [colors]
    background=1a1b26
    foreground=c0caf5
  '';

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    BROWSER = "chromium";
  };

  programs.starship.enable = true;

  programs.home-manager.enable = true;
}
NIXEOF

# Run home-manager switch (long but isolated)
log "  Running home-manager switch (this is the slow part)..."
if ! ws_ssh_long "${NIX_SOURCE}"' && home-manager switch'; then
    test_fail "Home Manager switch"
    notify_and_fail "Home Manager switch"
fi

# Verify key packages
VERIFY=$(ws_ssh "${NIX_SOURCE}"' && echo "sway=$(sway --version 2>/dev/null | head -1)" && echo "nvim=$(nvim --version 2>/dev/null | head -1)" && echo "node=$(node --version 2>/dev/null)"')
echo "$VERIFY" | grep -q "sway" && test_pass "Sway installed" || test_warn "Sway not verified"
echo "$VERIFY" | grep -q "NVIM" && test_pass "Neovim installed" || test_warn "Neovim not verified"
echo "$VERIFY" | grep -q "v22" && test_pass "Node.js installed" || test_warn "Node.js not verified"

# =========================================================================
step "Step 11/19: Persist Nix store for restarts"
# =========================================================================
# Cloud Workstations only persist /home across restarts. The /nix mount
# is ephemeral and gets wiped on container restart. Copy the entire nix
# store to /home/user/nix so the startup script (200_persist-nix.sh) can
# bind-mount it back to /nix on each boot.
log "Copying /nix to /home/user/nix for restart persistence..."
ws_ssh_long '
if [ -d /nix/store ] && [ "$(ls /nix/store/ 2>/dev/null | wc -l)" -gt 0 ]; then
    rm -rf /home/user/nix 2>/dev/null
    cp -a /nix /home/user/nix
    echo "COPY_DONE: $(du -sh /home/user/nix 2>/dev/null | cut -f1)"
else
    echo "COPY_SKIP: /nix/store empty or missing"
fi
' 2>&1 | tail -3

if ws_ssh "test -d /home/user/nix/store && echo exists" 2>/dev/null | grep -q "exists"; then
    test_pass "Nix store persisted to /home/user/nix"
else
    test_fail "Nix store persistence"
    notify_and_fail "Nix store persistence copy"
fi

# =========================================================================
step "Step 12/19: Deploy boot scripts and fonts"
# =========================================================================
log "Deploying boot scripts..."
tar czf /tmp/boot-scripts.tar.gz -C "${REPO_DIR}/workstation-image/boot" .
cat /tmp/boot-scripts.tar.gz | ws_pipe "mkdir -p ~/boot && cd ~/boot && tar xzf -"

SCRIPT_COUNT=$(ws_ssh "ls ~/boot/*.sh 2>/dev/null | wc -l")
if [ "${SCRIPT_COUNT:-0}" -ge 9 ]; then
    test_pass "Boot scripts deployed ($SCRIPT_COUNT files)"
else
    test_fail "Boot scripts deployment (only $SCRIPT_COUNT files)"
fi

log "Deploying fonts..."
tar czf /tmp/dev-fonts.tar.gz -C "${REPO_DIR}/dev-fonts" .
cat /tmp/dev-fonts.tar.gz | ws_pipe "mkdir -p ~/boot/fonts && cd ~/boot/fonts && tar xzf -"
test_pass "Fonts deployed"

# =========================================================================
step "Step 13/19: Deploy configs"
# =========================================================================
cat "${REPO_DIR}/workstation-image/configs/sway/config" | \
    ws_pipe "mkdir -p ~/.config/sway && cat > ~/.config/sway/config"
test_pass "Sway config deployed"

cat "${REPO_DIR}/workstation-image/configs/swaybar/sway-status" | \
    ws_pipe "mkdir -p ~/.local/bin && cat > ~/.local/bin/sway-status && chmod +x ~/.local/bin/sway-status"
test_pass "sway-status deployed"

cat "${REPO_DIR}/workstation-image/configs/waybar/config.jsonc" | \
    ws_pipe "mkdir -p ~/.config/waybar && cat > ~/.config/waybar/config.jsonc"
cat "${REPO_DIR}/workstation-image/configs/waybar/style.css" | \
    ws_pipe "cat > ~/.config/waybar/style.css"
test_pass "Waybar config deployed"

# Deploy wofi config
cat "${REPO_DIR}/workstation-image/configs/wofi/config" | \
    ws_pipe "mkdir -p ~/.config/wofi && cat > ~/.config/wofi/config"
cat "${REPO_DIR}/workstation-image/configs/wofi/style.css" | \
    ws_pipe "cat > ~/.config/wofi/style.css"
test_pass "Wofi config deployed"

# Deploy snippet picker
cat "${REPO_DIR}/workstation-image/scripts/snippet-picker" | \
    ws_pipe "mkdir -p ~/.local/bin && cat > ~/.local/bin/snippet-picker && chmod +x ~/.local/bin/snippet-picker"
cat "${REPO_DIR}/workstation-image/configs/snippets/snippets.conf" | \
    ws_pipe "mkdir -p ~/.config/snippets && cat > ~/.config/snippets/snippets.conf"
test_pass "Snippet picker deployed"

# Deploy tmux.conf
cat "${REPO_DIR}/workstation-image/configs/tmux/tmux.conf" | \
    ws_pipe "cat > ~/.tmux.conf"
test_pass "tmux.conf deployed"

# Deploy claude-tmux and tmux-debug scripts
cat "${REPO_DIR}/workstation-image/scripts/claude-tmux" | \
    ws_pipe "mkdir -p ~/.local/bin && cat > ~/.local/bin/claude-tmux && chmod +x ~/.local/bin/claude-tmux"
cat "${REPO_DIR}/workstation-image/scripts/tmux-debug" | \
    ws_pipe "cat > ~/.local/bin/tmux-debug && chmod +x ~/.local/bin/tmux-debug"
test_pass "claude-tmux and tmux-debug deployed"

# =========================================================================
step "Step 14/19: Run initial setup"
# =========================================================================
log "Running setup.sh (fonts, ZSH, Starship, foot)..."
if ! ws_ssh_long "sudo bash /home/user/boot/setup.sh"; then
    test_warn "setup.sh returned non-zero (some steps may have failed)"
fi

# Verify setup results
SETUP_VERIFY=$(ws_ssh '
'"${NIX_SOURCE}"'
echo "fonts=$(fc-list 2>/dev/null | grep -ci "operator mono")"
echo "zshrc=$(test -f ~/.zshrc && echo yes || echo no)"
echo "starship=$(~/.local/bin/starship --version 2>/dev/null | head -1)"
echo "foot=$(test -f ~/.config/foot/foot.ini && echo yes || echo no)"
echo "zsh_plugins=$(test -d ~/.zsh/zsh-syntax-highlighting && echo yes || echo no)"
')

echo "$SETUP_VERIFY" | grep -q "fonts=[1-9]" && test_pass "Operator Mono fonts" || test_warn "Fonts not verified"
echo "$SETUP_VERIFY" | grep -q "zshrc=yes" && test_pass ".zshrc created" || test_warn ".zshrc not verified"
echo "$SETUP_VERIFY" | grep -q "starship" && test_pass "Starship prompt" || test_warn "Starship not verified"
echo "$SETUP_VERIFY" | grep -q "foot=yes" && test_pass "foot.ini config" || test_warn "foot config not verified"
echo "$SETUP_VERIFY" | grep -q "zsh_plugins=yes" && test_pass "ZSH plugins" || test_warn "ZSH plugins not verified"

# =========================================================================
step "Step 15/19: Install language build dependencies"
# =========================================================================
log "Installing apt build dependencies for pyenv/rbenv compilation..."
if ws_ssh "sudo bash /home/user/boot/07a-lang-deps.sh"; then
    test_pass "Language build dependencies installed"
else
    test_fail "Language build dependencies install"
    notify_and_fail "Language build dependencies"
fi

# =========================================================================
step "Step 16/19: Install programming languages (Go, Rust, Python, Ruby)"
# =========================================================================
log "Installing languages (first-time: 10-15 min for Python/Ruby compilation)..."
if ! ws_ssh_long "sudo bash /home/user/boot/07b-languages.sh"; then
    test_warn "Language install script returned non-zero (some languages may have failed)"
fi

# Verify language installations
LANG_VERIFY=$(ws_ssh '
export GOROOT=$HOME/go
export GOPATH=$HOME/gopath
export PATH="$GOROOT/bin:$GOPATH/bin:$HOME/.cargo/bin:$HOME/.pyenv/bin:$HOME/.rbenv/bin:$PATH"
eval "$($HOME/.pyenv/bin/pyenv init -)" 2>/dev/null
eval "$($HOME/.rbenv/bin/rbenv init -)" 2>/dev/null
echo "go=$(go version 2>/dev/null | head -1)"
echo "rust=$(rustc --version 2>/dev/null)"
echo "cargo=$(cargo --version 2>/dev/null)"
echo "python=$(python --version 2>/dev/null)"
echo "ruby=$(ruby --version 2>/dev/null)"
')
echo "$LANG_VERIFY" | grep -q "go=go version" && test_pass "Go installed" || test_warn "Go not verified"
echo "$LANG_VERIFY" | grep -q "rust=rustc" && test_pass "Rust installed" || test_warn "Rust not verified"
echo "$LANG_VERIFY" | grep -q "cargo=cargo" && test_pass "Cargo installed" || test_warn "Cargo not verified"
echo "$LANG_VERIFY" | grep -q "python=Python 3" && test_pass "Python installed" || test_warn "Python not verified"
echo "$LANG_VERIFY" | grep -q "ruby=ruby 3" && test_pass "Ruby installed" || test_warn "Ruby not verified"

notify "Progress: Languages Installed" "Project: ${PROJECT_ID}" "Go, Rust, Python, Ruby installed. Installing AI tools next..."

# =========================================================================
step "Step 17/19: Install AI tools and Antigravity"
# =========================================================================
if ws_ssh_long '
'"${NIX_SOURCE}"'
export NPM_CONFIG_PREFIX=$HOME/.npm-global
mkdir -p $HOME/.npm-global/bin

npm install -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex @sourcegraph/cody @mariozechner/pi-coding-agent
'; then
    test_pass "NPM AI tools installed"
else
    test_warn "NPM AI tools install had errors (some tools may be missing)"
fi

# Antigravity is pre-installed via apt in the Docker image (/usr/bin/antigravity).
# No manual download needed.

# Install OpenCode via go install
if ws_ssh "${NIX_SOURCE}"' && export GOROOT=$HOME/go GOPATH=$HOME/gopath && export PATH=$GOROOT/bin:$GOPATH/bin:$PATH && go install github.com/opencode-ai/opencode@latest'; then
    test_pass "OpenCode installed"
else
    test_warn "OpenCode install failed (may work on next boot via 07-apps.sh)"
fi

# Install aider via pip
if ws_ssh 'export PYENV_ROOT=$HOME/.pyenv && export PATH=$PYENV_ROOT/bin:$PATH && eval "$(pyenv init -)" && pip install --user aider-chat'; then
    test_pass "Aider installed"
else
    test_warn "Aider install failed (may work on next boot via 07-apps.sh)"
fi

# Install gh copilot
if ws_ssh "${NIX_SOURCE}"' && gh extension install github/gh-copilot 2>&1 || gh extension upgrade gh-copilot 2>&1'; then
    test_pass "GitHub Copilot CLI installed"
else
    test_warn "GitHub Copilot CLI install failed (may work on next boot via 07-apps.sh)"
fi

# Create default .env if it doesn't exist (user adds secrets manually)
ws_ssh 'touch $HOME/.env'
test_pass "Default .env created"

AI_VERIFY=$(ws_ssh '
echo "claude=$(~/.npm-global/bin/claude --version 2>/dev/null | head -1)"
echo "gemini=$(~/.npm-global/bin/gemini --version 2>/dev/null | head -1)"
echo "antigravity=$(which antigravity 2>/dev/null && antigravity --version 2>/dev/null | head -1 || echo missing)"
')
echo "$AI_VERIFY" | grep -q "claude=.*Claude" && test_pass "Claude Code" || test_warn "Claude Code not verified"
echo "$AI_VERIFY" | grep -q "gemini=[0-9]" && test_pass "Gemini CLI" || test_warn "Gemini CLI not verified"
echo "$AI_VERIFY" | grep -q "/usr/bin/antigravity" && test_pass "Antigravity" || test_warn "Antigravity not verified"

# =========================================================================
step "Step 18/19: Create Cloud Scheduler (weekday start/stop)"
# =========================================================================
WS_API_BASE="https://workstations.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workstationClusters/${CLUSTER}/workstationConfigs/${CONFIG}/workstations/${WORKSTATION}"

# Remove old daily scheduler if exists
gcloud scheduler jobs delete ws-daily-start \
    --location="$REGION" --project="$PROJECT_ID" --quiet 2>/dev/null || true

# Weekday start: 6AM Mon-Fri Pacific
if gcloud scheduler jobs describe ws-weekday-start \
    --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Weekday start scheduler already exists — skipping"
else
    retry 2 5 gcloud scheduler jobs create http ws-weekday-start \
        --project="$PROJECT_ID" --location="$REGION" \
        --schedule="0 6 * * 1-5" --time-zone="America/Los_Angeles" \
        --uri="${WS_API_BASE}:start" \
        --http-method=POST \
        --oauth-service-account-email="$COMPUTE_SA" \
        --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" || true
fi

# Weekday stop: 9PM Mon-Fri Pacific
if gcloud scheduler jobs describe ws-weekday-stop \
    --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Weekday stop scheduler already exists — skipping"
else
    retry 2 5 gcloud scheduler jobs create http ws-weekday-stop \
        --project="$PROJECT_ID" --location="$REGION" \
        --schedule="0 21 * * 1-5" --time-zone="America/Los_Angeles" \
        --uri="${WS_API_BASE}:stop" \
        --http-method=POST \
        --oauth-service-account-email="$COMPUTE_SA" \
        --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" || true
fi

# Verify both
if gcloud scheduler jobs describe ws-weekday-start \
    --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    test_pass "Cloud Scheduler 'ws-weekday-start' (6AM Mon-Fri)"
else
    test_warn "Weekday start scheduler not verified"
fi
if gcloud scheduler jobs describe ws-weekday-stop \
    --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    test_pass "Cloud Scheduler 'ws-weekday-stop' (9PM Mon-Fri)"
else
    test_warn "Weekday stop scheduler not verified"
fi

# =========================================================================
step "Step 19/19: Verify noVNC desktop access"
# =========================================================================
# The full chain: Sway (compositor) → wayvnc (VNC on :5901) → noVNC (port 80)
# Wait for services to stabilize after boot script setup
log "Waiting for Sway + wayvnc to start (up to 60s)..."
NOVNC_READY=false
for i in $(seq 1 12); do
    VNC_CHECK=$(ws_ssh '
echo "sway=$(pgrep -c sway 2>/dev/null || echo 0)"
echo "wayvnc=$(ss -tlnp 2>/dev/null | grep -c 5901 || echo 0)"
echo "novnc=$(ss -tlnp 2>/dev/null | grep -c ":80 " || echo 0)"
' 2>/dev/null || echo "")
    if echo "$VNC_CHECK" | grep -q "sway=[1-9]" && \
       echo "$VNC_CHECK" | grep -q "wayvnc=[1-9]" && \
       echo "$VNC_CHECK" | grep -q "novnc=[1-9]"; then
        NOVNC_READY=true
        break
    fi
    sleep 5
done

if [ "$NOVNC_READY" = true ]; then
    test_pass "Sway compositor running"
    test_pass "wayvnc listening on port 5901"
    test_pass "noVNC listening on port 80"
else
    # Report individual results
    echo "$VNC_CHECK" | grep -q "sway=[1-9]" && test_pass "Sway compositor running" || test_fail "Sway not running"
    echo "$VNC_CHECK" | grep -q "wayvnc=[1-9]" && test_pass "wayvnc on port 5901" || test_fail "wayvnc not on port 5901"
    echo "$VNC_CHECK" | grep -q "novnc=[1-9]" && test_pass "noVNC on port 80" || test_fail "noVNC not on port 80"
fi

# Test noVNC HTTP response via workstation proxy
WS_HOST=$(gcloud workstations describe "$WORKSTATION" \
    --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
    --project="$PROJECT_ID" --format="value(host)" 2>/dev/null || echo "unknown")

if [ "$WS_HOST" != "unknown" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $(gcloud auth print-access-token 2>/dev/null)" \
        "https://${WS_HOST}" --max-time 10 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
        test_pass "noVNC HTTP accessible (HTTP $HTTP_CODE)"
    else
        test_warn "noVNC HTTP returned $HTTP_CODE (may need browser auth)"
    fi
fi

notify "Progress: noVNC Verified" "Project: ${PROJECT_ID}" \
    "Desktop accessible via noVNC. Stopping workstation to save costs..."

# =========================================================================
# Stop workstation to save costs
# =========================================================================
log "Stopping workstation to save costs..."
gcloud workstations stop "$WORKSTATION" \
    --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
    --project="$PROJECT_ID" 2>/dev/null || true

# =========================================================================
step "SETUP COMPLETE — Test Results"
# =========================================================================
ELAPSED=$(( $(date +%s) - START_TIME ))
MINS=$(( ELAPSED / 60 ))

echo ""
echo "  PASS: $PASS  |  FAIL: $FAIL  |  WARN: $WARN  |  Time: ${MINS}m"
echo ""

# Disable trap before final notification
trap - ERR

if [ "$FAIL" -gt 0 ]; then
    echo "  Some steps failed. Re-run setup.sh to retry (all steps are idempotent)."
    echo ""
    notify "Setup FAILED" "Project: ${PROJECT_ID}" \
        "PASS: ${PASS} | FAIL: <b>${FAIL}</b> | WARN: ${WARN}<br>Duration: ${MINS} minutes<br><br>Some steps failed. Re-run <code>setup.sh</code> to retry (idempotent)."
else
    notify "Setup COMPLETE" "Project: ${PROJECT_ID}" \
        "PASS: ${PASS} | FAIL: ${FAIL} | WARN: ${WARN}<br>Duration: ${MINS} minutes<br><br>Workstation URL: <b>https://${WS_HOST}</b><br><br>Start: <code>gcloud workstations start ${WORKSTATION} --config=${CONFIG} --cluster=${CLUSTER} --region=${REGION} --project=${PROJECT_ID}</code>"
fi

echo "============================================="
echo " Cloud Workstation is ready!"
echo "============================================="
echo ""
echo " URL:   https://${WS_HOST}"
echo ""
echo " Start: gcloud workstations start $WORKSTATION \\"
echo "          --config=$CONFIG --cluster=$CLUSTER \\"
echo "          --region=$REGION --project=$PROJECT_ID"
echo ""
echo " SSH:   gcloud workstations ssh $WORKSTATION \\"
echo "          --config=$CONFIG --cluster=$CLUSTER \\"
echo "          --region=$REGION --project=$PROJECT_ID"
echo ""
echo " Cloud Scheduler auto-starts daily at 7AM Pacific."
echo " Connect via browser at the URL above (noVNC desktop)."
echo ""
echo " Installed: Sway (Tokyo Night), Nix, ZSH, Starship,"
echo "   Operator Mono font, Chrome, VS Code, IntelliJ, Windsurf,"
echo "   Cursor, Zed, Antigravity, Claude Code, Gemini CLI,"
echo "   Codex, Cody, OpenCode, Aider, gh-copilot, pi-coding-agent,"
echo "   Go, Rust (rustup), Python (pyenv), Ruby (rbenv), Node.js (Nix),"
echo "   Wofi app launcher, snippet picker, clipboard manager"
echo "============================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
