#!/bin/bash
# =============================================================================
# 11-custom-tools.sh — Terraform, GitHub CLI, Java, Eclipse, fonts, systemd masks
# =============================================================================
# Installs tools not included in the upstream ameer00/cloud-workstations profile:
#   - Terraform (pinned version)
#   - GitHub CLI (official apt repo)
#   - Java LTS via SDKMAN
#   - Eclipse IDE for Java Developers
#   - JetBrains Mono font (for foot terminal)
# Also patches noVNC rfb.js and masks ws-autolaunch.service on every boot.
#
# Numbered 11- to run after all upstream boot scripts complete.
# Idempotent — safe to run on every boot.
# =============================================================================

set -euo pipefail

USER="user"
HOME_DIR="/home/user"
LOG_DIR="$HOME_DIR/logs"
LOG_FILE="$LOG_DIR/custom-tools.log"

TERRAFORM_VERSION="1.14.8"
# Temurin LTS — update this string when a new LTS ships; SDKMAN will validate.
JAVA_VERSION="21.0.5-tem"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [11-custom-tools] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

runuser -u $USER -- mkdir -p "$LOG_DIR"

log "=== Custom tools install started ==="

# =============================================================================
# Terraform
# =============================================================================
install_terraform() {
    local version="$TERRAFORM_VERSION"
    local arch
    arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
    [[ "$arch" == "x86_64" ]] && arch="amd64"

    if command -v terraform &>/dev/null; then
        local installed
        installed=$(terraform version -json 2>/dev/null \
            | grep -oP '(?<="terraform_version":")[^"]+' || true)
        if [[ "$installed" == "$version" ]]; then
            log "[Terraform] $version already installed — skipping"
            return
        fi
    fi

    log "[Terraform] Installing $version..."
    local url="https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_${arch}.zip"
    local tmp
    tmp=$(mktemp -d)
    trap "rm -rf '$tmp'" RETURN

    curl -fsSL "$url" -o "${tmp}/terraform.zip" >> "$LOG_FILE" 2>&1
    unzip -q "${tmp}/terraform.zip" -d "$tmp"
    install -o root -g root -m 0755 "${tmp}/terraform" /usr/local/bin/terraform

    log "[Terraform] Installed: $(terraform version 2>/dev/null | head -1)"
}

# =============================================================================
# GitHub CLI
# =============================================================================
install_gh() {
    if command -v gh &>/dev/null; then
        log "[gh] $(gh --version | head -1) already installed — skipping"
        return
    fi

    log "[gh] Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

    apt-get update -q >> "$LOG_FILE" 2>&1
    apt-get install -y gh >> "$LOG_FILE" 2>&1

    log "[gh] Installed: $(gh --version | head -1)"
}

# =============================================================================
# Java — via SDKMAN (installs to ~/.sdkman on the persistent /home disk)
# =============================================================================
install_java() {
    local sdkman_dir="$HOME_DIR/.sdkman"
    local sdkman_init="$sdkman_dir/bin/sdkman-init.sh"

    if [ -f "$sdkman_init" ] \
        && runuser -u $USER -- bash -c ". $sdkman_init && java -version" >> "$LOG_FILE" 2>&1; then
        local java_ver
        java_ver=$(runuser -u $USER -- bash -c \
            ". $sdkman_init && java -version 2>&1 | head -1")
        log "[Java] Already installed: $java_ver — skipping"
        return
    fi

    log "[Java] Installing SDKMAN..."
    runuser -u $USER -- bash -c \
        "curl -fsSL https://get.sdkman.io | bash" >> "$LOG_FILE" 2>&1
    log "[Java] SDKMAN installed"

    log "[Java] Installing Java $JAVA_VERSION (Temurin LTS)..."
    runuser -u $USER -- bash -c "
        . $sdkman_init
        sdk install java $JAVA_VERSION
        sdk default java $JAVA_VERSION
    " >> "$LOG_FILE" 2>&1

    local java_ver
    java_ver=$(runuser -u $USER -- bash -c \
        ". $sdkman_init && java -version 2>&1 | head -1")
    log "[Java] Installed: $java_ver"
}

