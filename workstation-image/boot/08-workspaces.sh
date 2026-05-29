#!/bin/bash
# =============================================================================
# 08-workspaces.sh — Auto-launch apps across 5 Sway workspaces
# =============================================================================
# Waits for Sway to be ready, then launches:
#   ws1 = Hub, ws2 = Antigravity IDE, ws3 = foot terminal, ws4 = foot terminal, ws5 = Chrome
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

# =============================================================================
# Launch order: Chrome first (fast, needed for IDE OAuth), then Hub (ws1,
# slow — OAuth may delay first paint), then IDE (ws2, needs Chrome for auth),
# then foot terminals (ws3, ws4).  Final focused workspace is ws1 (Hub).
# =============================================================================

# Workspace 5: Google Chrome (Electron — 15s timeout)
# Launched FIRST so Chrome is available before the IDE and Hub attempt their
# Google OAuth flows.  Chrome lives on ws5 after the F-0112 workspace swap
# (previously ws1).  F-0111: --disable-gpu — no GPU on this host.
launch_and_wait 5 15 google-chrome-stable --ozone-platform=wayland --disable-dev-shm-usage --disable-gpu

# Workspace 1: Antigravity 2.0 Hub (Electron — 90s timeout)
# F-0112: Hub moved from ws5 → ws1. ws1 is the default landing workspace so
# the user arrives on the Hub after every boot without extra navigation.
#
# F-0110 auth-friendly launch notes (still apply, adapted to ws1):
#   - 90s timeout accommodates Google OAuth first-paint delay (30–60s on first run).
#   - Hub stdout+stderr captured to ~/logs/hub-launch.log (per-boot timestamp header).
#   - HUB_OK conditional: on success the user is already on ws1 (Hub) — the
#     sway_cmd "workspace number 1" at the end is a no-op. On timeout, focus also
#     stays on ws1 so the OAuth window is visible when it eventually paints.
#     Either path leaves the user on ws1 = Hub at the end of boot.
#
# F-0111 flags (all retained):
#   --disable-gpu               GPU-less host; stops crash loop from GPU child process.
#   --user-data-dir=...Hub      Separate userData dir from IDE to avoid Electron
#                               SingletonLock conflict (IDE wins lock on ~/.config/Antigravity).
#
# F-0114: Wedge-proof launch — clear stale Electron singleton lock files and
# orphaned Hub processes BEFORE launching.  After an unclean shutdown the Hub's
# user-data-dir retains SingletonLock/SingletonCookie/SingletonSocket from the
# previous session; Electron detects the lock and the bundled language_server
# never reports its port, so no BrowserWindow is ever created → blank ws1.
# Safe process matching: target exe path / cmdline substrings that are unique to
# Hub binaries, NOT a broad pkill -f pattern that can match this shell script
# itself and cause self-termination.

# --- Reap stale Hub processes (F-0114) ---
HUB_REAPED=0

# 1. Hub Electron main process: exe is ~/.local/share/antigravity-hub/antigravity
#    Use pgrep -x to match the process name "antigravity" and filter by the
#    full exe path so we do NOT kill the IDE's /usr/bin/antigravity.
while IFS= read -r pid; do
    exe_path=$(readlink -f /proc/"$pid"/exe 2>/dev/null || true)
    if echo "$exe_path" | grep -q "antigravity-hub/antigravity"; then
        kill "$pid" 2>/dev/null && HUB_REAPED=$((HUB_REAPED + 1)) || true
    fi
done < <(pgrep -x antigravity 2>/dev/null || true)

# 2. Hub language_server: cmdline contains "antigravity-hub/resources"
#    pgrep -x language_server matches exact process name; grep filters to Hub's copy.
while IFS= read -r pid; do
    cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || true)
    if echo "$cmdline" | grep -q "antigravity-hub/resources"; then
        kill "$pid" 2>/dev/null && HUB_REAPED=$((HUB_REAPED + 1)) || true
    fi
done < <(pgrep -x language_server 2>/dev/null || true)

# Give killed processes a moment to exit, then force-kill any survivors
if [ "$HUB_REAPED" -gt 0 ]; then
    sleep 1
    # Force-kill any that didn't exit cleanly (best-effort; ignore errors)
    while IFS= read -r pid; do
        exe_path=$(readlink -f /proc/"$pid"/exe 2>/dev/null || true)
        if echo "$exe_path" | grep -q "antigravity-hub/antigravity"; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done < <(pgrep -x antigravity 2>/dev/null || true)
    while IFS= read -r pid; do
        cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || true)
        if echo "$cmdline" | grep -q "antigravity-hub/resources"; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done < <(pgrep -x language_server 2>/dev/null || true)
fi

# 3. Remove stale Electron singleton lock files — safe on boot because no Hub
#    instance is legitimately running at this point.
rm -f /home/user/.config/Antigravity-Hub/Singleton*

log "Cleared $HUB_REAPED stale Hub processes and singleton lock before launch (F-0114)"

HUB_OK=0
if [ -x "$HUB" ]; then
    HUB_LOG="/home/user/logs/hub-launch.log"
    mkdir -p "$(dirname "$HUB_LOG")"
    echo "=== Hub launch: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$HUB_LOG"
    # Redirect Hub stdout+stderr to the log so auth errors are diagnosable.
    # launch_and_wait signature is unchanged; wrapping the call site keeps
    # the generic function clean (F-0110).
    {
        launch_and_wait 1 90 "$HUB" --no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage --user-data-dir=/home/user/.config/Antigravity-Hub
        HUB_OK=$?
    } >> "$HUB_LOG" 2>&1
else
    log "WARNING: Hub not found at $HUB — skipping ws1"
fi

# Workspace 2: Antigravity 2.0 desktop app (Electron — 30s timeout)
# F-0111: --disable-gpu (swiftshader still launched a crashing GPU child process
# on a GPU-less host; --disable-gpu prevents the GPU process from starting at all).
if [ -x "$ANTIGRAVITY" ]; then
    launch_and_wait 2 30 "$ANTIGRAVITY" --no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage
else
    log "WARNING: Antigravity not found at $ANTIGRAVITY — skipping ws2"
fi

# Workspace 3: foot terminal (fast — 5s timeout)
launch_and_wait 3 5 "$FOOT" --working-directory=/home/user

# Workspace 4: foot terminal (fast — 5s timeout)
launch_and_wait 4 5 "$FOOT" --working-directory=/home/user

# F-0112 focus logic: Hub is on ws1 — always end on ws1.
# On success (HUB_OK=0): sway_cmd to ws1 is a no-op (already there after ws3/ws4 launch),
#   but calling it explicitly guarantees the user lands on Hub even if focus drifted.
# On timeout (HUB_OK≠0): Hub timed out but its window may still appear later (OAuth delay).
#   Switching to ws1 ensures the OAuth paint is visible when it happens.
# Both cases: user ends up on ws1 (Hub).  This preserves the F-0110 intent ("leave focus
# on the Hub's workspace on timeout") now that the Hub's workspace IS ws1.
sleep 1
sway_cmd "workspace number 1"
if [ "$HUB_OK" -eq 0 ]; then
    log "All workspaces launched, switched to workspace 1 (Hub)"
else
    log "All workspaces launched; Hub timed out — switched to workspace 1 for OAuth visibility"
fi
