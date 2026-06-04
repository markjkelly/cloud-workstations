#!/bin/bash
# =============================================================================
# 10-tests.sh — Post-boot verification of all Cloud Workstation features
# =============================================================================
# Runs after all setup scripts. Tests every feature and saves results.
# Results: ~/logs/boot-test-results.txt (full) + ~/logs/boot-test-summary.txt (one-line)
# =============================================================================

USER="user"
HOME_DIR="/home/user"
LOG_DIR="$HOME_DIR/logs"
RESULTS="$LOG_DIR/boot-test-results.txt"
SUMMARY="$LOG_DIR/boot-test-summary.txt"
NIX_SH="$HOME_DIR/.nix-profile/etc/profile.d/nix.sh"

PASS=0; FAIL=0; WARN=0; SKIP=0

# Source Nix for this script context
if [ -f "$NIX_SH" ]; then
    . "$NIX_SH"
fi

# Source module helper for composable install gating
WS_MODULES_HELPER="$HOME_DIR/.local/bin/ws-modules.sh"
if [ -f "$WS_MODULES_HELPER" ]; then
    . "$WS_MODULES_HELPER"
else
    ws_module_enabled() { return 0; }  # fallback: all enabled
fi

runuser -u $USER -- mkdir -p "$LOG_DIR"

log() { echo "$1" | tee -a "$RESULTS"; }

test_pass() { PASS=$((PASS+1)); log "  PASS: $1"; }
test_fail() { FAIL=$((FAIL+1)); log "  FAIL: $1"; }
test_warn() { WARN=$((WARN+1)); log "  WARN: $1"; }
test_skip() { SKIP=$((SKIP+1)); log "  SKIP: $1"; }

check_binary() {
    local name="$1" bin="$2"
    if runuser -u $USER -- bash -c ". $NIX_SH && export PATH=$HOME_DIR/.nix-profile/bin:$HOME_DIR/.npm-global/bin:$HOME_DIR/.local/bin:$HOME_DIR/gopath/bin:$HOME_DIR/go/bin:$HOME_DIR/.cargo/bin:$HOME_DIR/.pyenv/bin:$HOME_DIR/.rbenv/bin:/var/lib/nvidia/bin:\$PATH && which $bin" >/dev/null 2>&1; then
        test_pass "$name ($bin)"
    else
        test_fail "$name ($bin not found)"
    fi
}

check_file() {
    local name="$1" path="$2"
    if [ -f "$path" ]; then
        test_pass "$name"
    else
        test_fail "$name ($path missing)"
    fi
}

check_dir() {
    local name="$1" path="$2"
    if [ -d "$path" ]; then
        test_pass "$name"
    else
        test_fail "$name ($path missing)"
    fi
}

check_grep() {
    local name="$1" pattern="$2" file="$3"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        test_pass "$name"
    else
        test_fail "$name (pattern '$pattern' not in $file)"
    fi
}

check_process() {
    local name="$1" pattern="$2"
    if pgrep -f "$pattern" >/dev/null 2>&1; then
        test_pass "$name running"
    else
        test_warn "$name not running (may start later)"
    fi
}

check_version() {
    local name="$1" cmd="$2"
    local ver=$(runuser -u $USER -- bash -c ". $NIX_SH && export PATH=$HOME_DIR/.nix-profile/bin:$HOME_DIR/.npm-global/bin:$HOME_DIR/.local/bin:$HOME_DIR/gopath/bin:$HOME_DIR/go/bin:$HOME_DIR/.cargo/bin:$HOME_DIR/.pyenv/bin:$HOME_DIR/.rbenv/bin:/var/lib/nvidia/bin:\$PATH && $cmd" 2>&1 | grep -viE "^[0-9]+/[0-9].*WARN |^WARNING" | head -1)
    if [ -n "$ver" ] && ! echo "$ver" | grep -qiE "not found|error|command not found"; then
        test_pass "$name version: $ver"
    else
        test_fail "$name version check failed"
    fi
}

# Start fresh results
echo "========================================" > "$RESULTS"
echo "Cloud Workstation Boot Test Results" >> "$RESULTS"
echo "Date: $(TZ=America/Los_Angeles date)" >> "$RESULTS"
echo "========================================" >> "$RESULTS"
echo "" >> "$RESULTS"

# =============================================================================
# IDEs
# =============================================================================
if ws_module_enabled "ides"; then
    log "--- IDEs ---"
    check_binary "VSCode" "code"
    check_version "VSCode" "code --version"
else
    log "--- IDEs --- (SKIPPED — module disabled)"
    test_skip "IDEs (module disabled)"
fi

# tmux (separate module)
if ws_module_enabled "tmux"; then
    check_binary "tmux" "tmux"
else
    log "--- tmux --- (SKIPPED — module disabled)"
    test_skip "tmux (module disabled)"
fi

# =============================================================================
# Antigravity Tools
# =============================================================================
log ""
log "--- Antigravity Tools ---"
# F-0116: Antigravity IDE (/usr/bin/antigravity) removed — assert it is ABSENT.
if [ ! -f "/usr/bin/antigravity" ]; then
    test_pass "Antigravity IDE absent (/usr/bin/antigravity not present — F-0116)"
else
    test_fail "Antigravity IDE still present at /usr/bin/antigravity (should be removed — F-0116)"
fi
check_dir "Antigravity CLI config" "$HOME_DIR/.gemini/antigravity-cli"
check_dir "Antigravity Hub directory" "$HOME_DIR/.local/share/antigravity-hub"
check_file "Antigravity Hub symlink" "$HOME_DIR/.local/bin/antigravity-hub"
# F-0125: Orphaned IDE dirs must be absent (cleaned by 07-apps.sh on every boot).
# Also assert Hub and CLI dirs are still present (over-deletion guard).
if [ ! -e "$HOME_DIR/.config/Antigravity" ] || [ ! -f "/usr/bin/antigravity" ]; then
    test_pass "IDE userData dir absent or not owned by IDE (~/.config/Antigravity — F-0125)"
else
    test_fail "IDE userData dir still present at ~/.config/Antigravity and IDE binary exists (F-0125)"
fi
if ls "$HOME_DIR"/.config/Antigravity.bak.* >/dev/null 2>&1; then
    test_fail "IDE userData backup(s) still present at ~/.config/Antigravity.bak.* (07-apps.sh cleanup did not run — F-0125)"
else
    test_pass "IDE userData backups absent (~/.config/Antigravity.bak.* cleaned — F-0125)"
fi
if [ ! -e "$HOME_DIR/.antigravity" ]; then
    test_pass "IDE extensions dir absent (~/.antigravity cleaned — F-0125)"
else
    test_fail "IDE extensions dir still present at ~/.antigravity (07-apps.sh cleanup did not run — F-0125)"
fi
if [ ! -e "$HOME_DIR/.cache/antigravity" ]; then
    test_pass "IDE cache dir absent (~/.cache/antigravity cleaned — F-0125)"
else
    test_fail "IDE cache dir still present at ~/.cache/antigravity (07-apps.sh cleanup did not run — F-0125)"
fi
# Over-deletion guard: Hub userData and CLI dirs MUST still be present
check_dir "Hub userData preserved after F-0125 cleanup (anti-over-delete)" "$HOME_DIR/.config/Antigravity-Hub"
check_dir "Antigravity CLI preserved after F-0125 cleanup (anti-over-delete)" "$HOME_DIR/.gemini/antigravity-cli"
# F-0116: IDE ws2 launch removed — assert the IDE launch block is absent
if grep -qE 'launch_and_wait[[:space:]]+2[[:space:]].*ANTIGRAVITY' "$HOME_DIR/boot/08-workspaces.sh"; then
    test_fail "08-workspaces.sh still launches IDE on ws2 via ANTIGRAVITY variable (F-0116 regression)"
