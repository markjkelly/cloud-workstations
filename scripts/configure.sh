#!/usr/bin/env bash
# configure.sh — Onboarding script for personalizing this repo with your GCP project details.
# Run this after cloning to replace all template placeholders with your values.
# Safe to run multiple times (idempotent).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── Colors ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# ─── Welcome banner ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║          Cloud Workstation — Configure Your Repo           ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "This script replaces template placeholders across all config files"
echo -e "with your personal GCP project details, name, and email."
echo ""
echo -e "${YELLOW}You'll be prompted for 7 values. Press Ctrl+C to cancel at any time.${RESET}"
echo ""

# ─── Prompt helper ────────────────────────────────────────────────────────────
prompt_value() {
    local var_name="$1"
    local description="$2"
    local example="$3"
    local value=""

    while [[ -z "$value" ]]; do
        echo -e "${CYAN}${description}${RESET}"
        read -rp "  ${var_name} (e.g., ${example}): " value
        if [[ -z "$value" ]]; then
            echo -e "  ${RED}Value cannot be empty. Please try again.${RESET}"
        fi
    done
    echo ""
    echo "$value"
}

# ─── Collect inputs ──────────────────────────────────────────────────────────
echo -e "${BOLD}── Step 1: Enter your details ──${RESET}"
echo ""

GCP_PROJECT_ID=$(prompt_value \
    "GCP_PROJECT_ID" \
    "Your GCP project ID" \
    "my-project-123" | tail -1)

GCP_PROJECT_NUMBER=$(prompt_value \
    "GCP_PROJECT_NUMBER" \
    "Your GCP project number (find in Cloud Console > Dashboard)" \
    "123456789012" | tail -1)

GCP_ORG_DOMAIN=$(prompt_value \
    "GCP_ORG_DOMAIN" \
    "Your GCP organization domain" \
    "company.com" | tail -1)

GCP_ADMIN_EMAIL=$(prompt_value \
    "GCP_ADMIN_EMAIL" \
    "Your GCP admin email" \
    "admin@company.com" | tail -1)

OWNER_NAME=$(prompt_value \
    "OWNER_NAME" \
    "Your full name (for git commits)" \
    "Jane Doe" | tail -1)

OWNER_EMAIL=$(prompt_value \
    "OWNER_EMAIL" \
    "Your email (for git commits and notifications)" \
    "jane@example.com" | tail -1)

GITHUB_USERNAME=$(prompt_value \
    "GITHUB_USERNAME" \
    "Your GitHub username" \
    "janedoe" | tail -1)

# ─── Confirmation ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Step 2: Confirm your settings ──${RESET}"
echo ""
echo -e "  GCP Project ID:      ${GREEN}${GCP_PROJECT_ID}${RESET}"
echo -e "  GCP Project Number:  ${GREEN}${GCP_PROJECT_NUMBER}${RESET}"
echo -e "  GCP Org Domain:      ${GREEN}${GCP_ORG_DOMAIN}${RESET}"
echo -e "  GCP Admin Email:     ${GREEN}${GCP_ADMIN_EMAIL}${RESET}"
echo -e "  Owner Name:          ${GREEN}${OWNER_NAME}${RESET}"
echo -e "  Owner Email:         ${GREEN}${OWNER_EMAIL}${RESET}"
echo -e "  GitHub Username:     ${GREEN}${GITHUB_USERNAME}${RESET}"
echo -e "  Service Account:     ${GREEN}owner-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com${RESET}"
echo ""

read -rp "Apply these settings? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${YELLOW}Cancelled. No files were modified.${RESET}"
    exit 0
fi

# ─── Build sed command safely ────────────────────────────────────────────────
# Escape sed special characters in user inputs
escape_sed() {
    printf '%s' "$1" | sed 's/[&/\]/\\&/g'
}

E_PROJECT_ID=$(escape_sed "$GCP_PROJECT_ID")
E_PROJECT_NUMBER=$(escape_sed "$GCP_PROJECT_NUMBER")
E_ORG_DOMAIN=$(escape_sed "$GCP_ORG_DOMAIN")
E_ADMIN_EMAIL=$(escape_sed "$GCP_ADMIN_EMAIL")
E_OWNER_NAME=$(escape_sed "$OWNER_NAME")
E_OWNER_EMAIL=$(escape_sed "$OWNER_EMAIL")
E_GITHUB_USERNAME=$(escape_sed "$GITHUB_USERNAME")

