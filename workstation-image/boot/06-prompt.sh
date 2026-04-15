#!/bin/bash
# =============================================================================
# 06-prompt.sh — Starship prompt + foot terminal config
# =============================================================================
# Ensures Starship is available and configures foot terminal with
# DejaVu Sans Mono font and Tokyo Night color scheme.
# =============================================================================

USER="user"
HOME_DIR="/home/user"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [06-prompt] $1"; }

# --- Ensure Starship is available ---
STARSHIP_PATH="$HOME_DIR/.nix-profile/bin/starship"
if [ ! -x "$STARSHIP_PATH" ]; then
    STARSHIP_PATH="$HOME_DIR/.local/bin/starship"
    if [ ! -x "$STARSHIP_PATH" ]; then
        log "Installing Starship via curl..."
        runuser -u $USER -- mkdir -p "$HOME_DIR/.local/bin"
        runuser -u $USER -- bash -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"' 2>&1
        log "Starship installed to $HOME_DIR/.local/bin/starship"
    fi
fi
log "Starship available at: $(which starship 2>/dev/null || echo "$STARSHIP_PATH")"

# --- Create foot terminal config ---
# Source of truth: workstation-image/configs/foot/foot.ini in the repo,
# deployed to ~/boot/foot.ini by scripts/cloud-build-setup.sh. We copy it
# into place on every boot. An embedded heredoc is kept as a fallback so
# a workstation whose ~/boot/foot.ini is missing (e.g. partial upgrade)
# still gets a valid, monospace-resolving config rather than silently
# keeping a stale one. See F-0094.
FOOT_DIR="$HOME_DIR/.config/foot"
FOOT_INI="$FOOT_DIR/foot.ini"
FOOT_INI_SRC="$HOME_DIR/boot/foot.ini"
runuser -u $USER -- mkdir -p "$FOOT_DIR"

if [ -f "$FOOT_INI_SRC" ] && grep -q '^font=' "$FOOT_INI_SRC"; then
    install -m 0644 -o $USER -g $USER "$FOOT_INI_SRC" "$FOOT_INI"
    log "Deployed foot.ini from $FOOT_INI_SRC (repo source of truth)"
else
    cat > "$FOOT_INI" << 'EOF'
# foot terminal — Cloud Workstation (fallback; repo copy was missing)
# Tokyo Night theme with DejaVu Sans Mono font

[main]
font=DejaVu Sans Mono:size=14
dpi-aware=no
pad=8x8

[scrollback]
lines=10000

[colors-dark]
background=1a1b26
foreground=c0caf5
regular0=15161e
regular1=f7768e
regular2=9ece6a
regular3=e0af68
regular4=7aa2f7
regular5=bb9af7
regular6=7dcfff
regular7=a9b1d6
bright0=414868
bright1=f7768e
bright2=9ece6a
bright3=e0af68
bright4=7aa2f7
bright5=bb9af7
bright6=7dcfff
bright7=c0caf5

[key-bindings]
clipboard-copy=Control+Shift+c
clipboard-paste=Control+Shift+v

[tweak]
EOF
    log "WARNING: $FOOT_INI_SRC missing; wrote embedded fallback foot.ini"
fi
chown -R $USER:$USER "$FOOT_DIR"

# --- Deploy Starship config ---
STARSHIP_CONF="$HOME_DIR/.config/starship.toml"
runuser -u $USER -- mkdir -p "$HOME_DIR/.config"
cat > "$STARSHIP_CONF" << 'EOF'
[git_branch]
symbol = "git:"
EOF
chown $USER:$USER "$STARSHIP_CONF"
log "Deployed starship.toml (plain-text git branch symbol)"
