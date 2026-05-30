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

# =============================================================================
# F-0118: Named constants for the LS boot diagnostic sampler.
#
# HUB_LS_DIAG_LOG — new dedicated diagnostic log written by the F-0118
#   sampler that runs in the background during the Hub launch window.
#   Unlike HUB_LS_LOG (which only writes on attempt failure), this log
#   captures detailed per-sample data throughout every launch attempt,
#   providing a continuous timeline even when F-0117's readiness check
#   falsely reports success (which it always does — see F-0118 spec for
#   the false-positive analysis).
#
# HUB_LS_DIAG_INTERVAL — seconds between sampler samples.  3 s is fine
#   enough to catch a short-lived LS startup sequence (which succeeds in
#   ~0.3 s on warm runs) while keeping the log compact over 90 s windows.
# =============================================================================
HUB_LS_DIAG_LOG="/home/user/logs/hub-ls-diag.log"
HUB_LS_DIAG_INTERVAL=3

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

# =============================================================================
# F-0121 Part B: Wait for user session before launching any apps.
#
# ROOT CAUSE HYPOTHESIS (confirmed-correlation 2026-05-29): ws-autolaunch.service
# starts only ~3s after user@1000.service.  At that point the D-Bus session,
# gnome-keyring, and XDG portals are still activating.  The Hub's first
# language_server --standalone spawn lands in this half-initialised session and
# fails — producing the blank-ws1 cold-boot bug.  The F-0117 retry (Attempt 2)
# succeeds ~116s later when the session is fully ready.
#
# FIX: wait here until BOTH conditions hold:
#   1. runuser -u user -- true  → 0  (PAM/NSS can open a session)
#   2. dbus-send probe on unix:path=/run/user/1000/bus  → 0  (D-Bus bus is up)
# Timeout: 120s, fail-open (proceed after timeout with a WARNING log).
#
# The F-0117 retry loop and F-0118/F-0119/F-0120 diagnostics are PRESERVED as
# a backstop.  This gate is intended to make the FIRST Hub launch attempt land
# in a ready session so the retry is rarely needed.
#
# VALIDATE ON REBOOT: after merge + reboot, check:
#   ~/logs/ls-spawn.log  — should show a --standalone header on Attempt 1
#   ~/logs/hub-launch.log  — should show "Port changed!" fired by Attempt 1
#   ~/logs/app-update.log  — should show wait + per-step OK lines (Part A)
#
# SHARED HELPER NOTE: wait_for_user_session is also defined in 07-apps.sh
# (F-0121 Part A).  No shared sourced library exists in this boot script set;
# the helper is duplicated deliberately so each script is self-contained.
# =============================================================================

# wait_for_user_session: blocks until the user PAM session and D-Bus user bus
# are both available, or until WS_WAIT_TIMEOUT seconds elapse.
# Returns 0 on success, 1 on timeout.  Always fail-open.
WS_WAIT_TIMEOUT=120
WS_WAIT_POLL=2

wait_for_user_session() {
    local elapsed=0
    log "F-0121: Waiting for user session (user@1000.service + D-Bus) — timeout ${WS_WAIT_TIMEOUT}s ..."

    while [ "$elapsed" -lt "$WS_WAIT_TIMEOUT" ]; do
        # Condition 1: PAM/NSS can resolve the user entry and open a session
        local runuser_ok=0
        if runuser -u "$USER" -- true >/dev/null 2>&1; then
            runuser_ok=1
        fi

        # Condition 2: D-Bus session bus socket is reachable.
        # Only probe once runuser succeeds (no point probing D-Bus if PAM
        # cannot resolve the user entry yet).
        local dbus_ok=0
        if [ "$runuser_ok" -eq 1 ]; then
            if dbus-send \
                    --bus="unix:path=/run/user/1000/bus" \
                    --dest=org.freedesktop.DBus \
                    --type=method_call \
                    --print-reply \
                    /org/freedesktop/DBus \
                    org.freedesktop.DBus.ListNames \
                    >/dev/null 2>&1; then
                dbus_ok=1
            fi
        fi

        if [ "$runuser_ok" -eq 1 ] && [ "$dbus_ok" -eq 1 ]; then
            log "F-0121: User session ready after ${elapsed}s (runuser OK, D-Bus OK)"
            return 0
        fi

        # Log progress every 10s to aid diagnosis without flooding the log
        if [ "$((elapsed % 10))" -eq 0 ] && [ "$elapsed" -gt 0 ]; then
            log "F-0121: Still waiting for user session at ${elapsed}s (runuser_ok=$runuser_ok, dbus_ok=$dbus_ok)"
        fi

        sleep "$WS_WAIT_POLL"
        elapsed=$((elapsed + WS_WAIT_POLL))
    done

    log "F-0121: WARNING — user session NOT ready after ${WS_WAIT_TIMEOUT}s; proceeding anyway (fail-open)"
    return 1
}