# =============================================================================
# Eclipse IDE for Java Developers
# =============================================================================
install_eclipse() {
    local eclipse_dir="$HOME_DIR/eclipse"

    if [ -x "$eclipse_dir/eclipse" ]; then
        log "[Eclipse] Already installed at $eclipse_dir — skipping"
        return
    fi

    log "[Eclipse] Downloading Eclipse IDE for Java Developers..."
    local eclipse_version="2024-12"
    local eclipse_pkg="eclipse-java-${eclipse_version}-R-linux-gtk-x86_64.tar.gz"
    # Direct download link (bypasses mirror redirect)
    local eclipse_url="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/${eclipse_version}/R/${eclipse_pkg}&r=1"
    local tmp
    tmp=$(mktemp -d)
    trap "rm -rf '$tmp'" RETURN

    curl -fsSL -o "${tmp}/${eclipse_pkg}" "$eclipse_url" >> "$LOG_FILE" 2>&1
    tar -xzf "${tmp}/${eclipse_pkg}" -C "$tmp" >> "$LOG_FILE" 2>&1
    mv "${tmp}/eclipse" "$eclipse_dir"
    chown -R "$USER:$USER" "$eclipse_dir"

    # Desktop launcher
    runuser -u $USER -- mkdir -p "$HOME_DIR/.local/share/applications"
    cat > "$HOME_DIR/.local/share/applications/eclipse.desktop" << 'DESKTOP'
[Desktop Entry]
Name=Eclipse IDE
Comment=Eclipse IDE for Java Developers
Exec=/home/user/eclipse/eclipse
Icon=/home/user/eclipse/icon.xpm
Terminal=false
Type=Application
Categories=Development;IDE;Java;
DESKTOP
    chown "$USER:$USER" "$HOME_DIR/.local/share/applications/eclipse.desktop"

    log "[Eclipse] Installed at $eclipse_dir"
}

# =============================================================================
# JetBrains Mono font
# =============================================================================
install_jetbrains_mono() {
    if fc-list | grep -qi "JetBrains Mono"; then
        log "[fonts] JetBrains Mono already installed — skipping"
        return
    fi
    log "[fonts] Installing fonts-jetbrains-mono..."
    apt-get install -y fonts-jetbrains-mono >> "$LOG_FILE" 2>&1
    fc-cache -f >> "$LOG_FILE" 2>&1
    log "[fonts] JetBrains Mono installed"
}

# =============================================================================
# Patch noVNC — disable QEMU extended key events
# =============================================================================
# noVNC 1.5+ and wayvnc 0.9.1 negotiate QEMU Extended Key Events pseudo-encoding.
# This causes the main Enter key to be sent with unexpected modifier state,
# producing garbage escape sequences (e.g. ";9;13~;") in foot terminal.
# Numpad Enter is unaffected (different XKB scancode path).
# Fix: remove the encoding from noVNC's advertised list so it falls back to
# standard RFB key events, which wayvnc handles correctly.
patch_novnc() {
    local rfb="/opt/noVNC/core/rfb.js"
    if [ ! -f "$rfb" ]; then
        log "[novnc] $rfb not found — skipping patch"
        return
    fi
    if grep -q "DISABLED: QEMU ext key events" "$rfb"; then
        log "[novnc] rfb.js already patched — skipping"
        return
    fi
    local line
    line=$(grep -n "encs.push(encodings.pseudoEncodingQEMUExtendedKeyEvent)" "$rfb" | cut -d: -f1)
    if [ -z "$line" ]; then
        log "[novnc] QEMU extended key event line not found — skipping patch"
        return
    fi
    sed -i "${line}s/.*/        \/\/ DISABLED: QEMU ext key events break main Enter with wayvnc\/\/ encs.push(encodings.pseudoEncodingQEMUExtendedKeyEvent);/" "$rfb"
    log "[novnc] Patched rfb.js line $line — QEMU extended key events disabled"
}

# =============================================================================
# Mask ws-autolaunch.service — disable workspace auto-launch
# =============================================================================
# 03-sway.sh creates ws-autolaunch.service and enables it via a symlink into
# multi-user.target.wants/ on every boot. Running this script after 03-sway.sh
# (guaranteed by the 11- numbering) overwrites it with a /dev/null mask,
# preventing 08-workspaces.sh from auto-launching apps into Sway workspaces.
mask_autolaunch() {
    ln -sf /dev/null /etc/systemd/system/ws-autolaunch.service
    rm -f /etc/systemd/system/multi-user.target.wants/ws-autolaunch.service
    log "[autolaunch] ws-autolaunch.service masked"
}

# --- Run ---
install_terraform
install_gh
install_java
install_eclipse
install_jetbrains_mono
patch_novnc
mask_autolaunch

log "=== Custom tools install complete ==="