else
    test_pass "08-workspaces.sh does NOT launch IDE on ws2 (F-0116)"
fi
# Negative check: --use-gl=swiftshader must not appear in any launch_and_wait call
if grep -qE 'launch_and_wait.*--use-gl=swiftshader' "$HOME_DIR/boot/08-workspaces.sh"; then
    test_fail "08-workspaces.sh still has --use-gl=swiftshader in a launch_and_wait call (F-0111)"
else
    test_pass "08-workspaces.sh has no --use-gl=swiftshader in launch_and_wait calls (F-0111)"
fi

# F-0115: gnome-keyring Secret Service for Hub OAuth token persistence.
# Verify the boot script handles keyring unlock robustly (F-0115):
#   (a) gnome-keyring-daemon started with --unlock (empty-password unlock)
#   (b) gnome-keyring-daemon started with --components=secrets
#   (c) DBUS_SESSION_BUS_ADDRESS exported to launched app processes
#   (d) D-Bus lock-state check for the login collection
#   (e) restart-on-locked logic (kill + restart if keyring is locked)
#   (f) final verification of daemon running + keyring unlocked
WS_SCRIPT_F0115="$HOME_DIR/boot/08-workspaces.sh"
if [ -f "$WS_SCRIPT_F0115" ]; then
    check_grep "Keyring: gnome-keyring-daemon started with --unlock (F-0115)" \
        'gnome-keyring-daemon --unlock' \
        "$WS_SCRIPT_F0115"
    check_grep "Keyring: gnome-keyring-daemon started with --components=secrets (F-0115)" \
        '\-\-components=secrets' \
        "$WS_SCRIPT_F0115"
    check_grep "Keyring: DBUS_SESSION_BUS_ADDRESS exported in launch_and_wait env (F-0115)" \
        'DBUS_SESSION_BUS_ADDRESS' \
        "$WS_SCRIPT_F0115"
    check_grep "Keyring: D-Bus lock-state check for login collection (F-0115)" \
        'org.freedesktop.Secret.Collection.*Locked' \
        "$WS_SCRIPT_F0115"
    check_grep "Keyring: restart-on-locked logic kills existing daemon (F-0115)" \
        'pkill.*gnome-keyring-daemon' \
        "$WS_SCRIPT_F0115"
    check_grep "Keyring: removes password-protected login.keyring before restart (F-0115)" \
        'rm.*KEYRING_FILE' \
        "$WS_SCRIPT_F0115"
else
    test_fail "08-workspaces.sh not found at $WS_SCRIPT_F0115 (F-0115 check)"
fi

# =============================================================================
# F-0124: Hub autostart removed — regression guards.
# These tests confirm that the dead autostart machinery was stripped and that
# the live language_server binary is the real ELF (not the F-0119/F-0120 shim).
# =============================================================================
log ""
log "--- F-0124: Hub autostart removed (regression guards) ---"

LS_BIN_PATH="$HOME_DIR/.local/share/antigravity-hub/resources/bin/language_server"
LS_REAL_PATH="${LS_BIN_PATH}.real"
WS_SCRIPT_F0124="$HOME_DIR/boot/08-workspaces.sh"

# (a) 08-workspaces.sh does NOT contain the Hub launch command (antigravity-hub invocation)
if [ -f "$WS_SCRIPT_F0124" ]; then
    if grep -qE '"?\$HUB"?[[:space:]]|antigravity-hub.*--no-sandbox|runuser.*antigravity-hub' "$WS_SCRIPT_F0124" 2>/dev/null; then
        test_fail "F-0124: 08-workspaces.sh still contains a Hub launch invocation (autostart not fully removed)"
    else
        test_pass "F-0124: 08-workspaces.sh does NOT launch the Hub (Hub autostart removed)"
    fi

    # (b) Dead diagnostic/shim functions must be absent
    if grep -qE '_f0119_install_ls_shim|_f0118_ls_diag_sampler|hub_language_server_ready' "$WS_SCRIPT_F0124" 2>/dev/null; then
        test_fail "F-0124: 08-workspaces.sh still contains removed function(s) (_f0119/_f0118/hub_language_server_ready)"
    else
        test_pass "F-0124: 08-workspaces.sh has no _f0119/_f0118/hub_language_server_ready functions (dead machinery removed)"
    fi

    # (c) Dead constants must be absent
    if grep -qE 'HUB_LAUNCH_TIMEOUT=|HUB_MAX_RETRIES=|HUB_LS_LOG=|HUB_LS_DIAG_LOG=|HUB_LS_DIAG_INTERVAL=' "$WS_SCRIPT_F0124" 2>/dev/null; then
        test_fail "F-0124: 08-workspaces.sh still has removed diagnostic constants (HUB_LAUNCH_TIMEOUT / HUB_MAX_RETRIES / etc.)"
    else
        test_pass "F-0124: 08-workspaces.sh has no dead diagnostic constants (F-0124 clean)"
    fi
else
    test_fail "F-0124: 08-workspaces.sh not found at $WS_SCRIPT_F0124"
fi

# (d) language_server is NOT the F-0119 shim — must be an ELF binary
if [ -f "$LS_BIN_PATH" ]; then
    if head -3 "$LS_BIN_PATH" 2>/dev/null | grep -qF "# F-0119 LS capture shim"; then
        test_fail "F-0124: language_server is still the F-0119 shim (live binary not restored — ELF expected)"
    else
        test_pass "F-0124: language_server does NOT contain the F-0119 shim marker (real binary)"
    fi
    # Also confirm it is executable
    if [ -x "$LS_BIN_PATH" ]; then
        test_pass "F-0124: language_server is executable"
    else
        test_fail "F-0124: language_server is NOT executable"
    fi
else
    test_warn "F-0124: language_server does not exist — Hub not installed on this workstation"
fi

# (e) language_server.real must NOT exist — shim has been fully unwound
if [ -f "$LS_REAL_PATH" ]; then
    test_fail "F-0124: language_server.real still exists — shim restore incomplete (mv to language_server may have failed)"
else
    test_pass "F-0124: language_server.real does not exist (shim fully restored — F-0124)"
fi

# ~/logs directory must still be writable
if runuser -u $USER -- bash -c "test -d '$HOME_DIR/logs' && test -w '$HOME_DIR/logs'" 2>/dev/null; then
    test_pass "F-0124: $HOME_DIR/logs exists and is writable"
else
    test_fail "F-0124: $HOME_DIR/logs missing or not writable"
fi

# =============================================================================
# AI CLI Tools
# =============================================================================
log ""
if ws_module_enabled "ai-tools"; then
    log "--- AI CLI Tools ---"
    check_binary "Claude Code" "claude"
    check_binary "OpenCode" "opencode"
    # GH Copilot (extension)
    if runuser -u $USER -- bash -c ". $NIX_SH && gh copilot --version" >/dev/null 2>&1; then
        test_pass "GH Copilot"
    else
        test_warn "GH Copilot (extension may not be installed)"
    fi
elif ws_module_enabled "ai-tools-minimal"; then
    log "--- AI CLI Tools (minimal) ---"
    check_binary "Claude Code" "claude"
    test_skip "OpenCode (ai-tools-minimal)"
    test_skip "GH Copilot (ai-tools-minimal)"
else
    log "--- AI CLI Tools --- (SKIPPED — module disabled)"
    test_skip "AI CLI Tools (module disabled)"
fi

# =============================================================================
# Languages
# =============================================================================
log ""
if ws_module_enabled "languages"; then
    log "--- Languages ---"
    check_binary "Go" "go"
    check_binary "Rust (rustc)" "rustc"
    check_binary "Cargo" "cargo"
    # Python (needs pyenv init)
    if runuser -u $USER -- bash -c "export PYENV_ROOT=$HOME_DIR/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && which python" >/dev/null 2>&1; then
        test_pass "Python (pyenv)"
    else
        test_fail "Python (pyenv not found)"
    fi
    # Ruby (needs rbenv init)
    if runuser -u $USER -- bash -c "export PATH=$HOME_DIR/.rbenv/bin:\$PATH && eval \"\$($HOME_DIR/.rbenv/bin/rbenv init -)\" && which ruby" >/dev/null 2>&1; then
        test_pass "Ruby (rbenv)"
    else
        test_fail "Ruby (rbenv not found)"
    fi
