#!/bin/bash
# =============================================================================
# 08-workspaces.sh — Auto-launch apps across 5 Sway workspaces
# =============================================================================
# Waits for Sway to be ready, then launches:
#   ws1 = Antigravity IDE v2 (auto-launched, focused after boot)
#   ws2 = VS Code, ws3 = foot terminal, ws4 = Chrome
#   ws5 = (empty — Hub not auto-launched; run 'hub-restart' to start it)
# Idempotent: skips if windows already exist.
# Runs as systemd service (ws-autolaunch) after wayvnc.service.
#
# F-0136: IDE v2 auto-launched on ws1. Hub moved to ws5 (manual start).
# F-0124: Hub autostart removed. Use hub-restart (F-0122) after connecting.
# =============================================================================

USER="user"
NIX="/home/user/.nix-profile/bin"
SWAYMSG="$NIX/swaymsg"
FOOT="$NIX/foot"
DBUS_ADDR="unix:path=/run/user/1000/bus"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [08-workspaces] $1"; }

DETECTED_SOCK=""
DETECTED_DISPLAY="wayland-1"

detect_active_session() {
    local attempt="${1:-1}"
    DETECTED_SOCK=""
    DETECTED_DISPLAY="wayland-1"

    local crd_enabled=0
    if systemctl is-enabled chrome-remote-desktop@user.service >/dev/null 2>&1; then
        crd_enabled=1
    fi

    # Try to find the CRD session socket first (must have X11-1 output)
    for sock in /run/user/1000/sway-ipc.1000.*.sock; do
        [ -S "$sock" ] || continue
        if SWAYSOCK="$sock" "$SWAYMSG" -t get_outputs 2>/dev/null | grep -q 'X11-1'; then
            DETECTED_SOCK="$sock"
            local pid
            pid=$(basename "$sock" | cut -d. -f3)
            local lock_file
            lock_file=$(ls -la /proc/$pid/fd/ 2>/dev/null | grep -o 'wayland-[0-9]\+\.lock' | head -n1 || true)
            if [ -n "$lock_file" ]; then
                DETECTED_DISPLAY="${lock_file%.lock}"
            fi
            return 0
        fi
    done

    # If CRD is enabled, NEVER fall back to headless — keep waiting for CRD.
    # ws-autolaunch is ordered After=chrome-remote-desktop@user.service, so CRD
    # should be starting. Wait up to 60 attempts (~120s) for its Sway to appear.
    if [ "$crd_enabled" -eq 1 ]; then
        return 1
    fi

    # CRD is not configured — fall back to headless if available
    local fallback_sock
    fallback_sock=$(ls /run/user/1000/sway-ipc.1000.*.sock 2>/dev/null | head -n1 || true)
    if [ -n "$fallback_sock" ]; then
        DETECTED_SOCK="$fallback_sock"
        local pid
        pid=$(basename "$fallback_sock" | cut -d. -f3)
        local lock_file
        lock_file=$(ls -la /proc/$pid/fd/ 2>/dev/null | grep -o 'wayland-[0-9]\+\.lock' | head -n1 || true)
        if [ -n "$lock_file" ]; then
            DETECTED_DISPLAY="${lock_file%.lock}"
        fi
        return 0
    fi

    return 1
}

sway_cmd() {
    [ -z "$DETECTED_SOCK" ] && return 1
    runuser -u $USER -- env WAYLAND_DISPLAY="$DETECTED_DISPLAY" XDG_RUNTIME_DIR=/run/user/1000 SWAYSOCK="$DETECTED_SOCK" "$SWAYMSG" "$@"
}

# Count windows on a specific workspace
count_windows_on_ws() {
    local ws="$1"
    sway_cmd -t get_tree 2>/dev/null | python3 -c "
import json, sys
tree = json.load(sys.stdin)
def count(node, target_ws, in_ws=False):
    c = 0
    if node.get('type') == 'workspace' and node.get('num') == target_ws:
        in_ws = True
    if in_ws and node.get('pid') and node.get('pid') > 0:
        c = 1
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        c += count(child, target_ws, in_ws)
    return c
print(count(tree, $ws))
" 2>/dev/null || echo "0"
}

# --- Wait for Sway ---
log "Waiting for Sway to be ready..."
for i in $(seq 1 120); do
    if detect_active_session "$i" && sway_cmd -t get_tree >/dev/null 2>&1; then
        log "Sway is ready (attempt $i). Socket: $DETECTED_SOCK, Display: $DETECTED_DISPLAY"
        break
    fi
    [ "$i" -eq 120 ] && { log "ERROR: Sway not ready after 240s — aborting"; exit 1; }
    sleep 2
done

