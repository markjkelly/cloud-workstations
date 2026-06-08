#!/bin/bash
# =============================================================================
# 07-apps.sh — Update apps to latest versions on boot
# =============================================================================
# Updates Claude Code, Gemini CLI (npm), Nix apps (home-manager),
# Antigravity Hub, and Antigravity CLI.
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

# Create log directory (runs as root — no runuser needed here)
mkdir -p "$LOG_DIR"

log "=== App update started ==="

# =============================================================================
# F-0121 / F-0123: Wait for the user session to be fully ready before running
# any runuser commands.
#
# F-0121 ROOT CAUSE (confirmed 2026-05-29): 07-apps.sh used to run at boot+32s
# via setup.sh inline.  user@1000.service (the systemd user manager, which
# brings up NSS/PAM infrastructure) only starts at boot+115s–203s.  Until then,
# getent passwd user cannot resolve the "user" entry and every
# "runuser -u user -- ..." call fails silently.
#
# F-0121 FIX: poll until BOTH conditions hold or WAIT_TIMEOUT seconds elapse
# (fail-open):
#   1. runuser -u user -- true  → 0 (PAM can open a user session)
#   2. dbus-send probe on unix:path=/run/user/1000/bus  → 0 (D-Bus bus is up)
#
# F-0123 IMPROVEMENT (2026-06-02): This script is now invoked by
# ws-app-updates.service (After=user@1000.service network-online.target)
# instead of by setup.sh.  Systemd ordering guarantees user@1000.service is
# active before this script runs, so wait_for_user_session should succeed in
# seconds on any boot speed.  The helper is retained as a DEFENSIVE BACKSTOP
# only — it catches any timing edge case where the unit ordering delivers the
# service before its socket/bus is fully usable.  The fail-open path (SKIPPED)
# remains in place as a last resort.
#
# F-0123 FOLLOW-UP FIX (D-Bus probe uid — 2026-06-02):
# The dbus-send probe MUST run as uid 1000, not as root.  The session bus at
# unix:path=/run/user/1000/bus authenticates connections via SO_PEERCRED /
# EXTERNAL SASL mechanism — it checks that the connecting process UID matches
# the owner of the bus (uid 1000).  When this script runs as root (no User=
# directive in ws-app-updates.service), a raw "dbus-send --bus=..." call comes
# from uid 0 and the bus rejects it, so dbus_ok stays 0 for the full 120s
# and the script hits the SKIPPED path even though the session is ready.
# Fix: wrap the probe in "runuser -u $USER --" so it runs as uid 1000.
# Confirmed on the live box: root probe → FAIL, runuser probe → SUCCESS.
#
# dbus-send, busctl, and gdbus are all confirmed present on this Ubuntu 24.04
# base (verified 2026-05-29).  We use dbus-send as the primary probe.
#
# SHARED HELPER NOTE: After F-0124 removed Hub autostart, wait_for_user_session
# exists only in this file (07-apps.sh).  The duplicate in 08-workspaces.sh
# (F-0121 Part B) was removed by F-0124.
# =============================================================================

# wait_for_user_session: blocks until the user PAM session and D-Bus user bus
# are both available, or until WAIT_TIMEOUT seconds elapse.
# Returns 0 on success (session ready), 1 on timeout.
# Always fail-open: caller handles the timeout case.
WAIT_TIMEOUT=120
WAIT_POLL=2