else
    log "--- Languages --- (SKIPPED — module disabled)"
    test_skip "Languages (module disabled)"
fi
# Node.js (via Nix — always part of base)
check_binary "Node.js" "node"
check_binary "npm" "npm"

# =============================================================================
# Nix
# =============================================================================
log ""
log "--- Nix ---"
if runuser -u $USER -- bash -c ". $NIX_SH && nix-env --version" >/dev/null 2>&1; then
    test_pass "nix-env works"
else
    test_fail "nix-env not working"
fi
if runuser -u $USER -- bash -c ". $NIX_SH && home-manager --version" >/dev/null 2>&1; then
    test_pass "home-manager available"
else
    test_fail "home-manager not available"
fi

# =============================================================================
# Config Files
# =============================================================================
log ""
log "--- Config Files ---"
# Desktop module configs
if ws_module_enabled "desktop"; then
    check_file "Wofi config" "$HOME_DIR/.config/wofi/config"
    check_file "Wofi style" "$HOME_DIR/.config/wofi/style.css"
    check_file "Snippet picker" "$HOME_DIR/.local/bin/snippet-picker"
    check_file "Snippets conf" "$HOME_DIR/.config/snippets/snippets.conf"
else
    test_skip "Wofi/Snippets configs (desktop module disabled)"
fi
# Core configs (always)
check_file "sway-status" "$HOME_DIR/.local/bin/sway-status"
# F-0122: hub-restart utility
HUB_RESTART_BIN="$HOME_DIR/.local/bin/hub-restart"
if [ -f "$HUB_RESTART_BIN" ]; then
    test_pass "F-0122: hub-restart present at ~/.local/bin/hub-restart"
    if [ -x "$HUB_RESTART_BIN" ]; then
        test_pass "F-0122: hub-restart is executable"
    else
        test_fail "F-0122: hub-restart exists but is not executable"
    fi
else
    test_fail "F-0122: hub-restart missing at ~/.local/bin/hub-restart"
fi
check_binary "hub-restart (on PATH)" "hub-restart"
check_file "Sway config" "$HOME_DIR/.config/sway/config"
check_file "foot.ini" "$HOME_DIR/.config/foot/foot.ini"
check_grep "foot font (monospace)" "DejaVu Sans Mono" "$HOME_DIR/.config/foot/foot.ini"

# F-0094: resolve foot's configured primary font through fontconfig to
# verify it actually lands on the intended monospace family. A bare
# content-grep is not enough — if the family name is misspelled or the
# font package is missing, fc-match silently falls back to Noto Sans and
# foot emits "font does not appear to be monospace" on every launch.
FOOT_FAMILY=$(grep -E '^font=' "$HOME_DIR/.config/foot/foot.ini" 2>/dev/null \
    | head -1 | sed -E 's/^font=([^:]+).*/\1/')
if [ -n "$FOOT_FAMILY" ]; then
    FC_MATCH=$(runuser -u $USER -- fc-match "$FOOT_FAMILY" 2>/dev/null)
    if echo "$FC_MATCH" | grep -qiE 'noto.*sans|^[^:]*[Ss]ans[^:]*:.*"[^"]*Sans[^M"]*"'; then
        test_fail "foot font fc-match falls back to Noto/Sans ($FOOT_FAMILY -> $FC_MATCH)"
    elif echo "$FC_MATCH" | grep -qi "$FOOT_FAMILY"; then
        test_pass "foot font fc-match resolves to $FOOT_FAMILY ($FC_MATCH)"
    else
        test_fail "foot font fc-match does not match family ($FOOT_FAMILY -> $FC_MATCH)"
    fi
    # spacing=mono must also resolve to the same family; otherwise foot
    # will warn about a non-monospace font even if the family name resolves.
    FC_MONO=$(runuser -u $USER -- fc-match "${FOOT_FAMILY}:spacing=mono" 2>/dev/null)
    if echo "$FC_MONO" | grep -qi "$FOOT_FAMILY"; then
        test_pass "foot font spacing=mono resolves ($FC_MONO)"
    else
        test_fail "foot font spacing=mono fallback ($FOOT_FAMILY -> $FC_MONO)"
    fi
else
    test_fail "foot.ini has no [main] font= line"
fi
# Tmux module configs
if ws_module_enabled "tmux"; then
    check_file "tmux.conf" "$HOME_DIR/.tmux.conf"
    # Verify tmux.conf syntax is valid
    if runuser -u $USER -- bash -c ". $NIX_SH && tmux -f $HOME_DIR/.tmux.conf start-server \\; kill-server" >/dev/null 2>&1; then
        test_pass "tmux.conf syntax valid"
    else
        test_fail "tmux.conf has syntax errors"
    fi
else
    test_skip "tmux.conf (tmux module disabled)"
fi
check_file ".zshrc" "$HOME_DIR/.zshrc"
if [ -f "$HOME_DIR/.env" ]; then
    test_pass ".env"
else
    test_warn ".env ($HOME_DIR/.env missing — expected if no secrets configured)"
fi
check_file "Chrome Remote Desktop" "/opt/google/chrome-remote-desktop/chrome-remote-desktop"
check_file "CRD session config" "$HOME_DIR/.chrome-remote-desktop-session"
check_file "CRD setup helper" "$HOME_DIR/.local/bin/setup-crd.sh"

# =============================================================================
# Sway Config Content
# =============================================================================
log ""
log "--- Sway Config Checks ---"
SWAY_CFG="$HOME_DIR/.config/sway/config"
check_grep "xwayland disable" "xwayland disable" "$SWAY_CFG"
check_grep "IntelliJ DISPLAY=:0" "DISPLAY=:0.*idea-oss" "$SWAY_CFG"
check_grep "VSCode LD_LIBRARY_PATH" "LD_LIBRARY_PATH.*code" "$SWAY_CFG"
check_grep "Wofi XDG_DATA_DIRS" "XDG_DATA_DIRS" "$SWAY_CFG"
check_grep "Clipman keybinding" "mod+a.*clipman" "$SWAY_CFG"
check_grep "Windsurf keybinding" "mod+w.*windsurf" "$SWAY_CFG"
check_grep "Apps button click" "button1.*wofi" "$SWAY_CFG"
# F-0116: Antigravity IDE keybindings removed — assert they are ABSENT
if grep -qE 'bindsym.*mod\+g.*antigravity|bindsym.*mod\+n.*antigravity' "$SWAY_CFG"; then
    test_fail "Sway config still has antigravity IDE keybinding(s) (\$mod+g or \$mod+n) — F-0116 regression"
else
    test_pass "Sway config has no antigravity IDE keybindings (\$mod+g/\$mod+n removed — F-0116)"
fi
# Assert that the Antigravity placement rule is present so that it opens in workspace 1
if grep -q 'for_window \[app_id="antigravity"\]' "$SWAY_CFG"; then
    test_pass "Antigravity/Hub placement rule present in sway config"
else
    test_fail "Antigravity/Hub placement rule missing from sway config"
