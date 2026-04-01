#!/bin/bash
# =============================================================================
# 06a-tailscale.sh — Tailscale VPN (opt-in via TAILSCALE_AUTHKEY in ~/.env)
# =============================================================================
# If TAILSCALE_AUTHKEY is set in ~/.env, starts tailscaled and authenticates.
# If not set, skips silently. State persisted to ~/.tailscale/ for reconnection.
# =============================================================================

USER="user"
HOME_DIR="/home/user"
ENV_FILE="$HOME_DIR/.env"
STATE_DIR="$HOME_DIR/.tailscale"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [06a-tailscale] $1"; }

# Check if TAILSCALE_AUTHKEY is configured
if [ -f "$ENV_FILE" ] && grep -q "TAILSCALE_AUTHKEY" "$ENV_FILE" 2>/dev/null; then
    AUTHKEY=$(grep "^TAILSCALE_AUTHKEY=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ -z "$AUTHKEY" ]; then
        log "TAILSCALE_AUTHKEY is empty in ~/.env — skipping"
        exit 0
    fi
else
    log "No TAILSCALE_AUTHKEY in ~/.env — Tailscale disabled (opt-in)"
    exit 0
fi

log "TAILSCALE_AUTHKEY found — starting Tailscale"

# Ensure state directory exists on persistent disk
runuser -u $USER -- mkdir -p "$STATE_DIR"

# Start tailscaled if not already running
if ! pgrep -x tailscaled >/dev/null 2>&1; then
    tailscaled --state="$STATE_DIR/tailscaled.state" --socket=/var/run/tailscale/tailscaled.sock &
    disown
    sleep 3
    log "tailscaled started"
else
    log "tailscaled already running"
fi

# Check if already connected
if tailscale status >/dev/null 2>&1; then
    IP=$(tailscale ip -4 2>/dev/null)
    log "Tailscale already connected: $IP — skipping auth"
    exit 0
fi

# Authenticate and connect with SSH enabled
tailscale up --ssh --authkey="$AUTHKEY" --hostname="cloud-ws-$(hostname -s)" 2>&1
if tailscale status >/dev/null 2>&1; then
    IP=$(tailscale ip -4 2>/dev/null)
    log "Tailscale connected: $IP"
else
    log "WARNING: Tailscale failed to connect"
fi