wait_for_user_session() {
    local elapsed=0
    log "F-0121: Waiting for user session (user@1000.service + D-Bus) — timeout ${WAIT_TIMEOUT}s ..."

    while [ "$elapsed" -lt "$WAIT_TIMEOUT" ]; do
        # Condition 1: PAM/NSS can resolve the user entry and open a session
        local runuser_ok=0
        if runuser -u "$USER" -- true >/dev/null 2>&1; then
            runuser_ok=1
        fi

        # Condition 2: D-Bus session bus socket is reachable.
        # Only probe once runuser succeeds (no point probing D-Bus if PAM
        # cannot resolve the user entry yet).
        # IMPORTANT: the probe MUST run as uid 1000 (via runuser), NOT as root.
        # The session bus at unix:path=/run/user/1000/bus uses SO_PEERCRED /
        # EXTERNAL SASL auth and rejects connections from uid 0.  Running
        # dbus-send directly as root always fails here even when the bus is up.
        local dbus_ok=0
        if [ "$runuser_ok" -eq 1 ]; then
            if runuser -u "$USER" -- dbus-send \
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

        sleep "$WAIT_POLL"
        elapsed=$((elapsed + WAIT_POLL))
    done

    log "F-0121: WARNING — user session NOT ready after ${WAIT_TIMEOUT}s; skipping all app updates to avoid silent failures"
    return 1
}

# Wait for session readiness before any runuser operation.
# Fail-open: if timed out, skip updates and exit cleanly.
if ! wait_for_user_session; then
    log "=== App update SKIPPED — user session not ready (all updates will be retried on next boot) ==="
    exit 0
fi

log "User session confirmed ready — proceeding with app updates"

# F-0116: Antigravity IDE apt upgrade removed.
# The "antigravity" apt package (IDE, /usr/bin/antigravity) is no longer
# installed — it shared app_id="antigravity" with the Hub and caused sway
# placement collisions. No apt operations needed here for Antigravity.

# =============================================================================
# F-0136: Install Antigravity IDE v2 (one-time tarball install)
#
# Downloads Antigravity IDE v2 from the official release URL, extracts to
# ~/.local/share/antigravity-ide/, creates a symlink at ~/.local/bin/antigravity-ide,
# and creates a .desktop file for app launcher integration.
# Only runs if the install directory does not already exist (one-time install).
#
# Tarball extracts to "Antigravity IDE/" with binary "antigravity-ide" inside.
# app_id (Wayland) = "antigravity-ide" (from product.json applicationName).
# =============================================================================
log "F-0136: Installing Antigravity IDE v2..."
IDE_INSTALL_DIR="$HOME_DIR/.local/share/antigravity-ide"
IDE_SYMLINK="$HOME_DIR/.local/bin/antigravity-ide"
IDE_DESKTOP="$HOME_DIR/.local/share/applications/antigravity-ide.desktop"
IDE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.0.4-6381998290370560/linux-x64/Antigravity%20IDE.tar.gz"
IDE_TEMP="/tmp/antigravity-ide-v2-download.tar.gz"

if [ ! -d "$IDE_INSTALL_DIR" ]; then
    log "Antigravity IDE v2 not found — downloading and extracting..."
    runuser -u $USER -- mkdir -p "$HOME_DIR/.local/share" "$HOME_DIR/.local/bin" "$HOME_DIR/.local/share/applications"
    if runuser -u $USER -- curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 30 -o "$IDE_TEMP" "$IDE_URL" >> "$LOG_FILE" 2>&1; then
        if runuser -u $USER -- tar -xzf "$IDE_TEMP" -C "$HOME_DIR/.local/share/" >> "$LOG_FILE" 2>&1; then
            # Tarball extracts to "Antigravity IDE/" — rename to standard install dir
            runuser -u $USER -- mv "$HOME_DIR/.local/share/Antigravity IDE" "$IDE_INSTALL_DIR" 2>/dev/null || true
            rm -f "$IDE_TEMP"
            log "Antigravity IDE v2: downloaded and extracted — OK"
        else
            log "Antigravity IDE v2: extraction FAILED (rc=$?) — check $LOG_FILE for details"
            rm -f "$IDE_TEMP"
        fi
    else
        log "Antigravity IDE v2: download FAILED (rc=$?) — check $LOG_FILE for details"
        rm -f "$IDE_TEMP"
    fi