# --- CRD Resolution Auto-Resize (F-0137) ---
# Once Sway is detected as ready, check if CRD is enabled/active.
if systemctl is-enabled chrome-remote-desktop@user.service >/dev/null 2>&1 || \
   systemctl is-active --quiet chrome-remote-desktop@user.service || \
   pgrep -f chrome-remote-desktop >/dev/null 2>&1; then
    log "CRD is enabled/active. Automatically configuring virtual screen resolution to 2560x1440..."
    runuser -u "$USER" -- mkdir -p /home/user/logs
    if [ -x "/home/user/.local/bin/crd-resize" ]; then
        runuser -u "$USER" -- env PATH="/home/user/.nix-profile/bin:/usr/bin:/bin:$PATH" /home/user/.local/bin/crd-resize 2560 1440 > /home/user/logs/crd-resize-boot.log 2>&1
    else
        log "WARNING: /home/user/.local/bin/crd-resize not found or not executable, skipping resolution configure"
    fi
fi


# --- Idempotent check (F-0133) ---
# Count only actual application windows — containers with app_id (Wayland) or
# window_properties.class (X11) and type == "con".  Background processes like
# swaybar, Xwayland server, etc. do NOT have app_id/class set and are excluded.
# The old check (grep -o '"pid"' | wc -l) was too aggressive — it counted all
# PID entries in the sway tree, including non-window processes, causing autolaunch
# to skip even when no user apps were open.
APP_COUNT=$(sway_cmd -t get_tree 2>/dev/null | python3 -c "
import json, sys
tree = json.load(sys.stdin)
def count(n):
    c = 0
    if n.get('type') == 'con' and (n.get('app_id') or n.get('window_properties', {}).get('class')):
        c = 1
    for child in n.get('nodes', []) + n.get('floating_nodes', []):
        c += count(child)
    return c
print(count(tree))
" 2>/dev/null)
if [ "${APP_COUNT:-0}" -gt 0 ]; then
    log "App windows already open ($APP_COUNT found) — skipping"
    exit 0
fi

# --- Clean up stale SingletonLock files from previous boots ---
# Electron apps (Chrome, VS Code) create SingletonLock to prevent duplicate
# instances. After a reboot the lock file persists on the persistent disk,
# blocking new instances from launching. Safe to remove at boot since no
# Electron apps are running yet (the idempotent check above confirmed this).
log "Cleaning up stale SingletonLock files..."
rm -f "$HOME_DIR/.config/google-chrome/SingletonLock" 2>/dev/null
rm -f "$HOME_DIR/.config/Code/SingletonLock" 2>/dev/null

# --- Start Xwayland for X11 apps (IntelliJ) ---
# F-0096: pass -rootless so Xwayland does NOT create a visible root window
# that Sway would tile onto the active workspace. In rootless mode Xwayland
# only creates surfaces for individual X11 clients.
if ! pgrep -f "Xwayland :0" >/dev/null 2>&1; then
    log "Starting Xwayland on :0 (rootless)..."
    sway_cmd exec "/usr/bin/Xwayland -rootless :0" 2>/dev/null
    sleep 2
    if pgrep -f "Xwayland :0" >/dev/null 2>&1; then
        log "Xwayland started on :0 (rootless)"
    else
        log "WARNING: Xwayland failed to start"
    fi
else
    log "Xwayland already running on :0"
fi

# --- Launch app and wait for its window to appear on the workspace ---
launch_and_wait() {
    local ws="$1"
    local timeout="$2"
    shift 2

    # Switch to target workspace
    sway_cmd "workspace number $ws"
    sleep 0.5

    # Count windows before launch
    local before
    before=$(count_windows_on_ws "$ws")

    # Launch the app
    # -u LD_LIBRARY_PATH: prevent NVIDIA host driver libs from crashing Electron's
    # EGL initialization on hosts without a physical GPU.
    runuser -u $USER -- env -u LD_LIBRARY_PATH WAYLAND_DISPLAY="$DETECTED_DISPLAY" XDG_RUNTIME_DIR=/run/user/1000 SWAYSOCK="$DETECTED_SOCK" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" "$@" &
    local app_pid=$!

    # Wait for a new window to appear on this workspace
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        sleep 1
        elapsed=$((elapsed + 1))
        local after
        after=$(count_windows_on_ws "$ws")
        if [ "$after" -gt "$before" ]; then
            log "Launched on ws$ws (${elapsed}s): $*"
            return 0
        fi
    done
    log "WARNING: Timeout (${timeout}s) waiting for window on ws$ws: $*"
    return 1
}

# =============================================================================
# F-0115: Start gnome-keyring Secret Service before any app launch.
# The Hub's bundled language_server persists and reloads its OAuth token via
# the freedesktop.org Secret Service API. Without a provider, every token
# persist/reload fails and the Hub reverts to logged-out after first paint.
# We start gnome-keyring-daemon with an empty password so the login keyring
# (stored on the persistent home disk at ~/.local/share/keyrings/) is unlocked
# non-interactively on every boot.
#
# Race-condition fix: CRD or D-Bus autoactivation may start gnome-keyring-daemon
# before this script runs. When that happens, the login keyring can be locked
# (created with PAM password). We must detect this and restart the daemon with
# --unlock. We also ensure login.keyring uses an empty password by removing any
# password-protected keyring file before starting the daemon.
# =============================================================================
KEYRING_DIR="/home/$USER/.local/share/keyrings"
KEYRING_FILE="$KEYRING_DIR/login.keyring"

_keyring_env="env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=$DBUS_ADDR"

# Helper: check if the login collection is locked via D-Bus.
_keyring_is_locked() {
    local result
    result=$(runuser -u "$USER" -- $_keyring_env \
        dbus-send --session --print-reply \
        --dest=org.freedesktop.secrets \
        /org/freedesktop/secrets/collection/login \
        org.freedesktop.DBus.Properties.Get \
        string:org.freedesktop.Secret.Collection string:Locked 2>/dev/null)
    echo "$result" | grep -q "boolean true"
}

# Helper: start (or restart) gnome-keyring-daemon with empty-password unlock.
_keyring_start_unlocked() {
    # Remove any password-protected keyring file so the daemon creates a fresh
    # one with the empty password we pipe in.
    if [ -f "$KEYRING_FILE" ]; then
        log "Removing password-protected login.keyring to recreate with empty password"
        rm -f "$KEYRING_FILE"
    fi
    runuser -u "$USER" -- $_keyring_env \
        sh -c 'printf "\n" | /usr/bin/gnome-keyring-daemon --unlock --components=secrets' \
        >/dev/null 2>&1 &
    sleep 1
}

if [ ! -x /usr/bin/gnome-keyring-daemon ]; then
    log "WARNING: /usr/bin/gnome-keyring-daemon not found — Secret Service unavailable; Hub OAuth token will not persist"
elif pgrep -x gnome-keyring-daemon >/dev/null 2>&1; then
    log "Secret service already running, checking login keyring lock state..."
    if _keyring_is_locked; then
        log "Login keyring is LOCKED — restarting gnome-keyring-daemon with --unlock (F-0115)"
        pkill -x gnome-keyring-daemon 2>/dev/null
        sleep 1
        _keyring_start_unlocked
    else
        log "Login keyring is already unlocked — no action needed"
    fi
else
    log "Starting gnome-keyring secret service (F-0115)..."
    _keyring_start_unlocked
fi

# Final verification: daemon running and keyring unlocked.
if pgrep -x gnome-keyring-daemon >/dev/null 2>&1; then
    if _keyring_is_locked; then
        log "WARNING: gnome-keyring-daemon running but login keyring still locked — Hub OAuth may fail"
    else
        log "gnome-keyring secret service running, login keyring unlocked ✓"
    fi
else
    log "WARNING: gnome-keyring-daemon failed to start — Hub OAuth token persistence may not work"
fi

# =============================================================================
# F-0136 workspace layout:
#   ws1 = Antigravity IDE v2 (auto-launch, 15s timeout, Electron flags)
#   ws2 = VS Code (Electron — 15s timeout)
#   ws3 = foot terminal (fast — 5s timeout)
#   ws4 = Chrome (Electron — 15s timeout)
#   ws5 = Hub (manual — not auto-launched; run 'hub-restart' to start it)
# Final focused workspace: ws1 (Antigravity IDE)
# =============================================================================

# Workspace 4: Google Chrome (Electron — 15s timeout)
# Launched FIRST so Chrome is available before Hub/IDE OAuth flows.
# F-0111: --disable-gpu — no GPU on this host.
launch_and_wait 4 15 google-chrome-stable --ozone-platform=wayland --disable-dev-shm-usage --disable-gpu

# Workspace 2: VS Code (Electron — 15s timeout)
launch_and_wait 2 15 "$NIX/code" --no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage

# Workspace 3: foot terminal (fast — 5s timeout)
launch_and_wait 3 5 "$FOOT" --working-directory=/home/user

# Workspace 1: Antigravity IDE v2 (Electron — 15s timeout)
# F-0136: auto-launch with Electron flags for GPU-less Wayland host.
launch_and_wait 1 15 /home/user/.local/bin/antigravity-ide --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage

# F-0124: Hub not auto-launched at boot.
# ws5 starts empty. The sway for_window rule pins any app_id="antigravity"
# window to ws5, so hub-restart lands there correctly.
log "Hub not auto-launched (F-0124) — run 'hub-restart' to start it on ws5."

# F-0136: Focus on ws1 (Antigravity IDE) so the user lands on the primary dev environment.
sleep 1
sway_cmd "workspace number 1"
log "All workspaces launched, switched to workspace 1 (Antigravity IDE)"