# Wait for session readiness before launching any apps.
# Fail-open: if the session is not ready after 120s, log and continue.
# The F-0117 retry loop acts as a backstop if the session is not yet fully
# initialised when the Hub launches.
_ws_session_wait_start=$(date '+%s' 2>/dev/null || echo 0)
wait_for_user_session || true
_ws_session_wait_end=$(date '+%s' 2>/dev/null || echo 0)
_ws_session_wait_elapsed=$(( _ws_session_wait_end - _ws_session_wait_start ))
log "F-0121: Session readiness gate elapsed: ${_ws_session_wait_elapsed}s"

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

# =============================================================================
# F-0119: Install a capture shim over the Hub's language_server binary.
#
# PURPOSE
#   The Hub swallows language_server's stdout+stderr completely — we have never
#   seen WHY LS dies at cold boot.  This shim sits between the Hub and the real
#   ELF binary, passes BOTH streams through to the Hub UNMODIFIED (so the Hub's
#   port-discovery still works), and ALSO tees them to:
#     ~/logs/ls-spawn.log  — human-readable spawn/exit records (timestamp, args, rc)
#     ~/logs/ls-spawn.out  — raw LS stdout (append; may contain the port line)
#     ~/logs/ls-spawn.err  — raw LS stderr (append; likely contains crash reason)
#
# IDEMPOTENCY
#   The shim starts with the marker line "# F-0119 LS capture shim".
#   If LS_BIN contains that marker  → shim already installed; verify .real exists.
#   If LS_BIN is an ELF binary      → first install (or Hub auto-update replaced
#                                      the shim with a fresh ELF); move to .real.
#   If LS_BIN does not exist        → Hub not installed yet; skip with WARNING.
#
# SAFETY
#   All failure paths are guarded with || true so boot never fails here.
#   The warm path is verified in SWE-QA before this is committed.
# =============================================================================
_f0119_install_ls_shim() {
    local LS_BIN="/home/user/.local/share/antigravity-hub/resources/bin/language_server"
    local LS_REAL="${LS_BIN}.real"
    local SHIM_MARKER="# F-0119 LS capture shim"
    local SHIM_VERSION="# F-0120"

    # Ensure log directory exists
    mkdir -p /home/user/logs 2>/dev/null || true

    if [ ! -e "$LS_BIN" ]; then
        log "F-0119 WARNING: $LS_BIN does not exist — Hub not installed yet; skipping shim install"
        return 0
    fi

    # Detect whether LS_BIN is already the shim (text) or the real ELF.
    # The shim's shebang is on line 1; the marker is on line 2.  Check the
    # first 3 lines to be robust against any future shim edits.
    if head -3 "$LS_BIN" 2>/dev/null | grep -qF "$SHIM_MARKER"; then
        # Shim is already installed.  Check if it is the current F-0120 version.
        # If the version marker is absent, the installed shim is stale (F-0119-era)
        # and must be overwritten in-place.  language_server.real is NOT touched.
        if grep -qF "$SHIM_VERSION" "$LS_BIN" 2>/dev/null; then
            # Up-to-date shim — verify .real exists and is executable
            if [ -x "$LS_REAL" ]; then
                log "F-0120: LS capture shim (F-0120) already installed; language_server.real is executable"
            else
                log "F-0120 WARNING: shim installed but $LS_REAL is missing or not executable — broken state"
            fi
            return 0
        else
            # Stale shim (F-0119 or earlier) — overwrite in-place with F-0120 shim.
            log "F-0120: Upgrading stale LS shim to F-0120 version (overwriting in-place; .real untouched)..."
            # Fall through to the heredoc write below.
        fi
    else
        # LS_BIN is not the shim (it's the real ELF, possibly from a Hub auto-update).
        # Move it to .real (overwrite any older .real), then write the shim.
        log "F-0120: Installing LS capture shim (moving real binary to language_server.real)..."
        mv -f "$LS_BIN" "$LS_REAL" 2>/dev/null || {
            log "F-0120 WARNING: failed to move $LS_BIN → $LS_REAL; skipping shim install"
            return 0
        }
        chmod +x "$LS_REAL" 2>/dev/null || true
    fi

    # Write (or overwrite) the shim.  Use a single-quoted heredoc ('SHIM_EOF') so all
    # $VARIABLES, $*, $$, $PATH remain literal in the written file — they are expanded
    # at LS runtime by bash, NOT at install time by this boot script.
    #
    # F-0120 changes vs F-0119:
    #   1. Shebang: #!/bin/bash (absolute) — runs even when the Hub passes a stripped
    #      empty PATH to its children, which broke #!/usr/bin/env bash.
    #   2. Env capture: first action writes Hub's child env to ~/logs/ls-spawn.env
    #      (timestamp, pid, args, PATH value, full env dump) to confirm/refute the
    #      broken-PATH theory on the next cold boot.
    #   3. Env repair: export PATH prepends /usr/bin:/bin:/usr/local/bin before exec;
    #      HOME is set to /home/user if empty.
    #   4. Passthrough unchanged: stdout+stderr are tee'd AND passed through to the
    #      Hub UNMODIFIED so port-discovery ("[Auto-Restart] Port changed!") still works.
    #   5. SIGTERM/SIGINT forwarding to real child preserved (Hub lifecycle management).
    cat > "$LS_BIN" << 'SHIM_EOF'
#!/bin/bash
# F-0119 LS capture shim — tees language_server stdout/stderr for cold-boot diagnosis.
# F-0120
# Passes both streams through UNMODIFIED to the Hub (the Hub parses LS output for the
# dynamic HTTPS port), while also appending to ~/logs/ls-spawn.{out,err,env}.
LOG=/home/user/logs/ls-spawn.log
OUT=/home/user/logs/ls-spawn.out
ERR=/home/user/logs/ls-spawn.err
ENV=/home/user/logs/ls-spawn.env
REAL="$(dirname "$0")/language_server.real"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
# --- F-0120: capture Hub's child-spawn environment BEFORE any repair ---
# This is the FIRST action so we record the raw environment the Hub supplied.
# Guards with || true so no write failure can kill the shim.
{
  echo "=== LS env capture: $(date '+%Y-%m-%d %H:%M:%S.%3N') pid=$$ ==="
  echo "args: $*"
  echo "PATH=$PATH"
  echo "HOME=$HOME"
  echo "--- full env ---"
  env
  echo "--- end env ---"
} >>"$ENV" 2>/dev/null || true
# --- F-0120: repair environment so LS always gets a sane PATH and HOME ---
export PATH="/usr/bin:/bin:/usr/local/bin${PATH:+:$PATH}"
[ -z "$HOME" ] && export HOME=/home/user
# --- spawn/exit record ---
{ echo "=== LS spawn: $(date '+%Y-%m-%d %H:%M:%S.%3N') pid=$$ ==="; echo "args: $*"; } >>"$LOG" 2>&1 || true
# Forward SIGTERM/SIGINT to the real child so Hub lifecycle management works.
_ls_child_pid=""
_ls_forward_signal() { [ -n "$_ls_child_pid" ] && kill -s "$1" "$_ls_child_pid" 2>/dev/null || true; }
trap '_ls_forward_signal TERM' TERM
trap '_ls_forward_signal INT'  INT
"$REAL" "$@" > >(tee -a "$OUT") 2> >(tee -a "$ERR" >&2) &
_ls_child_pid=$!
wait "$_ls_child_pid"
rc=$?
{ echo "=== LS exit: $(date '+%Y-%m-%d %H:%M:%S.%3N') pid=$$ rc=$rc ==="; } >>"$LOG" 2>&1 || true
exit $rc
SHIM_EOF

    chmod +x "$LS_BIN" 2>/dev/null || {
        log "F-0120 WARNING: failed to chmod +x $LS_BIN — shim may not be executable"
    }
    log "F-0120: LS capture shim (F-0120) installed at $LS_BIN (real binary at $LS_REAL)"
}

