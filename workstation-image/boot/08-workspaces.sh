#!/bin/bash
# =============================================================================
# 08-workspaces.sh — Auto-launch apps across 5 Sway workspaces
# =============================================================================
# Waits for Sway to be ready, then launches:
#   ws1 = (empty — Hub not auto-launched; run 'hub-restart' to start it)
#   ws2 = (empty), ws3 = foot terminal, ws4 = foot terminal, ws5 = Chrome
# Idempotent: skips if windows already exist.
# Runs as systemd service (ws-autolaunch) after wayvnc.service.
#
# F-0124: Hub autostart removed. Boot no longer launches the Hub.
# Workspace 1 starts empty. Use hub-restart (F-0122) after connecting.
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

# --- Idempotent check ---
WINDOW_COUNT=$(sway_cmd -t get_tree 2>/dev/null | grep -o '"pid"' | wc -l)
if [ "${WINDOW_COUNT:-0}" -gt 1 ]; then
    log "Windows already open ($WINDOW_COUNT found) — skipping"
    exit 0
fi

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
# Launch order: Chrome first (fast, needed for OAuth), then foot terminals.
# ws1 = empty (Hub not auto-launched — F-0124).
# ws2 = empty.
# ws3 = foot terminal.
# ws4 = foot terminal.
# ws5 = Chrome.
# Final focused workspace: ws3 (terminal — user can run hub-restart from here).
# =============================================================================

# F-0124: Hub not auto-launched at boot.
# ws1 starts empty. The sway for_window rule (F-0116) still pins any
# app_id="antigravity" window to ws1, so hub-restart lands there correctly.
log "Hub not auto-launched (F-0124) — run 'hub-restart' to start it."

# Workspace 5: Google Chrome (Electron — 15s timeout)
# Launched FIRST so Chrome is available before Hub attempts its OAuth flow.
# F-0111: --disable-gpu — no GPU on this host.
launch_and_wait 5 15 google-chrome-stable --ozone-platform=wayland --disable-dev-shm-usage --disable-gpu

# Workspace 2: VS Code (Electron — 15s timeout)
launch_and_wait 2 15 "$NIX/code" --no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage

# Workspace 3: foot terminal (fast — 5s timeout)
launch_and_wait 3 5 "$FOOT" --working-directory=/home/user

# Workspace 4: foot terminal (fast — 5s timeout)
launch_and_wait 4 5 "$FOOT" --working-directory=/home/user

# F-0124: Focus on ws3 (terminal) so the user has a prompt ready to run hub-restart.
sleep 1
sway_cmd "workspace number 3"
log "All workspaces launched, switched to workspace 3 (terminal — run hub-restart to start Hub)"
