#!/bin/bash
# =============================================================================
# 12-crd.sh — Install and configure Chrome Remote Desktop
# =============================================================================
# Idempotent — safe to run on every boot or manually.
# Installs chrome-remote-desktop live if missing (for current session),
# configures the Sway session, and deploys the setup helper script.
# =============================================================================

set -euo pipefail

USER="user"
HOME_DIR="/home/user"
LOG_DIR="$HOME_DIR/logs"
LOG_FILE="$LOG_DIR/crd-setup.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [12-crd] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

mkdir -p "$LOG_DIR"
chown -R "$USER:$USER" "$LOG_DIR"

log "=== Chrome Remote Desktop setup started ==="

# =============================================================================
# 1. Install chrome-remote-desktop (Live Install check)
# =============================================================================
if ! command -v chrome-remote-desktop &>/dev/null && [ ! -f /opt/google/chrome-remote-desktop/chrome-remote-desktop ]; then
    log "chrome-remote-desktop not found — downloading and installing deb package..."
    tmp=$(mktemp -d)
    wget -q -O "${tmp}/chrome-remote-desktop_current_amd64.deb" https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb >> "$LOG_FILE" 2>&1
    apt-get update >> "$LOG_FILE" 2>&1 || log "WARNING: apt-get update failed"
    apt-get install -y "${tmp}/chrome-remote-desktop_current_amd64.deb" >> "$LOG_FILE" 2>&1
    rm -rf "$tmp"
    log "chrome-remote-desktop package installed successfully"
else
    log "chrome-remote-desktop package is already installed"
fi

# =============================================================================
# 2. Write ~/.chrome-remote-desktop-session
# =============================================================================
SESSION_FILE="$HOME_DIR/.chrome-remote-desktop-session"
log "Creating $SESSION_FILE..."

cat > "$SESSION_FILE" << 'EOF'
#!/bin/bash
# =============================================================================
# .chrome-remote-desktop-session — Launch Sway under CRD's virtual X11 server
# =============================================================================
LOG_FILE="/home/user/logs/crd-session.log"
mkdir -p "/home/user/logs"
exec > "$LOG_FILE" 2>&1
echo "=== Chrome Remote Desktop session started at $(date) ==="

# Ensure environment matches expectations
export XDG_RUNTIME_DIR="/run/user/1000"
export XDG_SESSION_TYPE="x11"
export WLR_BACKENDS="x11"

# Import environment for correct D-Bus activation and GUI apps
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Wait a brief moment for the virtual X11 display to be fully ready
sleep 1

# Identify the Sway binary to launch (prefer Nix-managed Sway)
SWAY_BIN="/home/user/.nix-profile/bin/sway"
if [ ! -x "$SWAY_BIN" ]; then
    SWAY_BIN=$(which sway 2>/dev/null || echo "/usr/bin/sway")
fi

echo "Launching Sway with path: $SWAY_BIN"

# Launch inside a clean dbus user session to avoid IPC or DBus communication errors
exec dbus-run-session -- "$SWAY_BIN"
EOF

chown "$USER:$USER" "$SESSION_FILE"
chmod 0755 "$SESSION_FILE"
log "Created and configured $SESSION_FILE"

# =============================================================================
# 3. Create interactive helper script
# =============================================================================
BIN_DIR="$HOME_DIR/.local/bin"
mkdir -p "$BIN_DIR"
chown "$USER:$USER" "$BIN_DIR"

SETUP_SCRIPT="$BIN_DIR/setup-crd.sh"
log "Deploying setup helper script to $SETUP_SCRIPT..."

cat > "$SETUP_SCRIPT" << 'EOF'
#!/bin/bash
# =============================================================================
# setup-crd.sh — Interactive Setup Utility for Chrome Remote Desktop
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0;m' # No Color

echo -e "${BLUE}=== Chrome Remote Desktop Setup Helper ===${NC}"
echo

# 1. Double check installation
if ! command -v chrome-remote-desktop &>/dev/null && [ ! -f /opt/google/chrome-remote-desktop/chrome-remote-desktop ]; then
    echo -e "${YELLOW}chrome-remote-desktop is not installed. Downloading and installing it now...${NC}"
    tmp=$(mktemp -d)
    wget -q -O "${tmp}/chrome-remote-desktop_current_amd64.deb" https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
    sudo apt-get update || true
    sudo apt-get install -y "${tmp}/chrome-remote-desktop_current_amd64.deb"
    rm -rf "$tmp"
fi

# 2. Instruct user
echo -e "${YELLOW}To link this workstation to your Google account, follow these steps:${NC}"
echo -e "  1. Open a browser on your local device and navigate to:"
echo -e "     ${BLUE}https://remotedesktop.google.com/headless${NC}"
echo -e "  2. Sign in with your Google account."
echo -e "  3. Click 'Begin', then 'Next', and then click 'Authorize'."
echo -e "  4. Copy the shell command displayed for ${GREEN}Debian Linux${NC}."
echo -e "     (The command starts with 'DISPLAY= /opt/google/chrome-remote-desktop/start-host ...')"
echo

echo -e "Paste the copied command below and press ${GREEN}Enter${NC}:"
read -r auth_command

if [[ -z "$auth_command" ]]; then
    echo -e "${RED}Error: No command was entered. Exiting.${NC}"
    exit 1
fi

# Strip DISPLAY= prefix from the start of the command if it exists
cmd=$(echo "$auth_command" | sed 's/^DISPLAY=[[:space:]]*//')

echo -e "\n${YELLOW}Running the authorization command...${NC}"
echo -e "You will be prompted to enter a 6-digit PIN. Make sure to remember this PIN!"
echo

# Run the command
eval "$cmd"

echo
echo -e "${GREEN}Authentication successfully completed!${NC}"

# Enable and start the systemd service for user 'user'
echo -e "${YELLOW}Enabling and starting Chrome Remote Desktop systemd service...${NC}"
sudo systemctl enable chrome-remote-desktop@user.service --now || true

# Wait for service startup
sleep 2

# Check if active
if systemctl is-active --quiet chrome-remote-desktop@user.service || pgrep -f chrome-remote-desktop &>/dev/null; then
    echo -e "${GREEN}Chrome Remote Desktop is active and RUNNING!${NC}"
    echo -e "You can now connect to this workstation from the Remote Access dashboard:"
    echo -e "  ${BLUE}https://remotedesktop.google.com/access${NC}"
else
    echo -e "${RED}Warning: Service is not reported as active. Please check state via:${NC}"
    echo -e "  systemctl status chrome-remote-desktop@user.service"
fi
EOF

chown "$USER:$USER" "$SETUP_SCRIPT"
chmod 0755 "$SETUP_SCRIPT"
log "Deployed setup helper script successfully"

log "=== Chrome Remote Desktop setup complete ==="