fi
check_grep "Workspace 1 layout tabbed" "workspace 1 layout tabbed" "$SWAY_CFG"
check_grep "Workspace 5 layout tabbed" "workspace 5 layout tabbed" "$SWAY_CFG"
check_grep "Snippet picker keybinding" "snippet-picker" "$SWAY_CFG"
# Assert that the Chrome placement and no_focus rules are present (both Wayland and X11)
if grep -q 'for_window \[app_id="google-chrome"\]' "$SWAY_CFG" && \
   grep -q 'for_window \[class="Google-chrome"\]' "$SWAY_CFG" && \
   grep -q 'no_focus \[app_id="google-chrome"\]' "$SWAY_CFG" && \
   grep -q 'no_focus \[class="Google-chrome"\]' "$SWAY_CFG"; then
    test_pass "Chrome placement and no_focus rules present in sway config (Wayland & X11)"
else
    test_fail "Chrome placement or no_focus rules missing from sway config (Wayland & X11)"
fi
# F-0107: $mod+h keybinding conflict fix — must be exactly ONE workspace binding, not exec Hub.
# F-0113: after Chrome/Hub workspace swap (F-0112), $mod+h must now be workspace 1 (Hub),
#         and $mod+u must be workspace 5 (Chrome). Mnemonics now match the boot layout.
SWAY_MOD_H_COUNT=$(grep -c "bindsym.*\$mod+h" "$SWAY_CFG")
if [ "$SWAY_MOD_H_COUNT" -eq 1 ]; then
    # Should be the workspace binding pointing to ws1 (Hub), not exec and not ws5
    if grep -q "bindsym \$mod+h workspace number 1" "$SWAY_CFG"; then
        test_pass "Keybinding \$mod+h is workspace 1 / Hub (unique, no exec duplicate) (F-0113)"
    else
        test_fail "Keybinding \$mod+h exists but is not workspace 1 — F-0113 remap may be missing"
    fi
else
    test_fail "Keybinding \$mod+h appears $SWAY_MOD_H_COUNT times (should be 1)"
fi
# F-0113: $mod+u must now be workspace 5 (Chrome) — not workspace 1 (orphaned pre-F-0113 slot)
SWAY_MOD_U_COUNT=$(grep -c "bindsym.*\$mod+u" "$SWAY_CFG")
if [ "$SWAY_MOD_U_COUNT" -eq 1 ]; then
    if grep -q "bindsym \$mod+u workspace number 5" "$SWAY_CFG"; then
        test_pass "Keybinding \$mod+u is workspace 5 / Chrome (F-0113)"
    else
        test_fail "Keybinding \$mod+u exists but is not workspace 5 — F-0113 remap may be missing"
    fi
else
    test_fail "Keybinding \$mod+u appears $SWAY_MOD_U_COUNT times (should be 1)"
fi
# F-0113: move-container bindings must also be remapped
check_grep "Move container \$mod+Alt+h to ws1 / Hub" \
    "bindsym.*\$mod+Alt+h move container to workspace number 1" "$SWAY_CFG"
check_grep "Move container \$mod+Alt+u to ws5 / Chrome" \
    "bindsym.*\$mod+Alt+u move container to workspace number 5" "$SWAY_CFG"
# F-0095: foot CWD drift guard. Standardized on
# --working-directory=/home/user (commits 0dd33b3, 20d3352). The earlier
# "cd ~ && $nix/foot" style from F-0087 does not work in sway exec without
# an explicit shell invocation, so this is the only permitted form.
check_grep "foot \$mod+Return starts in /home/user" \
    'bindsym \$mod+Return exec .*foot.*--working-directory=/home/user' "$SWAY_CFG"
check_grep "foot \$mod+t starts in /home/user" \
    'bindsym \$mod+t exec .*foot.*--working-directory=/home/user' "$SWAY_CFG"
check_grep "Sway CRD Xwayland check" 'WLR_BACKENDS.*x11.*Xwayland' "$SWAY_CFG"

# R4b: autostart workspace script must carry the same guard on every foot
# invocation. Check the live ~/boot copy (what actually runs on boot). A
# missing flag here was the root cause of F-0095 (the old cd ~ && style
# from F-0087 had silently been undone).
WS_SCRIPT="$HOME_DIR/boot/08-workspaces.sh"
if [ -f "$WS_SCRIPT" ]; then
    # Match any line that invokes foot — bare "$FOOT" at end of line,
    # "$FOOT" with trailing args, or a literal /foot path (with or
    # without surrounding quotes / trailing args). Excludes the shell
    # variable assignment line (FOOT="…") so we only check call sites.
    FOOT_LINES=$(grep -nE '(\"\$FOOT\"|\$FOOT|/foot)([[:space:]"]|$)' "$WS_SCRIPT" 2>/dev/null \
        | grep -vE '^[0-9]+:FOOT=' || true)
    if [ -z "$FOOT_LINES" ]; then
        test_warn "08-workspaces.sh has no foot invocations to check"
    elif echo "$FOOT_LINES" | grep -vq -- "--working-directory=/home/user"; then
        test_fail "08-workspaces.sh has foot invocation(s) missing --working-directory=/home/user"
    else
        test_pass "08-workspaces.sh foot invocations all carry --working-directory=/home/user"
    fi
else
    test_fail "08-workspaces.sh not found at $WS_SCRIPT"
fi

# R4c: drift guard — if home-manager is managing sway config, the
# home-manager source and the live config must be byte-identical on the
# foot-launch lines. Catches H1 (home-manager sway-config drift) at boot.
HM_SWAY="$HOME_DIR/.config/home-manager/sway-config"
if [ -f "$HM_SWAY" ]; then
    LIVE_FOOT=$(grep -E '^bindsym \$mod\+(Return|t) exec .*foot' "$SWAY_CFG" | sort)
    HM_FOOT=$(grep -E '^bindsym \$mod\+(Return|t) exec .*foot' "$HM_SWAY" | sort)
    if [ "$LIVE_FOOT" = "$HM_FOOT" ] && [ -n "$LIVE_FOOT" ]; then
        test_pass "sway foot-launch lines match between live config and home-manager source"
    else
        test_fail "sway foot-launch lines drift between $SWAY_CFG and $HM_SWAY"
    fi
else
    test_skip "home-manager sway-config not present (config deployed directly by setup)"
fi

# F-0131 autostart: VS Code placement rule — for_window [app_id="code"] move container to workspace number 2
# Static grep: confirms the rule is present in the sway config at boot.
if grep -qF 'for_window [app_id="code"] move container to workspace number 2' "$SWAY_CFG"; then
    test_pass "F-0131: sway config has VSCode placement rule (app_id=code → workspace 2)"
else
    test_fail "F-0131: sway config missing VSCode placement rule (for_window [app_id=\"code\"] move container to workspace number 2)"
fi

# F-0131 autostart: VS Code autostart exec directive present in AUTOSTART section
# Static grep: confirms exec (not exec_always) invocation is present.
if grep -qE '^exec env -u LD_LIBRARY_PATH \$nix/code --no-sandbox' "$SWAY_CFG"; then
    test_pass "F-0131: sway config has VSCode autostart exec (exec, not exec_always)"
else
    test_fail "F-0131: sway config missing VSCode autostart exec directive"
fi

# F-0131 parity guard: repo sway config and home-manager sway-config must be byte-identical.
# Extends R4c to cover the full file, not just foot-launch lines.
if [ -f "$HM_SWAY" ]; then
    if diff -q "$SWAY_CFG" "$HM_SWAY" >/dev/null 2>&1; then
        test_pass "F-0131: repo sway config and home-manager sway-config are byte-identical (full file parity)"
    else
        test_fail "F-0131: repo sway config and home-manager sway-config differ — three-places parity violation"
    fi
else
    test_skip "home-manager sway-config not present — skipping full-file parity check (F-0131)"
fi

# =============================================================================
# Shell Config
# =============================================================================
log ""
log "--- Shell Config ---"
HM_NIX="$HOME_DIR/.config/home-manager/home.nix"
if [ -f "$HM_NIX" ]; then
    ZSHRC_SOURCE="$HM_NIX"
else
    ZSHRC_SOURCE="$HOME_DIR/.zshrc"
