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

# Connect to the systemd user D-Bus session bus to share services (like gnome-keyring)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

echo "Launching Sway with path: $SWAY_BIN"
exec "$SWAY_BIN"
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

# =============================================================================
# 4. Create resolution resize helper script
# =============================================================================
RESIZE_SCRIPT="$BIN_DIR/crd-resize"
log "Deploying resolution resize helper script to $RESIZE_SCRIPT..."

cat > "$RESIZE_SCRIPT" << 'EOF'
#!/bin/bash
# =============================================================================
# crd-resize — Quick utility to resize virtual display and Sway output
# =============================================================================

set -e

WIDTH="${1:-}"
HEIGHT="${2:-}"

if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
    echo "Usage: crd-resize <width> <height>"
    echo "Example: crd-resize 2560 1440"
    exit 1
fi

MODE_NAME="${WIDTH}x${HEIGHT}_60.00"

echo "Calculating modeline for ${WIDTH}x${HEIGHT}..."
MODELINE=$(cvt "$WIDTH" "$HEIGHT" | grep -v '^#' | cut -d' ' -f3-)

if [[ -z "$MODELINE" ]]; then
    echo "Error: Failed to calculate modeline using cvt."
    exit 1
fi

echo "Adding custom mode: $MODE_NAME"
# Attempt to remove if already exists, to avoid errors
DISPLAY=:20 xrandr --delmode DUMMY0 "$MODE_NAME" 2>/dev/null || true
DISPLAY=:20 xrandr --rmmode "$MODE_NAME" 2>/dev/null || true

# Apply newmode and addmode
eval "DISPLAY=:20 xrandr --newmode \"$MODE_NAME\" $MODELINE"
DISPLAY=:20 xrandr --addmode DUMMY0 "$MODE_NAME"

echo "Applying X11 resolution..."
DISPLAY=:20 xrandr --output DUMMY0 --mode "$MODE_NAME"

# Find active Sway IPC socket for nested session (must have X11-1 output)
SWAYSOCK_NESTED=""
for sock in /run/user/1000/sway-ipc.1000.*.sock; do
    [ -S "$sock" ] || continue
    if SWAYSOCK="$sock" swaymsg -t get_outputs 2>/dev/null | grep -q 'X11-1'; then
        SWAYSOCK_NESTED="$sock"
        break
    fi
done

if [[ -n "$SWAYSOCK_NESTED" ]]; then
    echo "Applying Sway nested X11-1 output mode..."
    SWAYSOCK="$SWAYSOCK_NESTED" swaymsg "output X11-1 mode ${WIDTH}x${HEIGHT}"
else
    echo "Warning: Active nested Sway IPC socket not found."
fi

echo "Done! Resolution set to ${WIDTH}x${HEIGHT}."
EOF

chown "$USER:$USER" "$RESIZE_SCRIPT"
chmod 0755 "$RESIZE_SCRIPT"
log "Deployed resolution resize helper script successfully"

# =============================================================================
# 4b. Create clipboard bridge helper script
# =============================================================================
CLIPBOARD_SCRIPT="$BIN_DIR/crd-clipboard-bridge"
log "Deploying clipboard bridge helper script to $CLIPBOARD_SCRIPT..."

cat > "$CLIPBOARD_SCRIPT" << 'EOF'
#!/usr/bin/env python3
import sys
import os
import subprocess
import time
import tkinter

# Force display name to display :20 (CRD session)
os.environ["DISPLAY"] = ":20"

class ClipboardBridge:
    def __init__(self):
        self.root = tkinter.Tk()
        self.root.withdraw()
        
        # Initialize clipboard states
        self.last_x11 = self.get_x11_clipboard()
        self.last_wl = self.get_wayland_clipboard()
        
        # Start the periodic sync loop (every 500 ms)
        self.root.after(500, self.sync)

    def get_x11_clipboard(self):
        try:
            return self.root.clipboard_get()
        except Exception:
            return ""

    def set_x11_clipboard(self, text):
        try:
            self.root.clipboard_clear()
            self.root.clipboard_append(text)
            # update X11 display to process clipboard ownership events
            self.root.update()
        except Exception:
            pass

    def get_wayland_clipboard(self):
        try:
            return subprocess.check_output(["wl-paste", "-n", "-t", "text"], stderr=subprocess.DEVNULL).decode("utf-8")
        except Exception:
            return ""

    def set_wayland_clipboard(self, text):
        try:
            p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
            p.communicate(input=text.encode("utf-8"))
        except Exception:
            pass

    def sync(self):
        try:
            # Sync X11 -> Wayland
            current_x11 = self.get_x11_clipboard()
            if current_x11 != self.last_x11 and current_x11 != self.last_wl:
                if current_x11:
                    self.set_wayland_clipboard(current_x11)
                    self.last_wl = current_x11
                self.last_x11 = current_x11
            
            # Sync Wayland -> X11
            current_wl = self.get_wayland_clipboard()
            if current_wl != self.last_wl and current_wl != self.last_x11:
                if current_wl:
                    self.set_x11_clipboard(current_wl)
                    self.last_x11 = current_wl
                self.last_wl = current_wl
        except Exception:
            pass
        
        # Schedule next iteration
        self.root.after(500, self.sync)

    def run(self):
        self.root.mainloop()

def main():
    # Wait for display :20 to be ready
    for _ in range(30):
        try:
            root = tkinter.Tk()
            root.destroy()
            break
        except Exception:
            time.sleep(1)
            
    try:
        bridge = ClipboardBridge()
        bridge.run()
    except Exception:
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

chown "$USER:$USER" "$CLIPBOARD_SCRIPT"
chmod 0755 "$CLIPBOARD_SCRIPT"
log "Deployed clipboard bridge helper script successfully"

# =============================================================================
# 5. Enable and start the systemd service if CRD is configured
# =============================================================================
if ls "$HOME_DIR/.config/chrome-remote-desktop"/host#*.json &>/dev/null; then
    log "CRD configuration found. Enabling and starting systemd service..."
    systemctl enable chrome-remote-desktop@user.service --now >> "$LOG_FILE" 2>&1 || log "WARNING: Failed to start chrome-remote-desktop service"
else
    log "CRD configuration not found. Skipping service start (run setup-crd.sh first)."
fi

log "=== Chrome Remote Desktop setup complete ==="

