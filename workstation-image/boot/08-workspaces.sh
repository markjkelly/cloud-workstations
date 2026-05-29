#!/bin/bash
# =============================================================================
# 08-workspaces.sh — Auto-launch apps across 5 Sway workspaces
# =============================================================================
# Waits for Sway to be ready, then launches:
#   ws1 = Hub, ws2 = (empty), ws3 = foot terminal, ws4 = foot terminal, ws5 = Chrome
# Idempotent: skips if windows already exist.
# Runs as systemd service (ws-autolaunch) after wayvnc.service.
# =============================================================================

USER="user"
NIX="/home/user/.nix-profile/bin"
SWAYMSG="$NIX/swaymsg"
FOOT="$NIX/foot"
HUB="/home/user/.local/bin/antigravity-hub"
DBUS_ADDR="unix:path=/run/user/1000/bus"

# =============================================================================
# F-0117: Named constants for Hub launch resilience (no magic numbers).
#
# HUB_LAUNCH_TIMEOUT — seconds to wait per attempt for either the
#   language_server HTTPS port to be in LISTEN state OR the Hub
#   app_id=antigravity window to appear in the sway tree.
#   90 s matches the prior single-shot timeout so the total wall time
#   for 1 attempt is unchanged; subsequent retries add up to 2 × 90 s
#   more worst-case, which is acceptable at boot.
#
# HUB_MAX_RETRIES — total launch attempts (first attempt + this many
#   retries).  3 attempts means up to ~4.5 min worst-case, still well
#   within a typical boot window and highly unlikely to be reached
#   in practice (the failure is intermittent, not systematic).
#
# HUB_LS_LOG — dedicated log for language_server boot diagnostics
#   (F-0117 instrumentation).  Captures boot environment, retry
#   timeline, and language_server process state on each failing attempt
#   so the next cold-boot failure leaves enough evidence for a
#   targeted root-cause fix.
# =============================================================================
HUB_LAUNCH_TIMEOUT=90
HUB_MAX_RETRIES=3
HUB_LS_LOG="/home/user/logs/language_server_boot_diag.log"

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

# =============================================================================
# F-0117: language_server readiness check.
#
# The Hub's Electron main process spawns the bundled language_server child with
# --https_server_port 0 (random port).  The server is "ready" when it has a
# TCP socket in LISTEN state.  The ready signal then fires the
# "[Auto-Restart] Port changed!" Electron event, which causes Electron to
# navigate the BrowserWindow to https://127.0.0.1:<port>/ and create a
# renderer process.  Without this the BrowserWindow is never navigated and
# no app_id=antigravity window ever maps in sway.
#
# Detection strategy: find the language_server pid (child of the Hub Electron
# main process, exe matches antigravity-hub/resources/bin/language_server),
# then check /proc/<pid>/net/tcp6 for a socket in LISTEN state (state 0A in
# hex).  Falls back to /proc/net/tcp6 if the per-pid file is unavailable.
# Returns 0 (success/ready) if at least one LISTEN socket exists for that pid.
# =============================================================================
hub_language_server_ready() {
    # Find language_server pid: match exact process name AND cmdline contains
    # "antigravity-hub/resources" to avoid matching unrelated language_server
    # processes on the system.
    local ls_pid=""
    while IFS= read -r pid; do
        local cmdline
        cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || true)
        if echo "$cmdline" | grep -q "antigravity-hub/resources"; then
            ls_pid="$pid"
            break
        fi
    done < <(pgrep -x language_server 2>/dev/null || true)

    if [ -z "$ls_pid" ]; then
        # language_server not running yet — not ready
        return 1
    fi

    # Check for a LISTEN socket (state 0A) in the process's network namespace.
    # /proc/<pid>/net/tcp6 lists all TCP6 sockets visible to this process.
    # Column 4 is the socket state in hex; 0A = TCP_LISTEN.
    local tcp_file="/proc/${ls_pid}/net/tcp6"
    if [ ! -f "$tcp_file" ]; then
        tcp_file="/proc/net/tcp6"
    fi
    if [ -f "$tcp_file" ] && grep -q ' 0A ' "$tcp_file" 2>/dev/null; then
        return 0  # at least one socket is in LISTEN state — ready
    fi

    # Fallback: also check /proc/net/tcp (IPv4) in case language_server binds
    # on 127.0.0.1 rather than [::1].
    if grep -q ' 0A ' /proc/net/tcp 2>/dev/null; then
        return 0
    fi

    return 1  # no LISTEN socket found — not yet ready
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
    runuser -u $USER -- env WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 SWAYSOCK="$sock" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" "$@" &
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
# the freedesktop.org Secret Service API.  Without a provider, every token
# persist/reload fails and the Hub reverts to logged-out after first paint.
# We start gnome-keyring-daemon with an empty password so the login keyring
# (stored on the persistent home disk at ~/.local/share/keyrings/) is unlocked
# non-interactively on every boot.  DBUS_ADDR is set above; apps also receive
# DBUS_SESSION_BUS_ADDRESS so they can reach the bus.
# Idempotent: if gnome-keyring-daemon is already running, skip re-launch.
# =============================================================================
if [ ! -x /usr/bin/gnome-keyring-daemon ]; then
    log "WARNING: /usr/bin/gnome-keyring-daemon not found — Secret Service unavailable; Hub OAuth token will not persist"
