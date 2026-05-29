#!/bin/bash
# =============================================================================
# 07-apps.sh — Update apps to latest versions on boot
# =============================================================================
# Updates Claude Code, Gemini CLI (npm), Nix apps (home-manager),
# Antigravity IDE, Antigravity Hub, and Antigravity CLI.
# Logs to ~/logs/app-update.log.
# =============================================================================

USER="user"
HOME_DIR="/home/user"
LOG_DIR="$HOME_DIR/logs"
LOG_FILE="$LOG_DIR/app-update.log"
NIX_SH="$HOME_DIR/.nix-profile/etc/profile.d/nix.sh"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [07-apps] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

# Create log directory
runuser -u $USER -- mkdir -p "$LOG_DIR"

log "=== App update started ==="

# --- Upgrade Antigravity apt package ---
log "Upgrading Antigravity apt package..."
sudo apt-get update -qq >> "$LOG_FILE" 2>&1
sudo apt-get install -y --only-upgrade antigravity >> "$LOG_FILE" 2>&1
log "Antigravity apt upgrade done"

# --- Install/update Antigravity 2.0 Desktop App (Hub) ---
# NOTE: URL version 2.0.10-5119448496078848 is hardcoded. Update this URL when a
# new version of antigravity-hub is released.
log "Installing/updating Antigravity 2.0 Desktop App (Hub)..."
HUB_INSTALL_DIR="$HOME_DIR/.local/share/antigravity-hub"
HUB_BIN_DIR="$HUB_INSTALL_DIR"
HUB_SYMLINK="$HOME_DIR/.local/bin/antigravity-hub"
HUB_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.0.10-5119448496078848/linux-x64/Antigravity.tar.gz"
HUB_TEMP="/tmp/antigravity-hub-download.tar.gz"

if [ ! -d "$HUB_INSTALL_DIR" ]; then
    log "Antigravity Hub not found — downloading and extracting..."
    runuser -u $USER -- mkdir -p "$HOME_DIR/.local/share" "$HOME_DIR/.local/bin"
    if runuser -u $USER -- curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 30 -o "$HUB_TEMP" "$HUB_URL" >> "$LOG_FILE" 2>&1; then
        if runuser -u $USER -- tar -xzf "$HUB_TEMP" -C "$HOME_DIR/.local/share/" >> "$LOG_FILE" 2>&1; then
            # tar.gz extracts to Antigravity-x64/ — rename to standard install dir
            runuser -u $USER -- mv "$HOME_DIR/.local/share/Antigravity-x64" "$HUB_INSTALL_DIR" 2>/dev/null || true
            # Binary is named 'antigravity' inside the extracted directory
            runuser -u $USER -- ln -sf "$HUB_INSTALL_DIR/antigravity" "$HUB_SYMLINK"
            rm -f "$HUB_TEMP"
            log "Antigravity Hub downloaded, extracted, and symlinked"
        else
            log "Antigravity Hub extraction failed"
            rm -f "$HUB_TEMP"
        fi
    else
        log "Antigravity Hub download failed"
        rm -f "$HUB_TEMP"
    fi
else
    log "Antigravity Hub already installed at $HUB_INSTALL_DIR"
fi

# --- Update npm global packages (Claude Code, Gemini CLI) ---
log "Updating npm global packages..."
runuser -u $USER -- bash -c ". $NIX_SH && export NPM_CONFIG_PREFIX=$HOME_DIR/.npm-global && npm update -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex @sourcegraph/cody @mariozechner/pi-coding-agent" >> "$LOG_FILE" 2>&1
log "npm update complete"

# --- Install/update Antigravity CLI ---
log "Installing/updating Antigravity CLI..."
if [ ! -d "$HOME_DIR/.gemini/antigravity-cli" ]; then
    log "Antigravity CLI not initialized — installing..."
    runuser -u $USER -- bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash" >> "$LOG_FILE" 2>&1
    log "Antigravity CLI installed"
else
    log "Antigravity CLI found — updating..."
    runuser -u $USER -- bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash" >> "$LOG_FILE" 2>&1
    log "Antigravity CLI updated"
fi

# --- Install/update GitHub Copilot CLI extension ---
log "Updating GitHub Copilot CLI..."
runuser -u $USER -- bash -c ". $NIX_SH && gh extension install github/gh-copilot 2>/dev/null || gh extension upgrade gh-copilot" >> "$LOG_FILE" 2>&1
log "GitHub Copilot CLI update complete"

# --- Update OpenCode (Go binary) ---
log "Updating OpenCode..."
runuser -u $USER -- bash -c "export GOROOT=$HOME_DIR/go && export GOPATH=$HOME_DIR/gopath && export PATH=\$GOROOT/bin:\$GOPATH/bin:\$PATH && go install github.com/opencode-ai/opencode@latest" >> "$LOG_FILE" 2>&1
log "OpenCode update complete"

# --- Update Nix channel + Home Manager (VSCode, IntelliJ, etc.) ---
log "Updating Nix channel and Home Manager..."
runuser -u $USER -- bash -c ". $NIX_SH && nix-channel --update && home-manager switch" >> "$LOG_FILE" 2>&1
log "Nix/Home Manager update complete"

log "=== App update complete ==="