else
    log "Antigravity IDE v2: already installed at $IDE_INSTALL_DIR — OK"
fi

# Deploy wrapper script and .desktop file if the installation directory exists
if [ -d "$IDE_INSTALL_DIR" ]; then
    # Create wrapper script at $IDE_SYMLINK to automatically handle display/ozone/GPU configurations
    runuser -u $USER -- tee "$IDE_SYMLINK" > /dev/null <<'WRAPPER_EOF'
#!/bin/bash
# Wrapper for Antigravity IDE v2 to automatically inject ozone and GPU flags,
# and resolve active Sway session environment (so it works from SSH/tmux).

# Detect active Sway session socket and display (similar to 08-workspaces.sh)
DETECTED_SOCK=""
DETECTED_DISPLAY="wayland-1"

# Try to find the CRD session socket first (must have X11-1 output)
for sock in /run/user/1000/sway-ipc.1000.*.sock; do
    [ -S "$sock" ] || continue
    if SWAYSOCK="$sock" /home/user/.nix-profile/bin/swaymsg -t get_outputs 2>/dev/null | grep -q 'X11-1'; then
        DETECTED_SOCK="$sock"
        pid=$(basename "$sock" | cut -d. -f3)
        lock_file=$(ls -la /proc/$pid/fd/ 2>/dev/null | grep -o 'wayland-[0-9]\+\.lock' | head -n1 || true)
        if [ -n "$lock_file" ]; then
            DETECTED_DISPLAY="${lock_file%.lock}"
        fi
        break
    fi
done

# If no CRD socket found, try fallback
if [ -z "$DETECTED_SOCK" ]; then
    fallback_sock=$(ls /run/user/1000/sway-ipc.1000.*.sock 2>/dev/null | head -n1 || true)
    if [ -n "$fallback_sock" ]; then
        DETECTED_SOCK="$fallback_sock"
        pid=$(basename "$fallback_sock" | cut -d. -f3)
        lock_file=$(ls -la /proc/$pid/fd/ 2>/dev/null | grep -o 'wayland-[0-9]\+\.lock' | head -n1 || true)
        if [ -n "$lock_file" ]; then
            DETECTED_DISPLAY="${lock_file%.lock}"
        fi
    fi
fi

if [ -n "$DETECTED_SOCK" ]; then
    export SWAYSOCK="${SWAYSOCK:-$DETECTED_SOCK}"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-$DETECTED_DISPLAY}"
fi
export XDG_RUNTIME_DIR=/run/user/1000

exec env -u LD_LIBRARY_PATH /home/user/.local/share/antigravity-ide/antigravity-ide \
    --ozone-platform=wayland \
    --disable-gpu \
    --disable-dev-shm-usage \
    "$@"
WRAPPER_EOF
    runuser -u $USER -- chmod +x "$IDE_SYMLINK"

    # Create .desktop file for app launcher integration
    runuser -u $USER -- tee "$IDE_DESKTOP" > /dev/null <<'DESKTOP_EOF'
[Desktop Entry]
Name=Antigravity IDE
Comment=Antigravity IDE v2 — AI-powered development environment
Exec=/home/user/.local/bin/antigravity-ide %F
Icon=/home/user/.local/share/antigravity-ide/resources/app/resources/linux/code.png
Type=Application
Categories=Development;IDE;
Terminal=false
StartupWMClass=antigravity-ide
DESKTOP_EOF
    log "Antigravity IDE v2: wrapper and .desktop deployed/updated"
fi

# --- Install/update Antigravity 2.0 Desktop App (Hub) ---
# NOTE: URL version 2.0.10-5119448496078848 is hardcoded. Update this URL when a
# new version of antigravity-hub is released.
log "Installing/updating Antigravity 2.0 Desktop App (Hub)..."
HUB_INSTALL_DIR="$HOME_DIR/.local/share/antigravity-hub"
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
            log "Antigravity Hub: downloaded, extracted, and symlinked — OK"
        else
            log "Antigravity Hub: extraction FAILED (rc=$?) — check $LOG_FILE for details"
            rm -f "$HUB_TEMP"
        fi
    else
        log "Antigravity Hub: download FAILED (rc=$?) — check $LOG_FILE for details"
        rm -f "$HUB_TEMP"
    fi