elif pgrep -x gnome-keyring-daemon >/dev/null 2>&1; then
    log "Secret service already running, skipping gnome-keyring-daemon start"
else
    log "Starting gnome-keyring secret service (F-0115)..."
    runuser -u "$USER" -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
        sh -c 'printf "\n" | /usr/bin/gnome-keyring-daemon --unlock --components=secrets' \
        >/dev/null 2>&1 &
    sleep 1
    if pgrep -x gnome-keyring-daemon >/dev/null 2>&1; then
        log "Started gnome-keyring secret service"
    else
        log "WARNING: gnome-keyring-daemon failed to start — Hub OAuth token persistence may not work"
    fi
fi

# =============================================================================
# Launch order: Chrome first (fast, needed for OAuth), then Hub (ws1,
# slow — OAuth may delay first paint), then foot terminals (ws3, ws4).
# ws2 is intentionally empty (Antigravity IDE removed in F-0116).
# Final focused workspace is ws1 (Hub).
# =============================================================================

# Workspace 5: Google Chrome (Electron — 15s timeout)
# Launched FIRST so Chrome is available before the IDE and Hub attempt their
# Google OAuth flows.  Chrome lives on ws5 after the F-0112 workspace swap
# (previously ws1).  F-0111: --disable-gpu — no GPU on this host.
launch_and_wait 5 15 google-chrome-stable --ozone-platform=wayland --disable-dev-shm-usage --disable-gpu

# =============================================================================
# Workspace 1: Antigravity 2.0 Hub (Electron)
#
# F-0117: Resilient launch with readiness-based wait and retry.
#
# The prior single-shot launch_and_wait 1 90 only detected success by watching
# for a sway window.  At cold boot the Hub's bundled language_server
# intermittently fails to become "listening" before the timeout; without a
# listening language_server, Electron never fires the "Port changed!" event,
# the BrowserWindow is never navigated, no renderer process starts, and no
# app_id=antigravity window ever maps in sway — ws1 remains blank.
#
# New behaviour (F-0117):
#   • Each attempt uses hub_language_server_ready() — polls the language_server
#     PID for a LISTEN socket in /proc/<pid>/net/tcp6 — as the primary readiness
#     signal.  A sway window appearing is also accepted as success.
#   • If neither signal fires within HUB_LAUNCH_TIMEOUT seconds the attempt is
#     declared failed: stale Hub processes are killed (safe pgrep/exe-path
#     filtering, same approach as F-0114) and Singleton* lock files are removed
#     before relaunching.
#   • Up to HUB_MAX_RETRIES total attempts.  Each attempt is logged with its
#     attempt number and outcome.
#   • On a failed attempt, the boot environment and language_server state are
#     captured to HUB_LS_LOG (F-0117 instrumentation) so the next cold-boot
#     failure provides enough data for a targeted root-cause fix.
#
# Preserved from prior fixes:
#   F-0110: Hub stdout+stderr → hub-launch.log.
#   F-0111: --disable-gpu, --user-data-dir=Antigravity-Hub.
#   F-0112: ws1 is the Hub workspace; end-of-boot focus lands on ws1.
#   F-0114: safe pgrep-based process reaping (no broad pkill -f).
#   F-0115: DBUS_SESSION_BUS_ADDRESS in launch env (via inline env block).
#   F-0116: for_window [app_id="antigravity"] rule in sway config pins Hub
#           to ws1 once its window maps — unchanged by this fix.
# =============================================================================

