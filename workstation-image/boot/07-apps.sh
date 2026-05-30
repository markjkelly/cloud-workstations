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
# F-0121: Wait for the user session to be fully ready before running any
# runuser commands.
#
# ROOT CAUSE (confirmed 2026-05-29): 07-apps.sh runs at boot+32s via setup.sh.
# user@1000.service (the systemd user manager, which brings up NSS/PAM
# infrastructure) only starts at boot+115s.  Until then, getent passwd user
# cannot resolve the "user" entry and every "runuser -u user -- ..." call
# fails with:
#   runuser: user user does not exist or the user entry does not contain
#            all the required fields
# The scripts previously logged "... complete" unconditionally after each
# failing runuser, so all app updates appeared to succeed when they never ran.
#
# STRATEGY: poll until BOTH conditions hold or 120s elapses (fail-open).
#   1. runuser -u user -- true  → 0 (PAM can open a user session)
#   2. dbus-send probe on unix:path=/run/user/1000/bus  → 0 (D-Bus bus is up)
#
# dbus-send, busctl, and gdbus are all confirmed present on this Ubuntu 24.04
# base (verified 2026-05-29).  We use dbus-send as the primary probe.
#
# If the wait times out, we log a WARNING and SKIP all update steps — never
# attempt runuser into a broken session (that was the old behavior and caused
# every update to silently fail).
#
# SHARED HELPER NOTE: wait_for_user_session is also defined in
# 08-workspaces.sh (F-0121 Part B).  There is no shared sourced library in
# this boot script set, so the helper is duplicated in both scripts.  Both
# scripts run in different execution contexts (07-apps via setup.sh early in
# boot; 08-workspaces via ws-autolaunch.service after Sway is ready), and
# keeping them self-contained avoids source-order coupling.  The
# implementations are intentionally identical.
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

# --- Install/update GitHub Copilot CLI extension ---
# F-0121: check exit status; log real success or failure.
log "Updating GitHub Copilot CLI..."
if runuser -u $USER -- bash -c ". $NIX_SH && gh extension install github/gh-copilot 2>/dev/null || gh extension upgrade gh-copilot" >> "$LOG_FILE" 2>&1; then
    log "GitHub Copilot CLI: update OK"
else
    log "GitHub Copilot CLI: update FAILED (rc=$?) — check $LOG_FILE for details"
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