fi
check_grep "zshrc.local sourcing" "zshrc.local" "$ZSHRC_SOURCE"
check_grep "Timezone Pacific" "America/Los_Angeles" "$ZSHRC_SOURCE"
check_grep "Go PATH" "GOROOT" "$ZSHRC_SOURCE"
check_grep "Rust PATH" "cargo/bin" "$ZSHRC_SOURCE"
check_grep "pyenv init" "pyenv init" "$ZSHRC_SOURCE"
check_grep "rbenv init" "rbenv init" "$ZSHRC_SOURCE"
check_grep "Starship prompt" "starship init" "$ZSHRC_SOURCE"
check_grep "tmux aliases" "tmux new-session" "$ZSHRC_SOURCE"
check_grep "Nix profile sourced" "nix-profile.*nix.sh\|nix.sh" "$ZSHRC_SOURCE"

# =============================================================================
# sway-status
# =============================================================================
log ""
log "--- sway-status ---"
SWAY_STATUS="$HOME_DIR/.local/bin/sway-status"
check_grep "Apps block" "apps" "$SWAY_STATUS"
check_grep "GPU block" "gpu" "$SWAY_STATUS"
check_grep "CPU block" "cpu" "$SWAY_STATUS"
check_grep "Memory block" "memory" "$SWAY_STATUS"
check_grep "Disk block" "disk" "$SWAY_STATUS"
check_grep "Clock block" "clock" "$SWAY_STATUS"
check_grep "Network block" "network" "$SWAY_STATUS"

# =============================================================================
# Directory Structure
# =============================================================================
log ""
log "--- Directory Structure ---"
if ws_module_enabled "languages"; then
    check_dir "GOPATH" "$HOME_DIR/gopath"
    check_dir "Go install" "$HOME_DIR/go/bin"
    check_dir "Cargo" "$HOME_DIR/.cargo/bin"
    check_dir "pyenv" "$HOME_DIR/.pyenv"
    check_dir "rbenv" "$HOME_DIR/.rbenv"
else
    test_skip "Language dirs (languages module disabled)"
fi
check_dir "npm-global" "$HOME_DIR/.npm-global"
# npm global prefix must point at persistent disk so Claude Code's
# auto-updater (and any `npm -g`) doesn't EACCES on /usr/lib/node_modules.
npm_prefix=$(runuser -u $USER -- npm config get prefix 2>/dev/null)
if [ "$npm_prefix" = "$HOME_DIR/.npm-global" ]; then
    test_pass "npm prefix = $npm_prefix"
else
    test_fail "npm prefix is '$npm_prefix' (expected $HOME_DIR/.npm-global)"
fi
check_dir "Nix profile" "$HOME_DIR/.nix-profile"

# =============================================================================
# F-0096 / F-0097: Xwayland rootless invocation (no root window tiled on ws1)
# =============================================================================
# Three guards:
#   (a) Static (08-workspaces.sh): historical — the live ~/boot/08-workspaces.sh
#       invokes Xwayland with -rootless. Kept from F-0096 but insufficient on
#       its own: v1.17.1 passed this check while the running process was
#       still non-rootless (F-0097).
#   (a2) Static (sway config): the sway autostart owner of Xwayland :0 must
#       also pass -rootless. This is the exec that actually wins the boot
#       race, so the flag has to live here.
#   (b) Runtime (pgrep): the single Xwayland :0 process currently on the
#       system must have -rootless in its argv. This is the authoritative
#       check — it catches the F-0097 failure mode where the file on disk
#       is correct but the running process was started from elsewhere.
#   (c) Live (swaymsg): swaymsg -t get_tree must not contain a window with
#       app_id == "org.freedesktop.Xwayland" on any workspace. Without
#       -rootless, Xwayland spawns a visible root that Sway tiles next to
#       the foot terminal on ws1.
log ""
log "--- Xwayland rootless (F-0096 / F-0097) ---"
WS_SCRIPT="$HOME_DIR/boot/08-workspaces.sh"
if [ -f "$WS_SCRIPT" ]; then
    if grep -qE 'Xwayland[[:space:]]+-rootless' "$WS_SCRIPT"; then
        test_pass "08-workspaces.sh invokes Xwayland with -rootless"
    else
        test_fail "08-workspaces.sh missing -rootless on Xwayland invocation (F-0096 regression)"
    fi
else
    test_fail "08-workspaces.sh not found at $WS_SCRIPT (F-0096 check)"
fi

# F-0097 (a2): sway config autostart — the real launcher of Xwayland :0
if [ -f "$SWAY_CFG" ]; then
    if grep -qE '^exec[[:space:]]+.*Xwayland[[:space:]]+-rootless[[:space:]]+:0' "$SWAY_CFG"; then
        test_pass "sway config autostart invokes Xwayland with -rootless"
    else
        test_fail "sway config autostart missing -rootless on Xwayland :0 exec (F-0097 regression)"
    fi
fi

# F-0097 (b): runtime check — the Xwayland :0 process actually running on
# this boot must have -rootless in its argv. A static grep is insufficient
# because sway's autostart can race with 08-workspaces.sh; only ps -o args=
# on the live PID tells us which launcher won.
XWAY_PIDS=$(pgrep -x Xwayland 2>/dev/null | xargs)
XWAY_PID_COUNT=$(echo "$XWAY_PIDS" | wc -w)
if [ -z "$XWAY_PIDS" ]; then
    test_warn "no Xwayland :0 process running (may start later)"
elif [ "$XWAY_PID_COUNT" -gt 1 ]; then
    test_fail "multiple Xwayland :0 processes running (pids: $XWAY_PIDS)"
else
    XWAY_ARGS=$(ps -p "$XWAY_PIDS" -o args= 2>/dev/null | xargs)
    if echo "$XWAY_ARGS" | grep -qw -- '-rootless'; then
        test_pass "running Xwayland :0 has -rootless (args: $XWAY_ARGS)"
    else
        test_fail "running Xwayland :0 missing -rootless (args: $XWAY_ARGS) (F-0097 regression)"
    fi
fi