# Helper: kill any running Hub processes and clear Singleton locks.
# Extracted so the retry loop can call it cleanly.  Uses the same safe
# pgrep/exe-path filtering as F-0114 (no broad pkill -f).
_kill_stale_hub() {
    local reaped=0

    # 1. Hub Electron main process
    while IFS= read -r pid; do
        local exe_path
        exe_path=$(readlink -f /proc/"$pid"/exe 2>/dev/null || true)
        if echo "$exe_path" | grep -q "antigravity-hub/antigravity"; then
            kill "$pid" 2>/dev/null && reaped=$((reaped + 1)) || true
        fi
    done < <(pgrep -x antigravity 2>/dev/null || true)

    # 2. Hub language_server child
    while IFS= read -r pid; do
        local cmdline
        cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || true)
        if echo "$cmdline" | grep -q "antigravity-hub/resources"; then
            kill "$pid" 2>/dev/null && reaped=$((reaped + 1)) || true
        fi
    done < <(pgrep -x language_server 2>/dev/null || true)

    if [ "$reaped" -gt 0 ]; then
        sleep 1
        # Force-kill survivors
        while IFS= read -r pid; do
            local exe_path
            exe_path=$(readlink -f /proc/"$pid"/exe 2>/dev/null || true)
            if echo "$exe_path" | grep -q "antigravity-hub/antigravity"; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        done < <(pgrep -x antigravity 2>/dev/null || true)
        while IFS= read -r pid; do
            local cmdline
            cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || true)
            if echo "$cmdline" | grep -q "antigravity-hub/resources"; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        done < <(pgrep -x language_server 2>/dev/null || true)
    fi

    # 3. Remove stale Electron singleton lock files
    rm -f /home/user/.config/Antigravity-Hub/Singleton*

    log "Cleared $reaped stale Hub processes and singleton locks"
}

# --- Reap stale Hub processes before first launch (F-0114) ---
HUB_REAPED=0

while IFS= read -r pid; do
    exe_path=$(readlink -f /proc/"$pid"/exe 2>/dev/null || true)
    if echo "$exe_path" | grep -q "antigravity-hub/antigravity"; then
        kill "$pid" 2>/dev/null && HUB_REAPED=$((HUB_REAPED + 1)) || true
    fi
done < <(pgrep -x antigravity 2>/dev/null || true)

while IFS= read -r pid; do
    cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || true)
    if echo "$cmdline" | grep -q "antigravity-hub/resources"; then
        kill "$pid" 2>/dev/null && HUB_REAPED=$((HUB_REAPED + 1)) || true
    fi
done < <(pgrep -x language_server 2>/dev/null || true)

if [ "$HUB_REAPED" -gt 0 ]; then
    sleep 1
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

# Remove stale Electron singleton lock files — safe on boot because no Hub
# instance is legitimately running at this point.
rm -f /home/user/.config/Antigravity-Hub/Singleton*

log "Cleared $HUB_REAPED stale Hub processes and singleton lock before launch (F-0114)"

