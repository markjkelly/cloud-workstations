#!/bin/bash
# =============================================================================
# Cloud Workstation — One-Click Setup
# =============================================================================
# Sets up a complete GPU Cloud Workstation in any GCP project.
# All heavy work runs in Cloud Build (persistent, survives terminal close).
#
# Usage:
#   gcloud auth login
#   bash setup.sh -p PROJECT_ID [--webhook WEBHOOK_URL]
#
# Requirements:
#   - gcloud CLI authenticated with Owner role on the target project
#   - NVIDIA T4 GPU quota in us-west1 (at least 1)
# =============================================================================

set -euo pipefail

REGION="us-west1"
REPO_URL="https://github.com/ameer00/cloud-workstations.git"

# --- Parse arguments ---
usage() {
    echo "Usage: bash setup.sh -p PROJECT_ID [--webhook URL]"
    echo ""
    echo "Sets up a GPU Cloud Workstation with Sway, Nix, and dev tools."
    echo "All work runs in Cloud Build (safe to close terminal after launch)."
    echo ""
    echo "Required:"
    echo "  -p, --project PROJECT_ID    GCP project ID"
    echo ""
    echo "Optional:"
    echo "  -w, --webhook URL           Google Chat or Slack webhook URL for notifications"
    echo ""
    echo "Prerequisites:"
    echo "  1. gcloud auth login"
    echo "  2. Owner role on the target project"
    echo "  3. NVIDIA T4 GPU quota in us-west1"
    exit 1
}

PROJECT_ID=""
WEBHOOK_URL=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project) PROJECT_ID="$2"; shift 2 ;;
        -w|--webhook) WEBHOOK_URL="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: --project is required"
    usage
fi

echo "============================================="
echo " Cloud Workstation Setup"
echo " Project:  $PROJECT_ID"
echo " Region:   $REGION"
[ -n "$WEBHOOK_URL" ] && echo " Webhook:  configured (notifications enabled)"
echo "============================================="

# --- Pre-flight: validate gcloud auth ---
echo ""
echo "[1/5] Validating authentication..."
ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null || true)
if [ -z "$ACCOUNT" ]; then
    echo "ERROR: No active gcloud account. Run: gcloud auth login"
    exit 1
fi
echo "  Authenticated as: $ACCOUNT"

# --- Pre-flight: validate project exists ---
echo "[2/5] Validating project..."
if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    echo "ERROR: Project '$PROJECT_ID' not found or you don't have access."
    exit 1
fi
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
echo "  Project number: $PROJECT_NUMBER"

# --- Enable Cloud Build API (needed to submit the build) ---
echo "[3/5] Enabling Cloud Build API..."
gcloud services enable cloudbuild.googleapis.com --project="$PROJECT_ID" --quiet 2>/dev/null

# --- Grant Cloud Build SA the Owner role ---
echo "[4/5] Granting Cloud Build service account Owner role..."
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
if gcloud projects get-iam-policy "$PROJECT_ID" --format=json 2>/dev/null | \
   grep -q "$CB_SA"; then
    echo "  Cloud Build SA already has project-level bindings"
else
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${CB_SA}" \
        --role="roles/owner" \
        --quiet >/dev/null 2>&1
    echo "  Granted Owner role to $CB_SA"
fi

# --- Submit Cloud Build job ---
echo "[5/5] Submitting Cloud Build job..."
echo ""
echo "  This will:"
echo "    - Clone the repo from GitHub"
echo "    - Enable all required APIs"
echo "    - Create Artifact Registry, Docker image"
echo "    - Create Cloud Workstation cluster + config + workstation"
echo "    - Install Nix, fonts, ZSH, Starship, dev tools"
echo "    - Create Cloud Scheduler (7AM PT daily start)"
echo ""
echo "  You can safely close this terminal after submission."
echo ""

# Build substitutions
SUBS="_REPO_URL=${REPO_URL},_REGION=${REGION}"
[ -n "$WEBHOOK_URL" ] && SUBS="${SUBS},_WEBHOOK_URL=${WEBHOOK_URL}"

# Create a temporary cloudbuild.yaml
TMPDIR=$(mktemp -d)
cat > "${TMPDIR}/cloudbuild.yaml" << 'BUILDEOF'
steps:
  # Step 0: Clone the repository
  - name: 'gcr.io/cloud-builders/git'
    args: ['clone', '${_REPO_URL}', '/workspace/repo']
    id: 'clone-repo'

  # Step 1: Run the main setup
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        cd /workspace/repo
        bash scripts/cloud-build-setup.sh "${PROJECT_ID}" "${_REGION}" "${_WEBHOOK_URL}"
    id: 'run-setup'
    waitFor: ['clone-repo']

timeout: 7200s
substitutions:
  _REPO_URL: 'https://github.com/ameer00/cloud-workstations.git'
  _REGION: 'us-west1'
  _WEBHOOK_URL: ''
options:
  logging: CLOUD_LOGGING_ONLY
  machineType: 'E2_HIGHCPU_8'
BUILDEOF

BUILD_OUTPUT=$(gcloud builds submit \
    --config="${TMPDIR}/cloudbuild.yaml" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --no-source \
    --substitutions="${SUBS}" \
    --async 2>&1)

rm -rf "$TMPDIR"

BUILD_ID=$(echo "$BUILD_OUTPUT" | grep -oP 'builds/\K[a-f0-9-]+' | head -1)

if [ -z "$BUILD_ID" ]; then
    echo "ERROR: Failed to submit build. Output:"
    echo "$BUILD_OUTPUT"
    exit 1
fi

# Send webhook notification that build started
if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST "$WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "{
            \"cards\": [{
                \"header\": {
                    \"title\": \"Cloud Workstation Setup Started\",
                    \"subtitle\": \"Project: ${PROJECT_ID}\"
                },
                \"sections\": [{
                    \"widgets\": [
                        {\"textParagraph\": {\"text\": \"Build ID: <b>${BUILD_ID}</b>\"}},
                        {\"textParagraph\": {\"text\": \"You'll receive a notification when it completes.\"}},
                        {\"buttons\": [{\"textButton\": {\"text\": \"VIEW BUILD\", \"onClick\": {\"openLink\": {\"url\": \"https://console.cloud.google.com/cloud-build/builds;region=${REGION}/${BUILD_ID}?project=${PROJECT_ID}\"}}}}]}
                    ]
                }]
            }]
        }" >/dev/null 2>&1
    echo "  Notification sent to webhook"
fi

echo "============================================="
echo " Build submitted successfully!"
echo "============================================="
echo ""
echo " Build ID: $BUILD_ID"
echo ""
echo " Track progress:"
echo "   Console: https://console.cloud.google.com/cloud-build/builds;region=${REGION}/${BUILD_ID}?project=${PROJECT_ID}"
echo ""
echo "   CLI:     gcloud builds log ${BUILD_ID} --stream --project=${PROJECT_ID} --region=${REGION}"
echo ""
[ -n "$WEBHOOK_URL" ] && echo " Notifications: You'll receive a Google Chat message when the build completes."
echo ""
echo " You can safely close this terminal now."
echo " The build will continue running in Cloud Build."
echo "============================================="