SWAY_SOCK=$(ls /run/user/1000/sway-ipc.*.sock 2>/dev/null | head -1)
if [ -n "$SWAY_SOCK" ] && command -v python3 >/dev/null 2>&1; then
    XWAY_ROOT_COUNT=$(runuser -u $USER -- env WAYLAND_DISPLAY=wayland-1 \
        XDG_RUNTIME_DIR=/run/user/1000 SWAYSOCK="$SWAY_SOCK" \
        bash -c ". $NIX_SH && swaymsg -t get_tree" 2>/dev/null | python3 -c "
import json, sys
try:
    tree = json.load(sys.stdin)
except Exception:
    print(-1); sys.exit(0)
count = 0
def walk(n):
    global count
    if n.get('app_id') == 'org.freedesktop.Xwayland':
        count += 1
    for c in n.get('nodes', []) + n.get('floating_nodes', []):
        walk(c)
walk(tree)
print(count)
" 2>/dev/null)
    if [ "${XWAY_ROOT_COUNT:-0}" = "0" ]; then
        test_pass "no Xwayland root window present in sway tree"
    elif [ "$XWAY_ROOT_COUNT" = "-1" ]; then
        test_warn "sway tree unreadable — cannot verify Xwayland root window absence"
    else
        test_fail "Xwayland root window(s) present in sway tree: $XWAY_ROOT_COUNT (F-0096 regression)"
    fi
else
    test_skip "Xwayland root window check (sway socket unavailable or python3 missing)"
fi

# =============================================================================
# F-0098 / F-0112 / F-0124: Workspace autostart layout and launch order
# =============================================================================
# F-0124 layout: ws1 = empty (Hub NOT auto-launched), ws2 = empty,
#   ws3 = foot terminal, ws4 = foot terminal, ws5 = Chrome.
# Launch order: Chrome (ws5) first, then foot (ws3, ws4).
# Final focus: ws3 (terminal — user runs hub-restart from here).
log ""
log "--- Workspace autostart layout (F-0098/F-0112/F-0124) ---"
WS_SCRIPT="$HOME_DIR/boot/08-workspaces.sh"
if [ -f "$WS_SCRIPT" ]; then
    # ws1 must be empty — Hub is NOT auto-launched (F-0124)
    if ! grep -qE '^[[:space:]]*launch_and_wait[[:space:]]+1[[:space:]]' "$WS_SCRIPT"; then
        test_pass "08-workspaces.sh ws1 is empty (Hub not auto-launched — F-0124)"
    else
        test_fail "08-workspaces.sh ws1 still has a launch_and_wait call (F-0124 regression)"
    fi

    # ws2 must be empty (Antigravity IDE removed in F-0116)
    WS2_LINE=$(grep -nE '^[[:space:]]*launch_and_wait[[:space:]]+2[[:space:]]' "$WS_SCRIPT" | head -1)
    if [ -z "$WS2_LINE" ]; then
        test_pass "08-workspaces.sh ws2 is empty (Antigravity IDE removed — F-0116)"
    else
        test_fail "08-workspaces.sh ws2 still has a launch_and_wait call (F-0116 regression): $WS2_LINE"
    fi

    # ws3 must be foot terminal
    WS3_LINE=$(grep -nE '^[[:space:]]*launch_and_wait[[:space:]]+3[[:space:]]' "$WS_SCRIPT" | head -1)
    if echo "$WS3_LINE" | grep -q '"\$FOOT"'; then
        test_pass "08-workspaces.sh ws3 launches foot terminal"
    else
        test_fail "08-workspaces.sh ws3 does not launch foot (line: $WS3_LINE)"
    fi

    # ws4 must be foot terminal
    WS4_LINE=$(grep -nE '^[[:space:]]*launch_and_wait[[:space:]]+4[[:space:]]' "$WS_SCRIPT" | head -1)
    if echo "$WS4_LINE" | grep -q '"\$FOOT"'; then
        test_pass "08-workspaces.sh ws4 launches foot terminal"
    else
        test_fail "08-workspaces.sh ws4 does not launch foot (line: $WS4_LINE)"
    fi

    # ws5 must be Chrome (F-0112: Chrome moved from ws1 → ws5)
    WS5_LINE=$(grep -nE '^[[:space:]]*launch_and_wait[[:space:]]+5[[:space:]]' "$WS_SCRIPT" | head -1)
    if echo "$WS5_LINE" | grep -q "google-chrome-stable"; then
        test_pass "08-workspaces.sh ws5 launches google-chrome-stable (F-0112)"
    else
        test_fail "08-workspaces.sh ws5 does not launch Chrome (line: $WS5_LINE) (F-0112)"
    fi

    # Header comment must reflect the F-0124 layout (ws1 empty — Hub not auto-launched)
    if grep -qE '^#.*ws1 = \(empty|Hub not auto-launched' "$WS_SCRIPT"; then
        test_pass "08-workspaces.sh header comment reflects F-0124 layout (ws1 empty, Hub not auto-launched)"
    else
        test_fail "08-workspaces.sh header comment does not reflect F-0124 layout (expected ws1 empty)"
    fi

    # launch_and_wait must return 1 on timeout
    if grep -A1 "WARNING: Timeout" "$WS_SCRIPT" | grep -q "return 1"; then
        test_pass "08-workspaces.sh launch_and_wait returns 1 on timeout"
    else
        test_fail "08-workspaces.sh launch_and_wait does NOT return 1 on timeout"
    fi
else
    test_fail "08-workspaces.sh not found at $WS_SCRIPT (F-0098/F-0112/F-0124 check)"
fi

# =============================================================================
# Services (may not be running during boot script phase)
# =============================================================================
log ""
log "--- Services ---"
check_process "Sway" "sway$"
check_process "swaybar" "swaybar"
check_process "wayvnc" "wayvnc"
check_process "Xwayland" "Xwayland"
check_process "clipman" "clipman store"
if ls "$HOME_DIR/.config/chrome-remote-desktop"/host#*.json &>/dev/null; then
    check_process "chrome-remote-desktop" "chrome-remote-desktop"
fi


# =============================================================================
# Upgrade Scripts
# =============================================================================
log ""
log "--- Upgrade Scripts ---"

if ws_module_enabled "ai-tools"; then
    # Check 07-apps.sh ran and completed
    if [ -f "$HOME_DIR/logs/app-update.log" ]; then
        if grep -q "App update complete" "$HOME_DIR/logs/app-update.log" 2>/dev/null; then
            test_pass "07-apps.sh completed successfully"
        else
            test_fail "07-apps.sh did not complete (check ~/logs/app-update.log)"
        fi
    else
        test_fail "07-apps.sh never ran (~/logs/app-update.log missing)"
    fi

    check_version "Claude Code" "claude --version"
    check_version "OpenCode" "opencode -v"
elif ws_module_enabled "ai-tools-minimal"; then
    check_version "Claude Code" "claude --version"
    test_skip "Full AI tools versions (ai-tools-minimal profile)"
else
    test_skip "AI tool versions (module disabled)"
fi

# Home Manager generation is recent (within last 24 hours)
HM_GEN=$(runuser -u $USER -- bash -c ". $NIX_SH && home-manager generations" 2>&1 | head -1)
if [ -n "$HM_GEN" ]; then
    test_pass "Home Manager generation: $HM_GEN"
else
    test_fail "Home Manager has no generations"
fi

# Nix channel updated
if runuser -u $USER -- bash -c ". $NIX_SH && nix-channel --list" 2>&1 | grep -q "nixpkgs"; then
    test_pass "Nix channel configured"
else
    test_fail "Nix channel not configured"
fi

# =============================================================================
# Tailscale (opt-in — only tested if module enabled + TAILSCALE_AUTHKEY in ~/.env)
# =============================================================================
log ""
if ws_module_enabled "tailscale"; then
    log "--- Tailscale ---"
    check_binary "tailscale" "tailscale"
    if grep -q "TAILSCALE_AUTHKEY" "$HOME_DIR/.env" 2>/dev/null; then
        check_file "Tailscale state dir" "$HOME_DIR/.tailscale/tailscaled.state"
        if pgrep -x tailscaled >/dev/null 2>&1; then
            test_pass "tailscaled running"
        else
            test_fail "tailscaled not running (TAILSCALE_AUTHKEY is set)"
        fi
        if tailscale status >/dev/null 2>&1; then
            TS_IP=$(tailscale ip -4 2>/dev/null)
            test_pass "Tailscale connected ($TS_IP)"
        else
            test_fail "Tailscale not connected"
        fi
        if tailscale status --json 2>/dev/null | grep -q '"SSH"'; then
            test_pass "Tailscale SSH enabled"
        else
            test_warn "Tailscale SSH status unknown"
        fi
        # SSH config for Tailscale
        if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
            test_pass "SSH PasswordAuthentication enabled"
        else
            test_fail "SSH PasswordAuthentication not enabled"
        fi
        # iptables rule for tailscale SSH
        if iptables -C INPUT -i tailscale0 -p tcp --dport 22 -j ACCEPT 2>/dev/null; then
            test_pass "iptables: SSH allowed on tailscale0"
        else
            test_fail "iptables: SSH not allowed on tailscale0"
        fi
    else
        log "  SKIP: Tailscale not configured (no TAILSCALE_AUTHKEY in ~/.env)"
    fi
else
    log "--- Tailscale --- (SKIPPED — module disabled)"
    test_skip "Tailscale (module disabled)"
fi

# =============================================================================
# Boot Sync Script (F-0108)
# =============================================================================
log ""
log "--- Boot Sync (09-sync.sh) ---"

# Check that 09-sync.sh exists in home boot directory
SYNC_SCRIPT="$HOME_DIR/boot/09-sync.sh"
if [ -f "$SYNC_SCRIPT" ]; then
    if [ -x "$SYNC_SCRIPT" ]; then
        test_pass "09-sync.sh exists and is executable"
    else
        test_fail "09-sync.sh exists but is not executable"
    fi
else
    test_fail "09-sync.sh not found at $SYNC_SCRIPT"
fi

# Check that the repo path constant is correct in the script
REPO_PATH="/home/user/dev/git/cloud-workstations"
if grep -q "REPO_DIR=\"$REPO_PATH\"" "$SYNC_SCRIPT" 2>/dev/null; then
    test_pass "09-sync.sh has correct REPO_DIR constant"
else
    test_fail "09-sync.sh REPO_DIR constant mismatch (expected $REPO_PATH)"
fi

# Check that sync log file exists (script should have run and created it)
SYNC_LOG="$HOME_DIR/logs/sync.log"
if [ -f "$SYNC_LOG" ]; then
    test_pass "09-sync.sh created log at $SYNC_LOG"
    # Check for successful sync marker
    if grep -q "Boot sync completed successfully" "$SYNC_LOG" 2>/dev/null || grep -q "Git pull succeeded" "$SYNC_LOG" 2>/dev/null || grep -q "Boot sync completed (repo missing)" "$SYNC_LOG" 2>/dev/null; then
        test_pass "09-sync.sh log shows successful completion or graceful skip"
    else
        test_warn "09-sync.sh log exists but completion status unclear (check $SYNC_LOG)"
    fi
else
    test_warn "09-sync.sh log not found at $SYNC_LOG (may run after tests)"
fi

# =============================================================================
# Boot Sync SSH Authentication (F-0109)
# =============================================================================
log ""
log "--- Boot Sync SSH Auth (09-sync.sh) ---"

# Check that 09-sync.sh exists and has GIT_SSH_COMMAND for SSH auth
SYNC_SSH_SCRIPT="$HOME_DIR/boot/09-sync.sh"
if [ -f "$SYNC_SSH_SCRIPT" ]; then
    if [ -x "$SYNC_SSH_SCRIPT" ]; then
        test_pass "09-sync.sh exists and is executable"
    else
        test_fail "09-sync.sh exists but is not executable"
    fi
else
    test_fail "09-sync.sh not found at $SYNC_SSH_SCRIPT"
fi

# Check that GIT_SSH_COMMAND is set with user's SSH key
if grep -q "GIT_SSH_COMMAND=" "$SYNC_SSH_SCRIPT" 2>/dev/null; then
    test_pass "09-sync.sh: GIT_SSH_COMMAND is set for SSH auth"
else
    test_fail "09-sync.sh: GIT_SSH_COMMAND missing — SSH auth will fail as root"
fi

# Check that the SSH key path points to user's id_ed25519
if grep -q "id_ed25519" "$SYNC_SSH_SCRIPT" 2>/dev/null; then
    test_pass "09-sync.sh: SSH key path is id_ed25519"
else
    test_fail "09-sync.sh: SSH key path not specified"
fi

# Check for StrictHostKeyChecking safety setting
if grep -q "StrictHostKeyChecking=accept-new" "$SYNC_SSH_SCRIPT" 2>/dev/null; then
    test_pass "09-sync.sh: StrictHostKeyChecking set safely"
else
    test_fail "09-sync.sh: StrictHostKeyChecking not set (will prompt for host key)"
fi

# =============================================================================
# User-Session Readiness Gate (F-0121)
# =============================================================================
# These are STATIC tests (grep-based) — no reboot required.
# They confirm that the wait_for_user_session helper is present and called
# correctly in both 07-apps.sh and 08-workspaces.sh, and that per-step
# success/failure logging is in place (no unconditional "complete" after a
# runuser command that could fail silently).
# =============================================================================
log ""
log "--- User-Session Readiness Gate (F-0121) ---"

APPS_SCRIPT="$HOME_DIR/boot/07-apps.sh"
WS_SCRIPT_F0121="$HOME_DIR/boot/08-workspaces.sh"

# (a) 07-apps.sh defines the wait_for_user_session function
if grep -q 'wait_for_user_session()' "$APPS_SCRIPT" 2>/dev/null; then
    test_pass "F-0121: 07-apps.sh defines wait_for_user_session helper"
else
    test_fail "F-0121: 07-apps.sh is missing wait_for_user_session helper"
fi

# (b) 07-apps.sh calls wait_for_user_session before the first runuser update
if grep -q 'wait_for_user_session' "$APPS_SCRIPT" 2>/dev/null; then
    # Check the call site appears before the first runuser update line
    # (i.e., call appears before "npm update" or "Antigravity CLI" lines)
    call_line=$(grep -n 'wait_for_user_session' "$APPS_SCRIPT" 2>/dev/null | grep -v '()' | head -1 | cut -d: -f1)
    npm_line=$(grep -n 'npm update -g' "$APPS_SCRIPT" 2>/dev/null | head -1 | cut -d: -f1)
    if [ -n "$call_line" ] && [ -n "$npm_line" ] && [ "$call_line" -lt "$npm_line" ]; then
        test_pass "F-0121: 07-apps.sh calls wait_for_user_session before npm update (line $call_line < $npm_line)"
    else
        test_fail "F-0121: 07-apps.sh does not call wait_for_user_session before npm update (call=$call_line, npm=$npm_line)"
    fi
else
    test_fail "F-0121: 07-apps.sh does not call wait_for_user_session"
fi

# (c) 07-apps.sh fail-open: exit 0 on timeout (skips updates gracefully)
if grep -q 'App update SKIPPED' "$APPS_SCRIPT" 2>/dev/null; then
    test_pass "F-0121: 07-apps.sh has timeout-skip path (fail-open)"
else
    test_fail "F-0121: 07-apps.sh is missing timeout-skip path (not fail-open)"
fi

# (d) 07-apps.sh per-step failure logging: no unconditional "complete" after runuser calls
# We check that each runuser update step uses if/else with FAILED logging.
# Pattern: "FAILED" appears alongside each update step keyword.
if grep -q 'npm global packages: update FAILED' "$APPS_SCRIPT" 2>/dev/null; then
    test_pass "F-0121: 07-apps.sh logs npm update FAILED on non-zero exit"
else
    test_fail "F-0121: 07-apps.sh does not log npm update FAILED (may still swallow errors)"
fi

if grep -q 'GitHub Copilot CLI: update FAILED\|Copilot.*FAILED' "$APPS_SCRIPT" 2>/dev/null; then
    test_pass "F-0121: 07-apps.sh logs GitHub Copilot update FAILED on non-zero exit"
else
    test_fail "F-0121: 07-apps.sh does not log GitHub Copilot FAILED (may still swallow errors)"
fi

if grep -q 'OpenCode: update FAILED\|OpenCode.*FAILED' "$APPS_SCRIPT" 2>/dev/null; then
    test_pass "F-0121: 07-apps.sh logs OpenCode update FAILED on non-zero exit"
else
    test_fail "F-0121: 07-apps.sh does not log OpenCode FAILED (may still swallow errors)"
fi

if grep -q 'Nix/Home Manager: update FAILED\|Home Manager.*FAILED' "$APPS_SCRIPT" 2>/dev/null; then
    test_pass "F-0121: 07-apps.sh logs Nix/Home Manager FAILED on non-zero exit"
else
    test_fail "F-0121: 07-apps.sh does not log Nix/Home Manager FAILED (may still swallow errors)"
fi

# (e) 07-apps.sh D-Bus probe uses dbus-send (confirmed present on this host)
if grep -q 'dbus-send' "$APPS_SCRIPT" 2>/dev/null; then
    test_pass "F-0121: 07-apps.sh uses dbus-send for D-Bus readiness probe"
else
    test_fail "F-0121: 07-apps.sh is missing dbus-send probe in wait_for_user_session"
fi

# F-0124: F-0121 Part B (wait_for_user_session in 08-workspaces.sh) was
# removed as part of Hub autostart removal.  Only Part A (07-apps.sh) remains.
# Regression guard: 08-workspaces.sh must NOT contain wait_for_user_session
# (its removal is intentional — the session gate was only needed for the Hub launch).
if ! grep -q 'wait_for_user_session' "$WS_SCRIPT_F0121" 2>/dev/null; then
    test_pass "F-0121/F-0124: 08-workspaces.sh does NOT define wait_for_user_session (Part B removed — correct)"
else
    test_fail "F-0121/F-0124: 08-workspaces.sh still defines wait_for_user_session (F-0124 removal incomplete)"
fi

# =============================================================================
# F-0123: ws-app-updates.service systemd ordering fix
# Static assertions — no reboot required.
# Confirms that 07-apps.sh is now managed by a systemd unit ordered
# After=user@1000.service, replacing the inline setup.sh run.
# =============================================================================
log ""
log "--- F-0123: ws-app-updates.service systemd ordering fix ---"

SERVICE_FILE="/etc/systemd/system/ws-app-updates.service"
SERVICE_WANTS="/etc/systemd/system/multi-user.target.wants/ws-app-updates.service"
SWAY_BOOT_SCRIPT="$HOME_DIR/boot/03-sway.sh"
SETUP_SCRIPT="$HOME_DIR/boot/setup.sh"

# (a) Unit file exists at the standard systemd path
if [ -f "$SERVICE_FILE" ]; then
    test_pass "F-0123: ws-app-updates.service unit file exists at $SERVICE_FILE"
else
    test_fail "F-0123: ws-app-updates.service unit file missing at $SERVICE_FILE"
fi

# (b) Unit is enabled — symlink in multi-user.target.wants/
if [ -L "$SERVICE_WANTS" ] || [ -f "$SERVICE_WANTS" ]; then
    test_pass "F-0123: ws-app-updates.service is enabled (symlink in multi-user.target.wants/)"
else
    test_fail "F-0123: ws-app-updates.service is NOT enabled (symlink missing from multi-user.target.wants/)"
fi

# (c) Unit file declares After=user@1000.service
if grep -q 'After=user@1000.service' "$SERVICE_FILE" 2>/dev/null; then
    test_pass "F-0123: ws-app-updates.service has After=user@1000.service"
else
    test_fail "F-0123: ws-app-updates.service is missing After=user@1000.service"
fi

# (d) setup.sh skip guard for 07-apps.sh is present
if grep -q '07-apps.sh.*systemd\|systemd.*07-apps.sh\|ws-app-updates' "$SETUP_SCRIPT" 2>/dev/null; then
    test_pass "F-0123: setup.sh has skip guard for 07-apps.sh (runs via systemd)"
else
    test_fail "F-0123: setup.sh is missing skip guard for 07-apps.sh"
fi

# (e) 03-sway.sh creates ws-app-updates.service (grep for the service name)
if grep -q 'ws-app-updates.service' "$SWAY_BOOT_SCRIPT" 2>/dev/null; then
    test_pass "F-0123: 03-sway.sh creates ws-app-updates.service"
else
    test_fail "F-0123: 03-sway.sh does NOT create ws-app-updates.service (service creation may have been lost)"
fi

# (f) Runtime best-effort: app-update.log last "App update" completion line is not SKIPPED.
# RACE FIX (F-0123 follow-up): Only assert the outcome AFTER ws-app-updates.service has
# finished (SubState=exited for Type=oneshot RemainAfterExit).  If the service is still
# active/running when this test executes, we WARN/SKIP rather than assert — sampling the
# log mid-run produces a false PASS on the transient "=== App update started ===" line,
# masking a later SKIPPED outcome.
APP_UPDATE_LOG="$HOME_DIR/logs/app-update.log"
SVC_SUBSTATE=$(systemctl show ws-app-updates.service -p SubState --value 2>/dev/null)
SVC_ACTIVE=$(systemctl show ws-app-updates.service -p ActiveState --value 2>/dev/null)
if [ "$SVC_SUBSTATE" = "exited" ] && [ "$SVC_ACTIVE" = "active" ]; then
    # Service has completed — it is now safe to read the final outcome from the log
    if [ -f "$APP_UPDATE_LOG" ]; then
        # Check the last completion-marker line (started / complete / SKIPPED)
        LAST_APP_LINE=$(grep '=== App update' "$APP_UPDATE_LOG" 2>/dev/null | tail -1)
        if echo "$LAST_APP_LINE" | grep -q 'SKIPPED'; then
            test_fail "F-0123: ws-app-updates.service completed but last outcome is SKIPPED — D-Bus probe still failing (check $APP_UPDATE_LOG)"
        elif echo "$LAST_APP_LINE" | grep -q 'complete'; then
            test_pass "F-0123: ws-app-updates.service completed successfully (last line: $LAST_APP_LINE)"
        elif echo "$LAST_APP_LINE" | grep -q 'started'; then
            test_warn "F-0123: ws-app-updates.service exited but log only shows 'started' — update may have failed mid-run (check $APP_UPDATE_LOG)"
        else
            test_warn "F-0123: ws-app-updates.service exited but no '=== App update' completion marker in log (check $APP_UPDATE_LOG)"
        fi
    else
        test_fail "F-0123: ws-app-updates.service exited but $APP_UPDATE_LOG is missing"
    fi
elif [ "$SVC_ACTIVE" = "activating" ] || [ "$SVC_SUBSTATE" = "start" ]; then
    # Service is still running — do not sample mid-run (race condition)
    test_skip "F-0123: ws-app-updates.service still running (SubState=$SVC_SUBSTATE) — outcome check deferred to avoid race"
elif [ -z "$SVC_ACTIVE" ]; then
    test_warn "F-0123: ws-app-updates.service not found — unit may not have been created yet this boot"
else
    # Unexpected state (failed, dead, etc.)
    test_warn "F-0123: ws-app-updates.service in unexpected state (Active=$SVC_ACTIVE SubState=$SVC_SUBSTATE) — check systemctl status ws-app-updates.service"
fi

# (g) Linger must be enabled for user so user@1000.service starts at headless boot.
# Without linger, ws-app-updates.service ordering is hollow (After=user@1000.service
# never fires on a non-interactive boot).  Check loginctl and the marker file.
if loginctl show-user user 2>/dev/null | grep -q 'Linger=yes'; then
    test_pass "F-0123: Linger=yes for user (loginctl show-user confirmed)"
elif [ -f "/var/lib/systemd/linger/user" ]; then
    test_pass "F-0123: Linger marker file present at /var/lib/systemd/linger/user (loginctl may not reflect yet)"
else
    test_fail "F-0123: Linger not enabled for user — loginctl Linger=no and /var/lib/systemd/linger/user absent (03-sway.sh linger setup failed)"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS+FAIL+WARN+SKIP))
log ""
log "========================================"
log "  TOTAL: $TOTAL | PASS: $PASS | FAIL: $FAIL | WARN: $WARN | SKIP: $SKIP"
log "========================================"

# Write one-line summary
PROFILE_INFO=""
if [ -f "$HOME_DIR/.ws-modules" ]; then
    PROFILE_INFO=" | Profile: $(grep '^profile=' "$HOME_DIR/.ws-modules" 2>/dev/null | cut -d= -f2)"
fi
echo "$(TZ=America/Los_Angeles date '+%Y-%m-%d %H:%M:%S %Z') | PASS: $PASS | FAIL: $FAIL | WARN: $WARN | SKIP: $SKIP${PROFILE_INFO}" > "$SUMMARY"

# Set ownership
chown -R $USER:$USER "$LOG_DIR"