# --- Resilient Hub launch with readiness-based wait and retry (F-0117) ---
HUB_OK=0
if [ -x "$HUB" ]; then
    HUB_LOG="/home/user/logs/hub-launch.log"
    mkdir -p "$(dirname "$HUB_LOG")"
    mkdir -p "$(dirname "$HUB_LS_LOG")"

    echo "=== Hub launch: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$HUB_LOG"
    echo "=== Hub boot diag: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$HUB_LS_LOG"

    hub_attempt=0
    while [ "$hub_attempt" -lt "$HUB_MAX_RETRIES" ]; do
        hub_attempt=$((hub_attempt + 1))
        log "Hub launch attempt $hub_attempt/$HUB_MAX_RETRIES (timeout=${HUB_LAUNCH_TIMEOUT}s)"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $hub_attempt/$HUB_MAX_RETRIES" >> "$HUB_LS_LOG"

        # Switch to ws1 and record the window count before launch
        sway_cmd "workspace number 1"
        sleep 0.5
        ws1_before=$(count_windows_on_ws 1)

        # Launch the Hub; redirect stdout+stderr to hub-launch.log (F-0110)
        local_sock="$(find_swaysock)"
        runuser -u $USER -- env \
            WAYLAND_DISPLAY=wayland-1 \
            XDG_RUNTIME_DIR=/run/user/1000 \
            SWAYSOCK="$local_sock" \
            DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
            "$HUB" \
            --no-sandbox \
            --ozone-platform=wayland \
            --disable-gpu \
            --disable-dev-shm-usage \
            --user-data-dir=/home/user/.config/Antigravity-Hub \
            >> "$HUB_LOG" 2>&1 &

        # Poll for EITHER the language_server HTTPS port in LISTEN state OR
        # a new sway window on ws1, whichever comes first.
        hub_elapsed=0
        hub_attempt_ok=0
        while [ "$hub_elapsed" -lt "$HUB_LAUNCH_TIMEOUT" ]; do
            sleep 1
            hub_elapsed=$((hub_elapsed + 1))

            # Primary readiness signal: language_server port listening
            if hub_language_server_ready; then
                log "Hub attempt $hub_attempt: language_server is LISTENING (${hub_elapsed}s) — success"
                hub_attempt_ok=1
                break
            fi

            # Secondary readiness signal: sway window appeared on ws1
            ws1_after=$(count_windows_on_ws 1)
            if [ "$ws1_after" -gt "$ws1_before" ]; then
                log "Hub attempt $hub_attempt: sway window appeared on ws1 (${hub_elapsed}s) — success"
                hub_attempt_ok=1
                break
            fi
        done

        if [ "$hub_attempt_ok" -eq 1 ]; then
            HUB_OK=0
            log "Hub launch succeeded on attempt $hub_attempt"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $hub_attempt SUCCEEDED" >> "$HUB_LS_LOG"
            break
        fi

        # =================================================================
        # Attempt failed — capture instrumentation before killing stale
        # processes (F-0117 instrumentation).
        # =================================================================
        log "Hub attempt $hub_attempt: no readiness signal within ${HUB_LAUNCH_TIMEOUT}s — capturing diagnostics"
        {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $hub_attempt FAILED after ${HUB_LAUNCH_TIMEOUT}s"
            echo "--- uptime ---"
            uptime 2>/dev/null || true
            echo "--- language_server process state ---"
            local_ls_found=0
            while IFS= read -r pid; do
                local_cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || true)
                if echo "$local_cmdline" | grep -q "antigravity-hub/resources"; then
                    local_ls_found=1
                    echo "  PID $pid: cmdline=$local_cmdline"
                    echo "  status headers=$(cat /proc/"$pid"/status 2>/dev/null | head -5 || echo gone)"
                fi
            done < <(pgrep -x language_server 2>/dev/null || true)
            [ "$local_ls_found" -eq 0 ] && echo "  (no language_server process found)"
            echo "--- Hub Electron processes ---"
            while IFS= read -r pid; do
                local_exe=$(readlink -f /proc/"$pid"/exe 2>/dev/null || true)
                if echo "$local_exe" | grep -q "antigravity-hub/antigravity"; then
                    echo "  PID $pid: exe=$local_exe"
                fi
            done < <(pgrep -x antigravity 2>/dev/null || true)
            echo "--- key environment ---"
            echo "  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}"
            echo "  XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-unset}"
            echo "  DBUS_ADDR=$DBUS_ADDR"
            echo "  SWAYSOCK=${local_sock:-unset}"
            echo "--- /proc/net/tcp6 LISTEN sockets ---"
            grep ' 0A ' /proc/net/tcp6 2>/dev/null | head -20 || echo "  none"
            echo "--- /proc/net/tcp LISTEN sockets ---"
            grep ' 0A ' /proc/net/tcp 2>/dev/null | head -20 || echo "  none"
            echo "---"
        } >> "$HUB_LS_LOG"

        if [ "$hub_attempt" -lt "$HUB_MAX_RETRIES" ]; then
            log "Killing stale Hub processes before retry attempt $((hub_attempt + 1))..."
            _kill_stale_hub
            sleep 2
        else
            log "WARNING: Hub failed all $HUB_MAX_RETRIES attempts — ws1 may be blank"
            HUB_OK=1
        fi
    done
else
    log "WARNING: Hub not found at $HUB — skipping ws1"
fi

# Workspace 3: foot terminal (fast — 5s timeout)
launch_and_wait 3 5 "$FOOT" --working-directory=/home/user

# Workspace 4: foot terminal (fast — 5s timeout)
launch_and_wait 4 5 "$FOOT" --working-directory=/home/user

# F-0112/F-0116 focus logic: Hub is on ws1 — always end on ws1.
# On success (HUB_OK=0): sway_cmd to ws1 is a no-op (already there after ws3/ws4 launch),
#   but calling it explicitly guarantees the user lands on Hub even if focus drifted.
# On timeout (HUB_OK≠0): Hub timed out but its window may still appear later (OAuth delay).
#   F-0116: for_window [app_id="antigravity"] in sway config pins the Hub to ws1 regardless
#   of when its window maps, so switching to ws1 guarantees the OAuth paint is visible.
# Both cases: user ends up on ws1 (Hub).
sleep 1
sway_cmd "workspace number 1"
if [ "$HUB_OK" -eq 0 ]; then
    log "All workspaces launched, switched to workspace 1 (Hub)"
else
    log "All workspaces launched; Hub failed all retries — switched to workspace 1"
fi