else
    log "Antigravity Hub: already installed at $HUB_INSTALL_DIR — OK (no download needed)"
fi

log "Extracting Antigravity Hub tray icon..."
runuser -u $USER -- bash -c "cd \"$HUB_INSTALL_DIR\" && npx -y asar extract-file resources/app.asar icon.png" >> "$LOG_FILE" 2>&1 || true

# Deploy the desktop file to ~/.local/share/applications/antigravity.desktop
runuser -u $USER -- tee "$HOME_DIR/.local/share/applications/antigravity.desktop" > /dev/null <<'DESKTOP_EOF'
[Desktop Entry]
Name=Antigravity Hub
Comment=Antigravity 2.0 Desktop App (Hub)
Exec=/home/user/.local/bin/antigravity-hub
Icon=/home/user/.local/share/antigravity-hub/icon.png
Type=Application
Categories=Development;
Terminal=false
StartupWMClass=antigravity
DESKTOP_EOF

# --- Update npm global packages (Claude Code, Gemini CLI) ---
# F-0121: check exit status; log real success or failure (no unconditional "complete").
log "Updating npm global packages..."
if runuser -u $USER -- bash -c ". $NIX_SH && export NPM_CONFIG_PREFIX=$HOME_DIR/.npm-global && npm update -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex @sourcegraph/cody @mariozechner/pi-coding-agent" >> "$LOG_FILE" 2>&1; then
    log "npm global packages: update OK"
else
    log "npm global packages: update FAILED (rc=$?) — check $LOG_FILE for details"
fi

# --- Install/update Antigravity CLI ---
# F-0121: check exit status; log real success or failure.
log "Installing/updating Antigravity CLI..."
if [ ! -d "$HOME_DIR/.gemini/antigravity-cli" ]; then
    log "Antigravity CLI not initialized — installing..."
    if runuser -u $USER -- bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash" >> "$LOG_FILE" 2>&1; then
        log "Antigravity CLI: installed OK"
    else
        log "Antigravity CLI: install FAILED (rc=$?) — check $LOG_FILE for details"
    fi
else
    log "Antigravity CLI found — updating..."
    if runuser -u $USER -- bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash" >> "$LOG_FILE" 2>&1; then
        log "Antigravity CLI: updated OK"
    else
        log "Antigravity CLI: update FAILED (rc=$?) — check $LOG_FILE for details"
    fi
fi

# --- Update OpenCode (Go binary) ---
# F-0121: check exit status; log real success or failure.
log "Updating OpenCode..."
if runuser -u $USER -- bash -c "export GOROOT=$HOME_DIR/go && export GOPATH=$HOME_DIR/gopath && export PATH=\$GOROOT/bin:\$GOPATH/bin:\$PATH && go install github.com/opencode-ai/opencode@latest" >> "$LOG_FILE" 2>&1; then
    log "OpenCode: update OK"
else
    log "OpenCode: update FAILED (rc=$?) — check $LOG_FILE for details"
fi

# --- Update Nix channel + Home Manager (VSCode, IntelliJ, etc.) ---
# F-0121: check exit status; log real success or failure.
log "Updating Nix channel and Home Manager..."
if runuser -u $USER -- bash -c ". $NIX_SH && nix-channel --update && home-manager switch" >> "$LOG_FILE" 2>&1; then
    log "Nix/Home Manager: update OK"
else
    log "Nix/Home Manager: update FAILED (rc=$?) — check $LOG_FILE for details"
fi

log "=== App update complete ==="
