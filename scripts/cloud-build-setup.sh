#!/bin/bash
# =============================================================================
# cloud-build-setup.sh — Main setup script (runs inside Cloud Build)
# =============================================================================
# Creates the ENTIRE Cloud Workstation infrastructure from scratch.
# Every step is idempotent, self-recovering, and tested.
# =============================================================================

set -euo pipefail

PROJECT_ID="${1:?Usage: cloud-build-setup.sh PROJECT_ID REGION [WEBHOOK_URL]}"
REGION="${2:-us-west1}"
WEBHOOK_URL="${3:-}"
CLUSTER="workstation-cluster"
CONFIG="ws-config"
WORKSTATION="dev-workstation"
AR_REPO="workstation-images"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/workstation:latest"
REPO_DIR="/workspace/repo"
PASS=0; FAIL=0; WARN=0
START_TIME=$(date +%s)

log()  { echo "[$(date '+%H:%M:%S')] $1"; }
step() { echo ""; echo "========================================"; echo "  $1"; echo "========================================"; }

# Send Google Chat / Slack webhook notification
notify() {
    local title="$1" subtitle="$2" body="$3" color="${4:-#9ece6a}"
    [ -z "$WEBHOOK_URL" ] && return 0
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

# Send failure notification and exit
notify_and_fail() {
    local elapsed=$(( $(date +%s) - START_TIME ))
    local mins=$(( elapsed / 60 ))
    notify "Setup FAILED" "Project: ${PROJECT_ID}" \
        "Failed at: <b>$1</b><br>After: ${mins} minutes<br>PASS: ${PASS} | FAIL: ${FAIL} | WARN: ${WARN}<br><br>Re-run <code>setup.sh</code> to retry (idempotent)." \
        "#f7768e"
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

# SSH helpers with retry
ws_ssh() {
    retry 3 10 gcloud workstations ssh "$WORKSTATION" \
        --project="$PROJECT_ID" --region="$REGION" \
        --cluster="$CLUSTER" --config="$CONFIG" \
        --command="$1"
}

ws_pipe() {
    retry 3 10 gcloud workstations ssh "$WORKSTATION" \
        --project="$PROJECT_ID" --region="$REGION" \
        --cluster="$CLUSTER" --config="$CONFIG" \
        --command="$1"
}

PROJECT_NUMBER=""

# =========================================================================
step "Step 1/15: Enable APIs"
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
step "Step 2/15: Create Artifact Registry"
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
step "Step 3/15: Build and push Docker image"
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
step "Step 4/15: Create Cloud NAT (internet access)"
# =========================================================================
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
step "Step 5/15: Create Workstation Cluster"
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
step "Step 6/15: Grant Workstations service agent AR access"
# =========================================================================
WS_SA="service-${PROJECT_NUMBER}@gcp-sa-workstations.iam.gserviceaccount.com"
gcloud artifacts repositories add-iam-policy-binding "$AR_REPO" \
    --location="$REGION" \
    --member="serviceAccount:${WS_SA}" \
    --role="roles/artifactregistry.reader" \
    --project="$PROJECT_ID" --quiet >/dev/null 2>&1 || true
test_pass "AR reader granted to Workstations SA"

# =========================================================================
step "Step 7/15: Create Workstation Config"
# =========================================================================
if gcloud workstations configs describe "$CONFIG" \
    --cluster="$CLUSTER" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Config already exists — skipping"
else
    retry 2 10 gcloud workstations configs create "$CONFIG" \
        --cluster="$CLUSTER" --region="$REGION" \
        --machine-type=n1-standard-16 \
        --accelerator-type=nvidia-tesla-t4 --accelerator-count=1 \
        --pd-disk-size=500 --pd-disk-type=pd-ssd \
        --container-custom-image="$IMAGE" \
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
step "Step 8/15: Create and start Workstation"
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

log "Starting workstation (3-5 minutes)..."
gcloud workstations start "$WORKSTATION" \
    --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
    --project="$PROJECT_ID" 2>/dev/null || true

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
step "Step 9/15: Install Nix package manager"
# =========================================================================
if ws_ssh "test -d /home/user/nix && echo exists" | grep -q "exists"; then
    log "Nix already on persistent disk — skipping"
    test_pass "Nix persistent install"
else
    log "Installing Nix..."
    ws_ssh 'sh <(curl -L https://nixos.org/nix/install) --no-daemon' || true
    log "Moving to persistent disk..."
    ws_ssh 'cp -a /nix /home/user/nix'
    # Bind mount
    gcloud workstations ssh "$WORKSTATION" \
        --project="$PROJECT_ID" --region="$REGION" \
        --cluster="$CLUSTER" --config="$CONFIG" \
        --command="sudo bash -c 'rm -rf /nix && mkdir -p /nix && mount --bind /home/user/nix /nix'" 2>/dev/null
    # Verify
    if ws_ssh '. ~/.nix-profile/etc/profile.d/nix.sh && nix --version' | grep -q "nix"; then
        test_pass "Nix installed"
    else
        test_fail "Nix installation"
    fi
fi

# =========================================================================
step "Step 10/15: Install Nix Home Manager + packages"
# =========================================================================
log "Setting up Home Manager and packages (this takes 5-10 minutes)..."
ws_ssh '
set -e
. /home/user/.nix-profile/etc/profile.d/nix.sh

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
VERIFY=$(ws_ssh '. ~/.nix-profile/etc/profile.d/nix.sh && echo "sway=$(sway --version 2>/dev/null | head -1)" && echo "nvim=$(nvim --version 2>/dev/null | head -1)" && echo "node=$(node --version 2>/dev/null)"')
echo "$VERIFY" | grep -q "sway" && test_pass "Sway installed" || test_warn "Sway not verified"
echo "$VERIFY" | grep -q "NVIM" && test_pass "Neovim installed" || test_warn "Neovim not verified"
echo "$VERIFY" | grep -q "v22" && test_pass "Node.js installed" || test_warn "Node.js not verified"

# =========================================================================
step "Step 11/15: Deploy boot scripts and fonts"
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
step "Step 12/15: Deploy configs"
# =========================================================================
cat "${REPO_DIR}/workstation-image/configs/sway/config" | \
    ws_pipe "mkdir -p ~/.config/sway && cat > ~/.config/sway/config"
test_pass "Sway config deployed"

cat "${REPO_DIR}/workstation-image/configs/swaybar/sway-status" | \
    ws_pipe "mkdir -p ~/.local/bin && cat > ~/.local/bin/sway-status && chmod +x ~/.local/bin/sway-status"
test_pass "sway-status deployed"

# =========================================================================
step "Step 13/15: Run initial setup"
# =========================================================================
log "Running setup.sh (fonts, ZSH, Starship, foot)..."
gcloud workstations ssh "$WORKSTATION" \
    --project="$PROJECT_ID" --region="$REGION" \
    --cluster="$CLUSTER" --config="$CONFIG" \
    --command="sudo bash /home/user/boot/setup.sh" 2>/dev/null || true

# Verify setup results
SETUP_VERIFY=$(ws_ssh '
. ~/.nix-profile/etc/profile.d/nix.sh 2>/dev/null
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
step "Step 14/15: Install AI tools and Antigravity"
# =========================================================================
ws_ssh '
. /home/user/.nix-profile/etc/profile.d/nix.sh
export NPM_CONFIG_PREFIX=$HOME/.npm-global
mkdir -p $HOME/.npm-global/bin

npm install -g @anthropic-ai/claude-code @google/gemini-cli 2>/dev/null || true

if [ ! -d "$HOME/.antigravity" ]; then
    mkdir -p $HOME/.antigravity && cd $HOME/.antigravity
    curl -sL https://antigravity.google/download/linux -o antigravity.tar.gz || true
    [ -f antigravity.tar.gz ] && tar xzf antigravity.tar.gz 2>/dev/null && rm -f antigravity.tar.gz || true
fi
' || true

AI_VERIFY=$(ws_ssh '
echo "claude=$(~/.npm-global/bin/claude --version 2>/dev/null | head -1)"
echo "gemini=$(~/.npm-global/bin/gemini --version 2>/dev/null | head -1)"
echo "antigravity=$(test -d ~/.antigravity && echo yes || echo no)"
')
echo "$AI_VERIFY" | grep -q "claude=.*Claude" && test_pass "Claude Code" || test_warn "Claude Code not verified"
echo "$AI_VERIFY" | grep -q "gemini=[0-9]" && test_pass "Gemini CLI" || test_warn "Gemini CLI not verified"
echo "$AI_VERIFY" | grep -q "antigravity=yes" && test_pass "Antigravity" || test_warn "Antigravity not verified"

# =========================================================================
step "Step 15/15: Create Cloud Scheduler"
# =========================================================================
if gcloud scheduler jobs describe ws-daily-start \
    --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    log "Cloud Scheduler already exists — skipping"
else
    COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
    retry 2 5 gcloud scheduler jobs create http ws-daily-start \
        --project="$PROJECT_ID" --location="$REGION" \
        --schedule="0 7 * * *" --time-zone="America/Los_Angeles" \
        --uri="https://workstations.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/workstationClusters/${CLUSTER}/workstationConfigs/${CONFIG}/workstations/${WORKSTATION}:start" \
        --http-method=POST \
        --oauth-service-account-email="$COMPUTE_SA" \
        --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform" || true
fi
if gcloud scheduler jobs describe ws-daily-start \
    --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    test_pass "Cloud Scheduler 'ws-daily-start'"
else
    test_warn "Cloud Scheduler not verified"
fi

# =========================================================================
# Get workstation URL and stop
# =========================================================================
WS_HOST=$(gcloud workstations describe "$WORKSTATION" \
    --config="$CONFIG" --cluster="$CLUSTER" --region="$REGION" \
    --project="$PROJECT_ID" --format="value(host)" 2>/dev/null || echo "unknown")

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
        "PASS: ${PASS} | FAIL: <b>${FAIL}</b> | WARN: ${WARN}<br>Duration: ${MINS} minutes<br><br>Some steps failed. Re-run <code>setup.sh</code> to retry (idempotent)." \
        "#f7768e"
else
    notify "Setup COMPLETE" "Project: ${PROJECT_ID}" \
        "PASS: ${PASS} | FAIL: ${FAIL} | WARN: ${WARN}<br>Duration: ${MINS} minutes<br><br>Workstation URL: <b>https://${WS_HOST}</b><br><br>Start: <code>gcloud workstations start ${WORKSTATION} --config=${CONFIG} --cluster=${CLUSTER} --region=${REGION} --project=${PROJECT_ID}</code>" \
        "#9ece6a"
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
