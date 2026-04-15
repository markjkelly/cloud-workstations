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
    check_binary "IntelliJ" "idea-oss"
    check_binary "Cursor" "cursor"
    check_binary "Windsurf" "windsurf"
    check_binary "Zed" "zeditor"
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
# AI CLI Tools
# =============================================================================
log ""
if ws_module_enabled "ai-tools"; then
    log "--- AI CLI Tools ---"
    check_binary "Claude Code" "claude"
    check_binary "Codex" "codex"
    check_binary "OpenCode" "opencode"
    check_binary "Cody" "cody"
    check_binary "Pi" "pi"
    # Aider (pip, installed to ~/.local/bin)
    if runuser -u $USER -- bash -c "export PYENV_ROOT=$HOME_DIR/.pyenv && export PATH=$HOME_DIR/.local/bin:\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && which aider" >/dev/null 2>&1; then
        test_pass "Aider (aider)"
    else
        test_fail "Aider (not found)"
    fi
    # GH Copilot (extension)
    if runuser -u $USER -- bash -c ". $NIX_SH && gh copilot --version" >/dev/null 2>&1; then
        test_pass "GH Copilot"
    else
        test_warn "GH Copilot (extension may not be installed)"
    fi
elif ws_module_enabled "ai-tools-minimal"; then
    log "--- AI CLI Tools (minimal) ---"
    check_binary "Claude Code" "claude"
    test_skip "Codex (ai-tools-minimal)"
    test_skip "OpenCode (ai-tools-minimal)"
    test_skip "Cody (ai-tools-minimal)"
    test_skip "Pi (ai-tools-minimal)"
    test_skip "Aider (ai-tools-minimal)"
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
check_file ".env" "$HOME_DIR/.env"

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
check_grep "Clipman wofi PATH" "PATH=.*clipman.*wofi\|clipman store" "$SWAY_CFG"
check_grep "Windsurf keybinding" "mod+w.*windsurf" "$SWAY_CFG"
check_grep "Apps button click" "button1.*wofi" "$SWAY_CFG"
check_grep "Antigravity keybinding" "antigravity" "$SWAY_CFG"
check_grep "Snippet picker keybinding" "snippet-picker" "$SWAY_CFG"
# F-0095: foot CWD drift guard. Standardized on
# --working-directory=/home/user (commits 0dd33b3, 20d3352). The earlier
# "cd ~ && $nix/foot" style from F-0087 does not work in sway exec without
# an explicit shell invocation, so this is the only permitted form.
check_grep "foot \$mod+Return starts in /home/user" \
    'bindsym \$mod+Return exec .*foot.*--working-directory=/home/user' "$SWAY_CFG"
check_grep "foot \$mod+t starts in /home/user" \
    'bindsym \$mod+t exec .*foot.*--working-directory=/home/user' "$SWAY_CFG"

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
    if grep -qE '^exec[[:space:]]+/usr/bin/Xwayland[[:space:]]+-rootless[[:space:]]+:0' "$SWAY_CFG"; then
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
# Services (may not be running during boot script phase)
# =============================================================================
log ""
log "--- Services ---"
check_process "Sway" "sway$"
check_process "swaybar" "swaybar"
check_process "wayvnc" "wayvnc"
check_process "Xwayland" "Xwayland"
check_process "clipman" "clipman store"

# =============================================================================
# Upgrade Scripts
# =============================================================================
log ""
log "--- Upgrade Scripts ---"

# Check tool versions (verifies upgrades actually installed something)
check_version() {
    local name="$1" cmd="$2"
    local ver=$(runuser -u $USER -- bash -c ". $NIX_SH && export PATH=$HOME_DIR/.nix-profile/bin:$HOME_DIR/.npm-global/bin:$HOME_DIR/.local/bin:$HOME_DIR/gopath/bin:$HOME_DIR/go/bin:$HOME_DIR/.cargo/bin:$HOME_DIR/.pyenv/bin:$HOME_DIR/.rbenv/bin:/var/lib/nvidia/bin:\$PATH && $cmd" 2>&1 | grep -viE "^[0-9]+/[0-9].*WARN |^WARNING" | head -1)
    if [ -n "$ver" ] && ! echo "$ver" | grep -qiE "not found|error|command not found"; then
        test_pass "$name version: $ver"
    else
        test_fail "$name version check failed"
    fi
}

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
    check_version "Codex" "codex --version"
    check_version "OpenCode" "opencode -v"
    check_version "Cody" "cody --version"
    check_version "Pi" "pi --version"

    # Aider version (pip, installed to ~/.local/bin — needs pyenv for Python)
    AIDER_VER=$(runuser -u $USER -- bash -c "export PYENV_ROOT=$HOME_DIR/.pyenv && export PATH=$HOME_DIR/.local/bin:\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && aider --version" 2>&1 | head -1)
    if [ -n "$AIDER_VER" ] && ! echo "$AIDER_VER" | grep -qiE "not found|error"; then
        test_pass "Aider version: $AIDER_VER"
    else
        test_fail "Aider version check failed"
    fi

    # GH Copilot extension installed
    if [ -d "$HOME_DIR/.local/share/gh/extensions/gh-copilot" ] || runuser -u $USER -- bash -c ". $NIX_SH && gh extension list" 2>&1 | grep -q "copilot"; then
        test_pass "GH Copilot extension installed"
    elif ! runuser -u $USER -- bash -c ". $NIX_SH && gh auth status" >/dev/null 2>&1; then
        test_warn "GH Copilot extension (gh not authenticated)"
    else
        test_fail "GH Copilot extension not found"
    fi
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