# ─── Find target files ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Step 3: Applying replacements ──${RESET}"
echo ""

# Collect all text files that may contain placeholders
# Skip binary files, .git directory, and this script itself
TARGET_FILES=()
while IFS= read -r -d '' file; do
    # Skip binary files (fonts, images, etc.)
    if file --mime-type "$file" 2>/dev/null | grep -qE 'text/|application/json|application/javascript'; then
        TARGET_FILES+=("$file")
    fi
done < <(find "$REPO_ROOT" \
    -type f \
    -not -path "$REPO_ROOT/.git/*" \
    -not -path "$REPO_ROOT/scripts/configure.sh" \
    -not -name "*.woff" \
    -not -name "*.woff2" \
    -not -name "*.ttf" \
    -not -name "*.otf" \
    -not -name "*.png" \
    -not -name "*.jpg" \
    -not -name "*.jpeg" \
    -not -name "*.gif" \
    -not -name "*.ico" \
    -not -name "*.svg" \
    -not -name "*.zip" \
    -not -name "*.tar.gz" \
    -not -name "*.pdf" \
    -not -name "*-sa-key.json" \
    -print0)

updated_count=0

for file in "${TARGET_FILES[@]}"; do
    changed=false

    # Check if file contains any placeholder before modifying
    if grep -q "YOUR_PROJECT_ID\|YOUR_PROJECT_NUMBER\|your-org\.example\.com\|admin@your-org\.example\.com\|your-email@example\.com\|Your Name\|your-github-username" "$file" 2>/dev/null; then

        # Apply all replacements
        # Order matters: do the more specific patterns first to avoid partial matches

        # Service account email (must be before generic PROJECT_ID replacement)
        sed -i "s/owner-sa@YOUR_PROJECT_ID\.iam\.gserviceaccount\.com/owner-sa@${E_PROJECT_ID}.iam.gserviceaccount.com/g" "$file"

        # Admin email (must be before generic org domain replacement)
        sed -i "s/admin@your-org\.example\.com/${E_ADMIN_EMAIL}/g" "$file"

        # GCP org domain
        sed -i "s/your-org\.example\.com/${E_ORG_DOMAIN}/g" "$file"

        # Project number
        sed -i "s/YOUR_PROJECT_NUMBER/${E_PROJECT_NUMBER}/g" "$file"

        # Project ID (after service account to avoid double-replacement)
        sed -i "s/YOUR_PROJECT_ID/${E_PROJECT_ID}/g" "$file"

        # GitHub username (in URLs and references)
        sed -i "s/your-github-username/${E_GITHUB_USERNAME}/g" "$file"

        # Owner email
        sed -i "s/your-email@example\.com/${E_OWNER_EMAIL}/g" "$file"

        # Owner name — use word boundaries to avoid replacing partial matches
        # but allow it in contexts like git config and attribution
        sed -i "s/Your Name/${E_OWNER_NAME}/g" "$file"

        changed=true
    fi

    if [[ "$changed" == "true" ]]; then
        rel_path="${file#"$REPO_ROOT"/}"
        echo -e "  ${GREEN}Updated${RESET} ${rel_path}"
        ((updated_count++))
    fi
done

# ─── Completion summary ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║                    Configuration Complete                   ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${GREEN}${updated_count} file(s) updated${RESET} with your project settings."
echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo ""
echo -e "  1. Run the workstation setup:"
echo -e "     ${CYAN}bash scripts/ws.sh setup -p ${GCP_PROJECT_ID}${RESET}"
echo ""
echo -e "  2. If using Claude Code with Vertex AI, set these in ${CYAN}~/.env${RESET}:"
echo -e "     ${CYAN}CLAUDE_CODE_USE_VERTEX=1${RESET}"
echo -e "     ${CYAN}CLOUD_ML_REGION=us-east5${RESET}"
echo -e "     ${CYAN}ANTHROPIC_VERTEX_PROJECT_ID=${GCP_PROJECT_ID}${RESET}"
echo ""
echo -e "  3. Commit the configured files:"
echo -e "     ${CYAN}git add -A && git commit -m \"Configure repo for ${GCP_PROJECT_ID}\"${RESET}"
echo ""
