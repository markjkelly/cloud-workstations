#!/bin/bash
# =============================================================================
# 03-sway.sh — Sway desktop + wayvnc systemd services
# =============================================================================
# Creates sway-desktop and wayvnc services on the ephemeral root disk.
# Disables TigerVNC to free port 5901 for wayvnc.
# noVNC stays enabled (proxies port 80 -> localhost:5901).
# =============================================================================

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [03-sway] $1"; }

# --- Create sway-desktop.service ---
cat > /etc/systemd/system/sway-desktop.service << 'EOF'
[Unit]
Description=Sway desktop (headless for wayvnc)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=user
PAMName=login
Environment=WLR_BACKENDS=headless
Environment=WLR_LIBINPUT_NO_DEVICES=1
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=XDG_SESSION_TYPE=wayland
Environment=LD_LIBRARY_PATH=/var/lib/nvidia/lib64
Environment=TZ=America/Chicago
ExecStartPre=/bin/mkdir -p /run/user/1000
ExecStartPre=/bin/chown user:user /run/user/1000
ExecStartPre=/bin/chmod 700 /run/user/1000
ExecStart=/home/user/.nix-profile/bin/sway
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
log "Created sway-desktop.service"

# --- Create wayvnc.service ---
cat > /etc/systemd/system/wayvnc.service << 'EOF'
[Unit]
Description=wayvnc VNC server for Sway
After=sway-desktop.service
Requires=sway-desktop.service

[Service]
Type=simple
User=user
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=WAYLAND_DISPLAY=wayland-1
ExecStartPre=/bin/sleep 3
ExecStart=/home/user/.nix-profile/bin/wayvnc --keyboard=us --output=HEADLESS-1 0.0.0.0 5901
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
log "Created wayvnc.service"

# --- Enable services ---
ln -sf /etc/systemd/system/sway-desktop.service /etc/systemd/system/multi-user.target.wants/
ln -sf /etc/systemd/system/wayvnc.service /etc/systemd/system/multi-user.target.wants/
log "Enabled sway-desktop and wayvnc services"

# --- Create ws-autolaunch.service (launches apps on workspaces after Sway) ---
cat > /etc/systemd/system/ws-autolaunch.service << 'EOF'
[Unit]
Description=Auto-launch apps on Sway workspaces
After=wayvnc.service chrome-remote-desktop@user.service
Wants=chrome-remote-desktop@user.service
Requires=sway-desktop.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 5
ExecStart=/bin/bash /home/user/boot/08-workspaces.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/ws-autolaunch.service /etc/systemd/system/multi-user.target.wants/
log "Created ws-autolaunch.service (runs 08-workspaces.sh after Sway)"

# --- F-0123: Enable user linger so user@1000.service starts at boot ---
# Without linger, user@1000.service only starts when the user logs in interactively.
# ws-app-updates.service is ordered After=user@1000.service; without linger, that
# service would block indefinitely (or not start at all) on a non-interactive boot.
# loginctl enable-linger is idempotent — safe to call on every boot.
#
# F-0123 FOLLOW-UP FIX (linger fallback — 2026-06-02):
# The original call used "2>/dev/null || log WARNING" which silently swallowed
# loginctl failures.  Linger must actually stick: if loginctl fails for any reason,
# we fall back to creating the linger marker file directly.  Both paths are logged
# loudly so any future failure is immediately visible in the boot log.
LINGER_FILE="/var/lib/systemd/linger/user"
LINGER_DIR="/var/lib/systemd/linger"
LINGER_ERR=$( { loginctl enable-linger user; } 2>&1 )
LINGER_RC=$?
if [ "$LINGER_RC" -eq 0 ]; then
    log "F-0123: loginctl enable-linger user OK (rc=0)"
else
    log "F-0123: WARNING — loginctl enable-linger user FAILED (rc=$LINGER_RC, stderr: $LINGER_ERR)"
    log "F-0123: Falling back to direct marker-file creation at $LINGER_FILE"
    mkdir -p "$LINGER_DIR" && touch "$LINGER_FILE" && \
        log "F-0123: Linger marker file created at $LINGER_FILE (fallback OK)" || \
        log "F-0123: CRITICAL — linger marker file creation FAILED — user@1000.service may not start at boot (check $LINGER_DIR)"
fi
# Verify linger actually took effect regardless of which path ran
if loginctl show-user user 2>/dev/null | grep -q 'Linger=yes'; then
    log "F-0123: Linger=yes confirmed for user"
elif [ -f "$LINGER_FILE" ]; then
    log "F-0123: Linger marker file present at $LINGER_FILE (loginctl show-user may not reflect yet — OK at this stage)"
else
    log "F-0123: CRITICAL — Linger not confirmed and marker file absent — app updates will be skipped on headless boots"
fi

# --- F-0123: Create ws-app-updates.service (runs 07-apps.sh after user session ready) ---
# This unit replaces the inline run of 07-apps.sh in setup.sh.  By ordering After=user@1000.service
# the OS guarantees the user session (PAM + D-Bus) is ready before 07-apps.sh runs.
# The wait_for_user_session helper in 07-apps.sh is kept as a defensive backstop only.
# Wants= (not Requires=) for user@1000.service avoids deadlocking on logind quirks.
cat > /etc/systemd/system/ws-app-updates.service << 'EOF'
[Unit]
Description=Update dev apps to latest versions on boot
After=user@1000.service network-online.target
Wants=user@1000.service network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /home/user/boot/07-apps.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/ws-app-updates.service /etc/systemd/system/multi-user.target.wants/
log "F-0123: Created ws-app-updates.service (runs 07-apps.sh after user@1000.service ready)"

# --- Create ws-boot-tests.service ---
cat > /etc/systemd/system/ws-boot-tests.service << 'EOF'
[Unit]
Description=Run boot verification tests after all services are up
After=ws-autolaunch.service
Requires=sway-desktop.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 30
ExecStart=/bin/bash /home/user/boot/10-tests.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/ws-boot-tests.service /etc/systemd/system/multi-user.target.wants/
log "Created ws-boot-tests.service (runs 10-tests.sh after Sway)"

# --- Disable and mask TigerVNC ---
rm -f /etc/systemd/system/multi-user.target.wants/tigervnc.service
# Must rm first — ln -sf fails on overlay fs with regular files
rm -f /etc/systemd/system/tigervnc.service
ln -s /dev/null /etc/systemd/system/tigervnc.service
pkill -f Xtigervnc 2>/dev/null || true
log "Disabled and masked TigerVNC (port 5901 now served by wayvnc)"

# --- Reload systemd and start services ---
systemctl daemon-reload
log "Reloaded systemd daemon"

# Start sway-desktop (wayvnc depends on it and will start after)
if [ -x /home/user/.nix-profile/bin/sway ]; then
    systemctl start sway-desktop || log "WARNING: sway-desktop failed to start (will retry on next boot)"
    # Give sway a moment to initialize before starting wayvnc
    sleep 2
    systemctl start wayvnc || log "WARNING: wayvnc failed to start (will retry on next boot)"
    log "Started sway-desktop and wayvnc services"
else
    log "WARNING: /home/user/.nix-profile/bin/sway not found — skipping service start (run home-manager switch first)"
fi