# =============================================================================
# F-0118: Background diagnostic sampler for language_server boot failures.
#
# PURPOSE
#   F-0117's hub_language_server_ready() check is a guaranteed false positive:
#   /proc/<pid>/net/tcp6 is in the SHARED network namespace (same as init),
#   so it sees the entire host's LISTEN sockets (Chrome, sway, wayvnc, sshd)
#   and returns "ready" after ~3 s on every boot even when LS has already died.
#   The retry loop never actually retries.  This sampler provides the ground-
#   truth visibility we need to root-cause the real failure.
#
# HOW IT WORKS
#   _f0118_ls_diag_sampler() runs as a background subshell during the Hub
#   launch-window poll loop.  It samples every HUB_LS_DIAG_INTERVAL seconds
#   and appends timestamped records to HUB_LS_DIAG_LOG.  It is started with
#   &, its PID captured, and killed when the poll loop exits.
#
#   Per sample it captures:
#     (a) All language_server processes (cmdline matches antigravity-hub/resources):
#         pid, /proc/<pid>/stat field 3 (process state: R=running, S=sleeping,
#         Z=zombie, D=uninterruptible, etc.).  Disappearance of a previously
#         seen PID is reported explicitly with the elapsed time — this pins
#         exactly when/if LS dies.
#     (b) LS-OWNED LISTEN sockets — done correctly, NOT via the shared-
#         namespace approach of F-0117:
#         1. Collect socket inodes from /proc/<pid>/fd/* (readlink, filter
#            "socket:[INODE]" to get inode numbers)
#         2. Match those inodes against the inode column in /proc/net/tcp
#            and /proc/net/tcp6, filtering to LISTEN state (hex 0A)
#         3. Decode the hex local_address field (bytes 7-10 as big-endian
#            IPv4 or bytes 9-10 as port from the TCP6 combined field) to
#            get the real port number.
#         This tells us whether LS itself — not some unrelated process — owns
#         a listening socket, and which port it is on.
#     (c) Hub-reported port: grep latest "Port changed! Reloading all windows
#         with URL: https://127.0.0.1:<PORT>/" from hub-launch.log.
#     (d) Actual connectivity probe on each LS-owned port and the Hub-reported
#         port: curl -sk (falls back to bash /dev/tcp if curl absent).
#     (e) Hub renderer process count (--type=renderer processes with antigravity
#         in their cmdline) — the clearest success signal.
#     (f) DNS/network readiness: getent + curl HEAD to daily-cloudcode-pa.
#         googleapis.com (leading cold-boot failure hypothesis).
#     (g) ONE-TIME per boot: list of LS log files under ~/.config/Antigravity*
#         and find for language_server*.log — reveals where LS writes its own
#         log so we can read it after the next cold boot.
#
#   Additionally, on first sample with a live LS pid:
#     - Logs /proc/<pid>/fd/1 and /proc/<pid>/fd/2 targets (stdout/stderr
#       destination) — tells us where LS output is going without changing
#       launch behavior.
#     - Logs any GLOG_log_dir / --log_dir / --logtostderr signals in LS
#       cmdline or /proc/<pid>/environ.
#
# SAFETY CONSTRAINTS
#   - Every command is guarded with || true — sampler NEVER fails the script.
#   - Sampler runs as a subshell; any error is silently swallowed.
#   - No write to any file other than HUB_LS_DIAG_LOG.
#   - No signals sent to any process other than its own background pid.
#   - Does NOT change launch timing, flags, or environment of the Hub or LS.
# =============================================================================
_f0118_ls_diag_sampler() {
    local diag_log="$1"    # path to HUB_LS_DIAG_LOG
    local interval="$2"    # HUB_LS_DIAG_INTERVAL (seconds between samples)
    local boot_start="$3"  # boot epoch for elapsed-time arithmetic

    # One-time flag: log-file snapshot and LS fd targets done only once per boot
    local snap_done=0
    # Track previously seen LS PIDs to detect disappearance
    local prev_ls_pids=""

    while true; do
        local now elapsed ts
        now=$(date '+%s' 2>/dev/null || echo "0") || now=0
        elapsed=$(( now - boot_start ))
        ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown") || ts="unknown"

        {
            echo ""
            echo "--- [+${elapsed}s] ${ts} ---"

            # -----------------------------------------------------------------
            # (a) language_server process state
            # -----------------------------------------------------------------
            echo "  [a] language_server processes:"
            local cur_ls_pids=""
            while IFS= read -r pid; do
                local cmdline
                cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || true)
                if echo "$cmdline" | grep -q "antigravity-hub/resources" 2>/dev/null; then
                    local stat_state
                    # /proc/<pid>/stat field 3 is the process state character
                    stat_state=$(awk '{print $3}' /proc/"$pid"/stat 2>/dev/null || echo "gone") || stat_state="gone"
                    echo "      PID=$pid state=$stat_state cmdline=$cmdline"
                    cur_ls_pids="${cur_ls_pids} ${pid}"

                    # ---------------------------------------------------------
                    # (b) LS-owned LISTEN sockets via inode matching (correct)
                    # ---------------------------------------------------------
                    echo "      [b] LS-owned LISTEN sockets (inode method):"
                    local ls_inodes=""
                    local fd
                    for fd in /proc/"$pid"/fd/*; do
                        local target
                        # Use plain readlink (not -f) because socket:[INODE] is
                        # not a real filesystem path — readlink -f would fail to
                        # resolve it and return empty.  Plain readlink gives us
                        # the raw symlink target string: "socket:[12345678]".
                        target=$(readlink "$fd" 2>/dev/null || true)
                        case "$target" in
                            socket:\[*\])
                                # Extract the numeric inode from "socket:[INODE]"
                                local inode
                                inode=$(echo "$target" | sed 's/socket:\[//;s/\]//') || true
                                ls_inodes="${ls_inodes} ${inode}"
                                ;;
                        esac
                    done 2>/dev/null || true

                    if [ -z "$ls_inodes" ]; then
                        echo "        no socket fds found for PID $pid"
                    else
                        # Match inodes against /proc/net/tcp and /proc/net/tcp6
                        # Format of /proc/net/tcp6 and /proc/net/tcp:
                        #   sl local_address rem_address st ... inode
                        #   Field 2=local_address, field 4=state, last field=inode
                        # LISTEN state = 0A (hex)
                        local found_listen=0
                        local tcp_file
                        for tcp_file in /proc/net/tcp /proc/net/tcp6; do
                            [ -f "$tcp_file" ] || continue
                            while IFS= read -r line; do
                                local state_hex line_inode
                                state_hex=$(echo "$line" | awk '{print $4}') || true
                                line_inode=$(echo "$line" | awk '{print $NF}') || true
                                if [ "$state_hex" = "0A" ]; then
                                    local inode
                                    for inode in $ls_inodes; do
                                        if [ "$inode" = "$line_inode" ]; then
                                            # Decode the hex local_address port
                                            # local_address field format in /proc/net/tcp:
                                            #   AABBCCDD:PPPP (IPv4 BE hex) — port is PPPP
                                            # in /proc/net/tcp6:
                                            #   AABBCCDDAABBCCDDAABBCCDDAABBCCDD:PPPP — port is PPPP
                                            local hex_port
                                            hex_port=$(echo "$line" | awk '{print $2}' | cut -d: -f2) || true
                                            local dec_port
                                            dec_port=$(printf '%d' "0x${hex_port}" 2>/dev/null || echo "?") || dec_port="?"
                                            echo "        LISTEN on port $dec_port (inode=$inode, src=$tcp_file)"
                                            found_listen=1

                                            # (d) Probe: curl or /dev/tcp
                                            if [ "$dec_port" != "?" ] && [ "$dec_port" -gt 0 ] 2>/dev/null; then
                                                echo "        [d] probe https://127.0.0.1:${dec_port}/"
                                                if command -v curl >/dev/null 2>&1; then
                                                    local probe_result
                                                    probe_result=$(curl -sk -o /dev/null \
                                                        -w "%{http_code} %{time_total}s" \
                                                        --max-time 3 \
                                                        "https://127.0.0.1:${dec_port}/" 2>/dev/null || echo "curl-fail") || probe_result="curl-fail"
                                                    echo "          curl result: $probe_result"
                                                else
                                                    # bash /dev/tcp fallback
                                                    if (exec 3<>/dev/tcp/127.0.0.1/"$dec_port") 2>/dev/null; then
                                                        echo "          /dev/tcp: port $dec_port is open (curl absent)"
                                                        exec 3>&- 2>/dev/null || true
                                                    else
                                                        echo "          /dev/tcp: port $dec_port refused/timeout (curl absent)"
                                                    fi
                                                fi
                                            fi
                                        fi
                                    done
                                fi
                            done < <(grep ' 0A ' "$tcp_file" 2>/dev/null || true)
                        done
                        if [ "$found_listen" -eq 0 ]; then
                            echo "        no LISTEN sockets owned by PID $pid (inodes:${ls_inodes})"
                        fi
                    fi

                    # ---------------------------------------------------------
                    # LS stdout/stderr fd targets + GLOG signals (first sample
                    # only, when LS is alive — req 5)
                    # ---------------------------------------------------------
                    if [ "$snap_done" -eq 0 ]; then
                        echo "      [fd-targets] LS stdout/stderr destinations:"
                        local fd1 fd2
                        fd1=$(readlink -f /proc/"$pid"/fd/1 2>/dev/null || echo "unreadable") || fd1="unreadable"
                        fd2=$(readlink -f /proc/"$pid"/fd/2 2>/dev/null || echo "unreadable") || fd2="unreadable"
                        echo "        fd/1 (stdout) -> $fd1"
                        echo "        fd/2 (stderr) -> $fd2"
                        echo "      [glog] LS glog/log_dir signals:"
                        local ls_env_log
                        ls_env_log=$(tr '\0' '\n' < /proc/"$pid"/environ 2>/dev/null \
                            | grep -iE 'GLOG|LOG_DIR|LOGTOSTDERR' || echo "  none") || ls_env_log="unreadable"
                        echo "        environ: $ls_env_log"
                        local ls_cmd_log
                        ls_cmd_log=$(echo "$cmdline" | grep -oE '(--log_dir|--logtostderr|GLOG)[^ ]*' || echo "  none") || ls_cmd_log="none"
                        echo "        cmdline flags: $ls_cmd_log"
                    fi
                fi
            done < <(pgrep -x language_server 2>/dev/null || true)

            # Detect disappearance of previously seen PIDs
            if [ -n "$prev_ls_pids" ]; then
                local ppid
                for ppid in $prev_ls_pids; do
                    if ! echo "$cur_ls_pids" | grep -qw "$ppid" 2>/dev/null; then
                        echo "      *** PID $ppid DISAPPEARED at +${elapsed}s ***"
                    fi
                done
            fi
            if [ -z "$cur_ls_pids" ]; then
                echo "      (no language_server process found)"
            fi

            # (c) Hub-reported port from hub-launch.log
            echo "  [c] Hub-reported port (from hub-launch.log):"
            local hub_port
            hub_port=$(grep -oP 'Port changed! Reloading all windows with URL: https://127\.0\.0\.1:\K[0-9]+' \
                /home/user/logs/hub-launch.log 2>/dev/null | tail -1 || true) || hub_port=""
            if [ -n "$hub_port" ]; then
                echo "      Hub last reported port: $hub_port"
                # (d) Probe the Hub-reported port
                echo "      [d] probe https://127.0.0.1:${hub_port}/ (Hub-reported)"
                if command -v curl >/dev/null 2>&1; then
                    local hub_probe
                    hub_probe=$(curl -sk -o /dev/null \
                        -w "%{http_code} %{time_total}s" \
                        --max-time 3 \
                        "https://127.0.0.1:${hub_port}/" 2>/dev/null || echo "curl-fail") || hub_probe="curl-fail"
                    echo "        curl result: $hub_probe"
                else
                    if (exec 3<>/dev/tcp/127.0.0.1/"$hub_port") 2>/dev/null; then
                        echo "        /dev/tcp: port $hub_port is open (curl absent)"
                        exec 3>&- 2>/dev/null || true
                    else
                        echo "        /dev/tcp: port $hub_port refused/timeout (curl absent)"
                    fi
                fi
            else
                echo "      (no 'Port changed!' line in hub-launch.log yet)"
            fi

            # (e) Hub renderer count
            echo "  [e] Hub renderer processes:"
            local renderer_count
            renderer_count=$(pgrep -afc -- '--type=renderer' 2>/dev/null | grep -c 'antigravity' || echo "0") || renderer_count="0"
            # pgrep -afc may not be available everywhere; fall back
            if ! pgrep -af -- '--type=renderer' >/dev/null 2>&1; then
                renderer_count=$(pgrep -f -- '--type=renderer' 2>/dev/null \
                    | while IFS= read -r rpid; do
                        tr '\0' ' ' < /proc/"$rpid"/cmdline 2>/dev/null || true
                    done | grep -c 'antigravity' 2>/dev/null || echo "0") || renderer_count="0"
            else
                renderer_count=$(pgrep -af -- '--type=renderer' 2>/dev/null \
                    | grep -c 'antigravity' || echo "0") || renderer_count="0"
            fi
            echo "      antigravity renderer count: $renderer_count"

            # (f) DNS / network readiness (leading failure hypothesis)
            echo "  [f] DNS / network readiness:"
            local dns_result
            dns_result=$(getent hosts daily-cloudcode-pa.googleapis.com 2>/dev/null || echo "NXDOMAIN/fail") || dns_result="getent-fail"
            echo "      getent daily-cloudcode-pa.googleapis.com: $dns_result"
            if command -v curl >/dev/null 2>&1; then
                local net_probe
                net_probe=$(curl -sk -o /dev/null \
                    -w "%{http_code} %{time_total}s" \
                    --max-time 3 \
                    "https://daily-cloudcode-pa.googleapis.com/" 2>/dev/null || echo "curl-fail") || net_probe="curl-fail"
                echo "      curl daily-cloudcode-pa.googleapis.com: $net_probe"
            else
                echo "      curl absent — skipping net probe"
            fi

            # (g) ONE-TIME per boot: LS log file snapshot
            if [ "$snap_done" -eq 0 ]; then
                echo "  [g] ONE-TIME log file snapshot:"
                ls -la --time-style=full-iso \
                    /home/user/.config/Antigravity-Hub/logs/ \
                    /home/user/.config/Antigravity/logs/ \
                    2>/dev/null || echo "      (no logs dirs found)"
                echo "      find language_server*.log:"
                find /home/user/.config -name 'language_server*.log' 2>/dev/null \
                    || echo "      (none found)"
                snap_done=1
            fi

        } >> "$diag_log" 2>/dev/null || true

        prev_ls_pids="$cur_ls_pids"
        sleep "$interval" 2>/dev/null || true
    done
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

# --- F-0119: Install LS capture shim BEFORE Hub launches ---
# Must run after any Hub auto-update step (07-apps.sh) and before the Hub
# spawns language_server.  Idempotent — safe to call on every boot.
_f0119_install_ls_shim || true

# --- Resilient Hub launch with readiness-based wait and retry (F-0117) ---
HUB_OK=0
if [ -x "$HUB" ]; then
    HUB_LOG="/home/user/logs/hub-launch.log"
    mkdir -p "$(dirname "$HUB_LOG")"
    mkdir -p "$(dirname "$HUB_LS_LOG")"

    echo "=== Hub launch: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$HUB_LOG"
    echo "=== Hub boot diag: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$HUB_LS_LOG"

    # F-0118: Write the per-boot header to the new dedicated diagnostic log.
    # The sampler is started once per launch attempt (inside the retry loop
    # below) and writes timestamped samples throughout the full launch window.
    mkdir -p "$(dirname "$HUB_LS_DIAG_LOG")"
    echo "=== F-0118 LS diag: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$HUB_LS_DIAG_LOG"

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

        # F-0118: Start the diagnostic sampler in the background for this
        # launch attempt.  It runs for the full HUB_LAUNCH_TIMEOUT window,
        # sampling every HUB_LS_DIAG_INTERVAL seconds.  We record the boot
        # epoch here for elapsed-time arithmetic inside the sampler.
        # The sampler is killed (cleanly) once the poll loop below exits,
        # regardless of success or failure — it never outlives this attempt.
        _f0118_boot_epoch=$(date '+%s' 2>/dev/null || echo "0") || _f0118_boot_epoch=0
        {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $hub_attempt/$HUB_MAX_RETRIES — sampler start" \
                >> "$HUB_LS_DIAG_LOG" 2>/dev/null || true
            _f0118_ls_diag_sampler "$HUB_LS_DIAG_LOG" "$HUB_LS_DIAG_INTERVAL" "$_f0118_boot_epoch"
        } &
        _f0118_sampler_pid=$!

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

        # F-0118: Kill the sampler background process — cleanly, with SIGTERM.
        # The sampler guards all its operations with || true so it exits cleanly
        # on SIGTERM.  We suppress errors in case it already exited naturally.
        kill "$_f0118_sampler_pid" 2>/dev/null || true
        wait "$_f0118_sampler_pid" 2>/dev/null || true
        {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $hub_attempt — sampler stopped (elapsed ${hub_elapsed}s, ok=${hub_attempt_ok})" \
                >> "$HUB_LS_DIAG_LOG" 2>/dev/null || true
        }

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
