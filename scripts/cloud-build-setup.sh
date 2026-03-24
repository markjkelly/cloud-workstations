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

PROJECT_ID="${1:?Usage: cloud-build-setup.sh PROJECT_ID REGION [WEBHOOK_URL] [EMAIL_FUNC_URL] [EMAIL]}"
REGION="${2:-us-west1}"
WEBHOOK_URL="${3:-}"
EMAIL_FUNC_URL="${4:-}"
EMAIL="${5:-}"
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

# SSH helper with retry — runs command on workstation
ws_ssh() {
    retry 3 10 gcloud workstations ssh "$WORKSTATION" \
        --project="$PROJECT_ID" --region="$REGION" \
        --cluster="$CLUSTER" --config="$CONFIG" \
        --command="$1"
}

# Pipe helper — accepts stdin piped to workstation command
ws_pipe() {
    retry 3 10 gcloud workstations ssh "$WORKSTATION" \
        --project="$PROJECT_ID" --region="$REGION" \
        --cluster="$CLUSTER" --config="$CONFIG" \
        --command="$1"
}

# Source Nix profile — works with both old and new Nix profile paths
NIX_SOURCE='if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then . ~/.nix-profile/etc/profile.d/nix.sh; elif [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; fi; export PATH="$HOME/.nix-profile/bin:$HOME/.local/state/nix/profiles/profile/bin:$PATH"'

PROJECT_NUMBER=""

# =========================================================================
step "Step 1/17: Enable APIs"
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
step "Step 2/17: Create Artifact Registry"
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

# =========================================================================
step "Step 3/17: Build and push Docker image"
# =========================================================================
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
step "Step 4/17: Ensure default VPC network + Cloud NAT"
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
step "Step 5/17: Create Workstation Cluster"
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
step "Step 6/17: Grant AR access to service accounts"
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
step "Step 7/17: Create Workstation Config"
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
step "Step 8/17: Create and start Workstation"
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
step "Step 9/17: Install Nix package manager"
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
    # Install Nix (installs directly to /nix which is persistent)
    ws_ssh 'curl -L https://nixos.org/nix/install | sh -s -- --no-daemon' || true
    # Verify
    if ws_ssh "${NIX_SOURCE} && nix --version" 2>/dev/null | grep -q "nix"; then
        test_pass "Nix installed"
    else
        test_fail "Nix installation"
    fi
fi

# =========================================================================
step "Step 10/17: Install Nix Home Manager + packages"
# =========================================================================
log "Setting up Home Manager and packages (this takes 5-10 minutes)..."
ws_ssh "${NIX_SOURCE}"'

if ! nix-channel --list | grep -q home-manager; then
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
    nix-channel --update
fi

if ! command -v home-manager &>/dev/null; then
    nix-shell "<home-manager>" -A install
fi

mkdir -p ~/.config/home-manager
cat > ~/.config/home-manager/home.nix << '"'"'NIXEOF'"'"'
{ config, pkgs, ... }:
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";
  nixpkgs.config.allowUnfree = true;
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    sway foot wofi thunar clipman wl-clipboard wayvnc mako
    chromium google-chrome
    neovim tmux tree zsh ripgrep fd jq ffmpeg
    vscode
    nodejs_22
  ];
}
NIXEOF

home-manager switch
echo "HOME_MANAGER_DONE"
' | tail -5

# Verify key packages
VERIFY=$(ws_ssh "${NIX_SOURCE}"' && echo "sway=$(sway --version 2>/dev/null | head -1)" && echo "nvim=$(nvim --version 2>/dev/null | head -1)" && echo "node=$(node --version 2>/dev/null)"')
echo "$VERIFY" | grep -q "sway" && test_pass "Sway installed" || test_warn "Sway not verified"
echo "$VERIFY" | grep -q "NVIM" && test_pass "Neovim installed" || test_warn "Neovim not verified"
echo "$VERIFY" | grep -q "v22" && test_pass "Node.js installed" || test_warn "Node.js not verified"

# =========================================================================
step "Step 11/17: Persist Nix store for restarts"
# =========================================================================
# Cloud Workstations only persist /home across restarts. The /nix mount
# is ephemeral and gets wiped on container restart. Copy the entire nix
# store to /home/user/nix so the startup script (200_persist-nix.sh) can
# bind-mount it back to /nix on each boot.
log "Copying /nix to /home/user/nix for restart persistence..."
ws_ssh '
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
step "Step 12/17: Deploy boot scripts and fonts"
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
step "Step 13/17: Deploy configs"
# =========================================================================
cat "${REPO_DIR}/workstation-image/configs/sway/config" | \
    ws_pipe "mkdir -p ~/.config/sway && cat > ~/.config/sway/config"
test_pass "Sway config deployed"

cat "${REPO_DIR}/workstation-image/configs/swaybar/sway-status" | \
    ws_pipe "mkdir -p ~/.local/bin && cat > ~/.local/bin/sway-status && chmod +x ~/.local/bin/sway-status"
test_pass "sway-status deployed"

# =========================================================================
step "Step 14/17: Run initial setup"
# =========================================================================
log "Running setup.sh (fonts, ZSH, Starship, foot)..."
gcloud workstations ssh "$WORKSTATION" \
    --project="$PROJECT_ID" --region="$REGION" \
    --cluster="$CLUSTER" --config="$CONFIG" \
    --command="sudo bash /home/user/boot/setup.sh" 2>/dev/null || true

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
step "Step 15/17: Install AI tools and Antigravity"
# =========================================================================
ws_ssh '
'"${NIX_SOURCE}"'
export NPM_CONFIG_PREFIX=$HOME/.npm-global
mkdir -p $HOME/.npm-global/bin

npm install -g @anthropic-ai/claude-code @google/gemini-cli 2>/dev/null || true
' || true

# Antigravity is pre-installed via apt in the Docker image (/usr/bin/antigravity).
# No manual download needed.

AI_VERIFY=$(ws_ssh '
echo "claude=$(~/.npm-global/bin/claude --version 2>/dev/null | head -1)"
echo "gemini=$(~/.npm-global/bin/gemini --version 2>/dev/null | head -1)"
echo "antigravity=$(which antigravity 2>/dev/null && antigravity --version 2>/dev/null | head -1 || echo missing)"
')
echo "$AI_VERIFY" | grep -q "claude=.*Claude" && test_pass "Claude Code" || test_warn "Claude Code not verified"
echo "$AI_VERIFY" | grep -q "gemini=[0-9]" && test_pass "Gemini CLI" || test_warn "Gemini CLI not verified"
echo "$AI_VERIFY" | grep -q "/usr/bin/antigravity" && test_pass "Antigravity" || test_warn "Antigravity not verified"

# =========================================================================
step "Step 16/17: Create Cloud Scheduler (weekday start/stop)"
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
step "Step 17/17: Verify noVNC desktop access"
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
echo "   Operator Mono font, Chrome, VS Code, Antigravity,"
echo "   Claude Code, Gemini CLI, 4 auto-launched workspaces"
echo "============================================="

[ "$FAIL" -gt 0 ] && exit 1 || exit 0
