#!/bin/bash
# =============================================================================
# 08-workspaces.sh — Auto-launch apps across 5 Sway workspaces
# =============================================================================
# Waits for Sway to be ready, then launches:
#   ws1 = Chrome, ws2 = Antigravity IDE, ws3 = foot terminal, ws4 = foot terminal, ws5 = Hub
# Idempotent: skips if windows already exist.
# Runs as systemd service (ws-autolaunch) after wayvnc.service.
# =============================================================================

USER="user"
NIX="/home/user/.nix-profile/bin"
SWAYMSG="$NIX/swaymsg"
FOOT="$NIX/foot"
ANTIGRAVITY="/usr/bin/antigravity"
HUB="/home/user/.local/bin/antigravity-hub"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [08-workspaces] $1"; }

find_swaysock() {
    ls /run/user/1000/sway-ipc.*.sock 2>/dev/null | head -1
}

sway_cmd() {
    local sock
    sock="$(find_swaysock)"
    [ -z "$sock" ] && return 1
    runuser -u $USER -- env WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 SWAYSOCK="$sock" "$SWAYMSG" "$@"
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
for i in $(seq 1 60); do
    if sway_cmd -t get_tree >/dev/null 2>&1; then
        log "Sway is ready (attempt $i)"
        break
    fi
    [ "$i" -eq 60 ] && { log "ERROR: Sway not ready after 60s — aborting"; exit 1; }
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
# that Sway would tile onto the active workspace (ws1). In rootless mode
# Xwayland only creates surfaces for individual X11 clients, which is the
# correct behavior under a Wayland compositor. Without this flag, ws1
# booted with a 50/50 split between the Xwayland root window and the
# autostart foot terminal.
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
    local sock
    sock="$(find_swaysock)"
    runuser -u $USER -- env WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 SWAYSOCK="$sock" "$@" &
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

# Workspace 1: Google Chrome (Electron — 15s timeout)
launch_and_wait 1 15 google-chrome-stable --ozone-platform=wayland --disable-dev-shm-usage

# Workspace 2: Antigravity 2.0 desktop app (Electron — 30s timeout, needs longer to initialize)
if [ -x "$ANTIGRAVITY" ]; then
    launch_and_wait 2 30 "$ANTIGRAVITY" --no-sandbox --ozone-platform=wayland --use-gl=swiftshader --disable-dev-shm-usage
else
    log "WARNING: Antigravity not found at $ANTIGRAVITY — skipping ws2"
fi

# Workspace 3: foot terminal (fast — 5s timeout)
launch_and_wait 3 5 "$FOOT" --working-directory=/home/user

# Workspace 4: foot terminal (fast — 5s timeout)
launch_and_wait 4 5 "$FOOT" --working-directory=/home/user

# Workspace 5: Antigravity 2.0 Hub (Electron — 90s timeout; Hub may need to complete
# a Google OAuth flow before its window first paints, which can take 30–60s on the
# first run. F-0110: bumped from 30s → 90s to accommodate auth delays.)
HUB_OK=0
if [ -x "$HUB" ]; then
    HUB_LOG="/home/user/logs/hub-launch.log"
    mkdir -p "$(dirname "$HUB_LOG")"
    echo "=== Hub launch: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$HUB_LOG"
    # Redirect Hub stdout+stderr to the log so auth errors are diagnosable.
    # launch_and_wait signature is unchanged; wrapping the call site keeps
    # the generic function clean (F-0110).
    {
        launch_and_wait 5 90 "$HUB" --no-sandbox --ozone-platform=wayland --use-gl=swiftshader --disable-dev-shm-usage
        HUB_OK=$?
    } >> "$HUB_LOG" 2>&1
else
    log "WARNING: Hub not found at $HUB — skipping ws5"
fi

# Switch back to workspace 1 only if Hub launched successfully.
# F-0110: if Hub timed out (OAuth window not yet painted), leave focus on ws5
# so the auth window is visible to the user when it eventually appears.
if [ "$HUB_OK" -eq 0 ]; then
    sleep 1
    sway_cmd "workspace number 1"
    log "All workspaces launched, switched to workspace 1"
else
    log "All workspaces launched; Hub timed out — leaving focus on ws5 for OAuth"
fi
