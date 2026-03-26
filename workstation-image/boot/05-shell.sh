#!/bin/bash
# =============================================================================
# 05-shell.sh — ZSH default shell + plugins (no plugin manager)
# =============================================================================
# Sets ZSH as default shell via exec in .bashrc.
# Installs zsh-syntax-highlighting and zsh-autosuggestions via git clone.
# Creates .zshrc with Nix profile, PATH, plugins, and Starship init.
# =============================================================================

USER="user"
HOME_DIR="/home/user"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [05-shell] $1"; }

# --- Make ZSH default via .bashrc exec ---
BASHRC="$HOME_DIR/.bashrc"
if ! grep -q 'exec zsh' "$BASHRC" 2>/dev/null; then
    # Add exec zsh at the end of .bashrc (only in interactive shells)
    cat >> "$BASHRC" << 'BASHEOF'

# Launch ZSH as default shell (chsh may not work in container)
if [ -x "$HOME/.nix-profile/bin/zsh" ] && [ -z "$ZSH_VERSION" ]; then
    exec "$HOME/.nix-profile/bin/zsh"
fi
BASHEOF
    chown $USER:$USER "$BASHRC"
    log "Added ZSH exec to .bashrc"
else
    log "ZSH exec already in .bashrc — skipping"
fi

# --- Clone ZSH plugins ---
ZSH_DIR="$HOME_DIR/.zsh"
runuser -u $USER -- mkdir -p "$ZSH_DIR"

if [ ! -d "$ZSH_DIR/zsh-syntax-highlighting" ]; then
    runuser -u $USER -- git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_DIR/zsh-syntax-highlighting" 2>&1
    log "Cloned zsh-syntax-highlighting"
else
    log "zsh-syntax-highlighting already installed"
fi

if [ ! -d "$ZSH_DIR/zsh-autosuggestions" ]; then
    runuser -u $USER -- git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_DIR/zsh-autosuggestions" 2>&1
    log "Cloned zsh-autosuggestions"
else
    log "zsh-autosuggestions already installed"
fi

# --- Create .zshrc ---
ZSHRC="$HOME_DIR/.zshrc"
cat > "$ZSHRC" << 'ZSHEOF'
# =============================================================================
# ZSH Configuration — Cloud Workstation
# =============================================================================

# Nix profile
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# PATH additions
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/var/lib/nvidia/bin:$PATH"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# Key bindings (emacs mode)
bindkey -e

# Completion
autoload -Uz compinit && compinit -u

# ZSH plugins (no plugin manager — plain git clones)
if [ -f "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

if [ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Source ~/.env (Vertex AI config for Claude Code, etc.)
if [ -f "$HOME/.env" ]; then
    set -a
    source "$HOME/.env"
    set +a
fi

# Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
ZSHEOF
chown $USER:$USER "$ZSHRC"
log "Created .zshrc"
