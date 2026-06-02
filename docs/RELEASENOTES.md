# Release Notes — Cloud Workstation

## v1.27.0 — Install VS Code + reconcile home.nix drift + autostart on workspace 2 (2026-06-02)

### Added
- **VS Code 1.119.0 installed via Nix** (`pkgs.vscode`, MS proprietary build). `code` is now
  on PATH via home-manager. `allowUnfree = true` was already set in home.nix.
- **VS Code auto-starts on workspace 2** at every sway session boot. Implemented as two
  sway-native directives in `workstation-image/configs/sway/config`:
  - `for_window [app_id="code"] move container to workspace number 2` — placement rule
    (reliable for Electron app_id timing; uses `move container` not `assign`)
  - `exec env -u LD_LIBRARY_PATH $nix/code --no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage`
    — autostart exec in the AUTOSTART section (uses `exec` not `exec_always` — no duplicate on `swaymsg reload`)
  - Deliberately does NOT use `ws-autolaunch.service` / `08-workspaces.sh` — that service is
    masked every boot by `11-custom-tools.sh` (intentional end-state of F-0106→F-0124 saga).
  - Runtime validated: VS Code window confirmed on workspace 2 via `swaymsg -t get_tree`.
  - Cold-boot confirmation deferred to next reboot (exec directive cannot be triggered by reload).
- **`check_version "VSCode"` boot test** added to the IDEs section of `10-tests.sh`, now
  reporting `PASS: VSCode version: 1.119.0` on each boot.
- **`check_version` helper moved to shared helpers block** (was defined after first use at line
  98; moved to line 85 so IDE section and all future callers can invoke it properly).
- **Three new F-0131 autostart boot tests**: placement rule grep, autostart exec grep, and
  full-file parity guard (repo sway config vs `~/.config/home-manager/sway-config`).

### Changed
- **Reconciled live `~/.config/home-manager/home.nix`** from a minimal 30-line stub to the
  full-profile baseline:
  - `home.packages` = BASE_PKGS (`neovim tmux tree ffmpeg git gh curl wget htop ripgrep fd jq
    unzip chromium sway waybar foot wofi thunar grim slurp wl-clipboard clipman mako swaylock
    swayidle wayvnc nodejs_22 cascadia-code fira-code jetbrains-mono`) + `vscode`. No other IDEs.
  - `programs.zsh` block with aliases (t1–t10, cc, vim, tdbg, ta, tl, tk, etc.) and initContent
    sourcing Nix profile, timezone (`America/Los_Angeles`), PATH extensions (npm-global, local,
    nvidia, go, rust, pyenv, rbenv), pyenv/rbenv init, starship prompt, user customization hooks.
  - `home.sessionVariables`: `EDITOR=nvim`, `VISUAL=nvim`, `BROWSER=chromium`.
  - `programs.starship.enable = true`.
  - `home.file ".config/sway/config"` — sway config now managed as a home-manager symlink
    (content unchanged; previously a plain file).
  - `home.file ".config/nvim/init.lua"` — nvim config now managed as a home-manager symlink
    (source deployed from `workstation-image/configs/nvim/init.lua`).
  - Waybar `home.file` directives intentionally omitted (box uses swaybar; source files absent).
- **Boot tests improved**: PASS 137 / FAIL 21 / WARN 1 (was PASS 123 / FAIL 30 / WARN 2).
  12 fewer FAILs vs F-0123 baseline — all Shell Config checks (zshrc.local, timezone, Go PATH,
  Rust PATH, pyenv, rbenv, starship, tmux aliases, Nix profile) now PASS; 3 new F-0131
  autostart assertions added and PASS.

### Notes
- The 4 other IDEs (`jetbrains.idea-oss`, `code-cursor`, `windsurf`, `zed-editor`) are NOT
  installed on the live box. Their stale boot-test FAILs remain and are tracked under F-0126.
- `~/boot/10-tests.sh` synced to match `workstation-image/boot/10-tests.sh`.

## v1.26.1 — Fix app-updates D-Bus probe uid + boot-test race + linger fallback (2026-06-02)

### Fixed

- **D-Bus probe now runs as uid 1000** (F-0123 follow-up). The `wait_for_user_session` probe in
  `07-apps.sh` was calling `dbus-send --bus=unix:path=/run/user/1000/bus` as root (uid 0). The
  session bus uses SO_PEERCRED / EXTERNAL SASL authentication and rejects connections from any
  UID other than the bus owner. This kept `dbus_ok=0` for the full 120-second wait and caused
  the SKIPPED path to fire on every boot even after F-0123 delivered correct systemd ordering.
  Fix: wrapped the probe in `runuser -u user --`. Confirmed on live box: probe succeeds
  immediately, service completes with `=== App update complete ===`.

- **Boot-test race eliminated** (F-0123 follow-up). The F-0123 runtime test in `10-tests.sh`
  sampled `app-update.log` mid-run and gave a false PASS on the transient
  `=== App update started ===` line (72s before `=== App update SKIPPED ===` was written).
  Fix: test now checks `systemctl show ws-app-updates.service -p SubState` first — only asserts
  on the final log marker when `SubState=exited`; emits SKIP if service still running.

- **Linger fallback + loud logging** (F-0123 follow-up). `loginctl enable-linger user 2>/dev/null`
  silently swallowed failures leaving `Linger=no` on the booted system. Fix: captures RC and
  stderr, logs both; falls back to direct marker-file creation if loginctl fails; verifies
  result and logs it. New boot test asserts `Linger=yes` or marker file present.

### Tests
- 7th F-0123 boot test added: linger assertion (Linger=yes or marker file present).
- F-0123 runtime test (f) rewritten: race-safe, service-state-gated, SKIP on mid-run.

## v1.26.0 — Fix skipped app updates on slow boots: systemd ordering (2026-06-02)

### Changed
- **`07-apps.sh` now runs via `ws-app-updates.service`** (F-0123). The script is no longer
  invoked inline by `setup.sh`. A new systemd unit `ws-app-updates.service` is created by
  `03-sway.sh` on every boot with `After=user@1000.service network-online.target`, so the
  OS-level ordering guarantee ensures the user session (PAM + D-Bus) is ready before any
  `runuser` call — regardless of how slowly `user@1000.service` starts.
- **`loginctl enable-linger user`** added to `03-sway.sh`. Without linger, `user@1000.service`
  only starts on interactive login and the `After=` ordering is hollow on a headless boot.
  The call is idempotent and safe to run on every boot.
- **`setup.sh` skip guard** added for `07-apps.sh`, matching the existing guards for
  `08-workspaces.sh` and `10-tests.sh`.
- **`wait_for_user_session` kept** in `07-apps.sh` as a defensive backstop (now succeeds in
  seconds because unit ordering already guarantees session readiness). Comment block updated
  to explain the new role.

### Fixed
- On boots where `user@1000.service` started after the 120-second `wait_for_user_session`
  timeout (observed at boot+203s), ALL app updates were silently skipped — npm globals,
  Antigravity CLI, Copilot, OpenCode, and `home-manager switch` never ran. This was a
  systematic miss introduced by F-0121's stopgap timeout approach; F-0123 removes the race
  entirely via systemd ordering.

### Tests
- 6 new boot tests in `10-tests.sh` (F-0123 section): service unit file exists, service is
  enabled, `After=user@1000.service` present, `setup.sh` skip guard present, `03-sway.sh`
  creates the service, runtime best-effort check that `app-update.log` does not end in
  SKIPPED.

## v1.25.2 — TPM bookkeeping: reconcile stale Hub and CWD backlog rows (2026-06-02)

### Changed
- **F-0106 and F-0107 backlog status corrected** to `superseded`. Both rows were left at
  `in-review` / `in-progress` after the Hub autostart direction was abandoned in F-0124.
  No code changes — docs-only correction.
- **Status legend in `docs/BACKLOG.md`** extended with `superseded` as a formal status term,
  consistent with the "⚠ SUPERSEDED" language already used in multiple Feedback cells.
- **F-0103 backlog status corrected** from `in-progress` to `done`. F-0103 ("Fix foot
  terminal CWD regression (third occurrence)") was a stale duplicate of F-0095. The fix
  (`--working-directory=/home/user`) is present in all three required sources (sway config,
  home-manager sway-config, `08-workspaces.sh`), shipped in v1.18 via PR #9. The R4a/R4b/R4c
  drift-guard tests it requested already exist at `10-tests.sh:473-515`. No code changes —
  docs-only correction. See F-0095 for canonical fix history.

## v1.25.1 — Antigravity IDE cleanup: remove orphaned dirs and dead sway rule (2026-05-29)

### Removed
- **Orphaned Antigravity IDE directories** (F-0125). The four dirs left on the persistent
  disk after F-0116 removed the IDE are now cleaned idempotently on every boot by
  `07-apps.sh`, reclaiming ~193 MB:
  - `~/.config/Antigravity` (~30 MB) — IDE Electron userData
  - `~/.config/Antigravity.bak.*` (~72 MB) — backup(s) of the above
  - `~/.antigravity` (~91 MB) — IDE extensions / local state
  - `~/.cache/antigravity` (~8 KB) — IDE cache
  Cleanup is guarded to never touch Hub (`~/.config/Antigravity-Hub`) or CLI
  (`~/.gemini/antigravity-cli`, `~/.antigravitycli`) directories.
- **Dead sway `for_window` rule** (F-0125). The `for_window [app_id="antigravity"] move
  container to workspace number 1` rule (and its F-0116 explanatory comment) is removed
  from `workstation-image/configs/sway/config` and `~/.config/home-manager/sway-config`.
  The rule was made redundant by F-0124: Hub autostart was removed, and `hub-restart`
  already calls `swaymsg workspace 1` before launching the Hub.

### Tests
- 7 new boot tests in `10-tests.sh` assert: each orphaned IDE dir is absent, Hub and
  CLI dirs are still present (over-deletion guards), and the dead sway rule is absent.
  The stale F-0116 Hub-placement-rule positive-presence test is removed.

## v1.25.0 — Remove Hub autostart machinery; boot no longer auto-launches the Hub (2026-05-29)

### Changed (Breaking: boot behavior)
- **Boot no longer auto-launches the Antigravity Hub** (F-0124). After persistent cold-boot
  failures across F-0110–F-0121 that were never made reliable, the Hub autostart is removed
  entirely. Workspace 1 now starts empty on every boot. **Run `hub-restart` from any terminal
  after connecting** — this always works and takes ~5s.
- **Final focus workspace changed from ws1 to ws3** (terminal). The user lands on a prompt
  immediately ready to type `hub-restart`, rather than an empty ws1 with no visible action.
- `08-workspaces.sh` reduced from 1,079 to 181 lines (−898 lines).

### Removed
- All Hub autostart machinery from `08-workspaces.sh`:
  - F-0117 readiness-based retry loop (`HUB_MAX_RETRIES=3`, `hub_language_server_ready()`,
    `HUB_LAUNCH_TIMEOUT`, instrumentation log `~/logs/language_server_boot_diag.log`)
  - F-0118 background diagnostic sampler (`_f0118_ls_diag_sampler()`, `~/logs/hub-ls-diag.log`)
  - F-0119/F-0120 LS capture shim installer (`_f0119_install_ls_shim()`, `~/logs/ls-spawn.*`)
  - F-0114 pre-launch stale-Hub process reaper and singleton lock cleanup
  - F-0121 Part B user-session readiness gate (`wait_for_user_session()` in 08-workspaces.sh)
  - Hub launch block (`runuser … antigravity-hub …`, retry/poll loop, `HUB_OK` variable)

### Fixed
- **Live `language_server` binary restored** from the F-0119/F-0120 bash shim to the real
  ELF binary. Before: `file language_server` → "Bourne-Again shell script". After: `file
  language_server` → "ELF 64-bit LSB pie executable, x86-64, stripped". The `.real` backup
  no longer exists.

### Kept
- F-0115 gnome-keyring (OAuth token persistence for hub-restart)
- F-0116 sway `for_window` rule (hub-restart's window still lands on ws1)
- F-0122 `hub-restart` utility (the supported launch path)
- F-0121 Part A in `07-apps.sh` (app-update session gate — unaffected)
- Chrome on ws5, foot terminals on ws3/ws4

## v1.24.15 — hub-restart manual Hub-relaunch utility (2026-05-29)

### Added
- **`hub-restart` utility** (F-0122): a one-command script to cleanly relaunch the
  Antigravity Hub when workspace 1 is blank after a cold-boot failure. Run
  `hub-restart` from any terminal; it kills any stuck Hub, clears the Electron
  Singleton lock, relaunches from the user's Wayland/D-Bus session (the warm path
  that always works), focuses workspace 1, and polls for `language_server` readiness
  (up to 20 s), printing `UP ✓` with the port on success.
  - Deployed to `~/.local/bin/hub-restart` (executable, on PATH) by
    `cloud-build-setup.sh` — survives fresh-project setup on a new disk.
  - Source in repo: `workstation-image/scripts/hub-restart`.
  - 3 new boot tests in `10-tests.sh` (F-0122): file-exists, executable, on PATH.
  - Documented in `docs/STARTUP_SCRIPTS.md` under new "User Tools" table.

## v1.24.14 — Gate boot scripts on user-session readiness (2026-05-29)

### Fixed
- **07-apps.sh: all app updates now actually run on cold boot** (F-0121 Part A).
  Root cause: `07-apps.sh` (run by `setup.sh` at boot+32s) was calling
  `runuser -u user -- …` ~83 seconds before `user@1000.service` came up, causing
  every `runuser` to fail with "user does not exist". A `wait_for_user_session`
  helper now polls until both the PAM session (`runuser -u user -- true` returns 0)
  and the D-Bus session bus (`dbus-send` probe on `/run/user/1000/bus`) are ready,
  with a 120s timeout. If the session is not ready after 120s the script exits
  cleanly with a WARNING (fail-open — updates are skipped rather than silently
  failing into a broken session).
- **07-apps.sh: silent-failure logging eliminated** (F-0121 Part A). Every update
  step (`npm update -g`, Antigravity CLI, GitHub Copilot CLI, OpenCode,
  `home-manager switch`) now wraps its `runuser` command in an `if/else` and logs
  either `"… OK"` or `"… FAILED (rc=N)"`. No more unconditional `"… complete"` that
  masked failures.

### Changed
- **08-workspaces.sh: Hub launch gated on user-session readiness** (F-0121 Part B,
  hypothesis-driven). The same `wait_for_user_session` helper is inserted after the
  Sway-ready check and before the gnome-keyring / Hub launch block. `ws-autolaunch`
  was previously starting only ~3s after `user@1000.service`, while D-Bus portals,
  keyring, and gvfs were still activating — strongly correlated with the
  first `--standalone` LS spawn failing and producing blank ws1. Fail-open:
  if the session is not ready the Hub still launches (existing F-0117 retry as
  backstop). Logs elapsed wait time for diagnosis.

### Notes
- **Boot-script-only change** — no image rebuild required. Merge PR then reboot.
- `scripts/cloud-build-setup.sh` unchanged — boot scripts deployed via tarball.
- **Post-merge validation steps for PO:**
  1. `grep -E 'OK|FAILED|SKIPPED|waiting|ready' ~/logs/app-update.log` — expect
     `"User session ready after Ns"` then `"… OK"` for each update step.
  2. `~/logs/ls-spawn.log` — check if a `--standalone` header appears on Attempt 1
     (not just Attempt 2). If yes, Part B fixed the blank-ws1 root cause.
  3. `~/logs/hub-launch.log` — confirm `Port changed!` fired on Attempt 1.
- Part B (blank-ws1) validation-on-reboot pending PO merge + reboot.
  F-0117 retry backstop is preserved regardless of Part B outcome.

## v1.24.13 — Hub LS shim env-capture + PATH repair (2026-05-29)

### Changed
- **Hub LS capture shim upgraded to F-0120** — the shim installed over the Hub's
  `language_server` binary receives three targeted changes:
  1. **Absolute shebang** (`#!/bin/bash`) replaces `#!/usr/bin/env bash`. The Hub passes
     its `--standalone` LS child a stripped environment where `PATH` may be empty or
     broken; `/usr/bin/env` cannot resolve `bash` in that case, so the shim never ran.
     `#!/bin/bash` runs unconditionally.
  2. **Environment capture** — the shim's very first action appends to a new log
     `~/logs/ls-spawn.env`: timestamp, pid, args, the raw `PATH` value the Hub supplied,
     and a full `env` dump. This confirms or refutes the broken-PATH theory on the
     next cold boot regardless of whether the fix works.
  3. **Environment repair** — before exec-ing the real binary the shim ensures:
     `export PATH="/usr/bin:/bin:/usr/local/bin${PATH:+:$PATH}"` and sets
     `HOME=/home/user` if HOME is empty.
  All pre-existing behaviour preserved: stdout+stderr tee'd UNMODIFIED to Hub
  (port-discovery safe), SIGTERM/SIGINT forwarding, spawn/exit records in `ls-spawn.log`.

### Added
- **Idempotent shim upgrade** — `_f0119_install_ls_shim()` now detects a stale F-0119-era
  shim (missing the `# F-0120` version marker) and rewrites it in-place without touching
  `language_server.real`. Fresh-install path (ELF present, no shim) continues to work.
- **8 new F-0120 boot tests** in `10-tests.sh`: static heredoc checks for shebang,
  version marker, `ls-spawn.env`, PATH repair, upgrade logic; plus installed-shim marker
  and shebang checks.

### Notes
- **Boot-script-only change** — no image rebuild required. Merge PR then reboot.
- F-0120 shim installed live immediately (no reboot needed for the shim upgrade itself).
- After merge + reboot: read `~/logs/ls-spawn.env` to see the Hub's child PATH for
  `--standalone`; read `~/logs/ls-spawn.log` for `--standalone` spawn header (confirms
  shim now executes); read `~/logs/hub-launch.log` for `Port changed!` (confirms fix).
- `scripts/cloud-build-setup.sh` unchanged — boot scripts deployed via tarball.

## v1.24.12 — Hub LS spawn capture shim: capture language_server stdout/stderr (2026-05-29)

### Added
- **Hub LS spawn capture shim** (F-0119) — a bash shim is installed over the Hub's
  `language_server` binary before each Hub launch. The shim passes both stdout and
  stderr through to the Hub UNMODIFIED (preserving the Hub's port-discovery mechanism),
  while also teeing them to:
  - `~/logs/ls-spawn.log` — human-readable spawn/exit records with timestamps, args, and exit code
  - `~/logs/ls-spawn.out` — raw LS stdout (append per spawn; may contain dynamic port line)
  - `~/logs/ls-spawn.err` — raw LS stderr (append per spawn; expected to show crash reason at cold boot)
  Install is idempotent (marker-based: `# F-0119 LS capture shim` on line 2 of the shim).
  SIGTERM/SIGINT forwarded to the real child process. Diagnostic only — no change to Hub
  launch behavior or timing. The next cold boot where ws1 is blank will leave evidence
  in `~/logs/ls-spawn.err` for F-0120 root-cause analysis.

### Changed
- **`workstation-image/boot/08-workspaces.sh`** — new `_f0119_install_ls_shim()` function
  called before the Hub launch block (no behavior change to Hub launch itself)
- **`workstation-image/boot/10-tests.sh`** — 6 new F-0119 tests (shim marker, .real ELF,
  executability, logs dir writable, function defined, call-site ordering)
- **`docs/STARTUP_SCRIPTS.md`** — new log entries for `ls-spawn.log`, `ls-spawn.out`, `ls-spawn.err`

### Notes
- **Boot-script-only change** — no image rebuild required. Merge PR then reboot.
- Shim installed live on this workstation; warm-path verification confirmed capture
  works AND Hub still fires `Port changed!` correctly.
- After merge + reboot: read `~/logs/ls-spawn.err` to see why LS exits at cold boot.
- F-0120 will implement the targeted fix based on the captured evidence.

## v1.24.11 — Hub LS boot diagnostics: thorough sampler instrumentation (2026-05-29)

### Added
- **Hub LS boot diagnostic sampler** (F-0118) — a background sampler runs during every
  Hub launch window (full 90 s), sampling every 3 s, appending to `~/logs/hub-ls-diag.log`.
  Per sample: language_server PID + process state (disappearance detected), LS-owned
  LISTEN sockets via correct inode→fd matching, Hub-reported port from hub-launch.log,
  curl/tcp connectivity probes, Hub renderer count, DNS resolution + curl probe of
  `daily-cloudcode-pa.googleapis.com` (leading cold-boot failure hypothesis), one-time
  snapshot of LS log directories and LS stdout/stderr fd targets. Diagnostic only — no
  change to Hub launch timing or behavior.

### Changed
- **`workstation-image/boot/08-workspaces.sh`** — Two additions (no behavior change):
  - Named constants `HUB_LS_DIAG_LOG=/home/user/logs/hub-ls-diag.log` and
    `HUB_LS_DIAG_INTERVAL=3`
  - `_f0118_ls_diag_sampler()` function started in background after Hub launch, killed
    after the poll loop exits; per-boot header `=== F-0118 LS diag: ... ===` written
- **`workstation-image/boot/10-tests.sh`** — 9 new F-0118 tests
- **`docs/STARTUP_SCRIPTS.md`** — new `hub-ls-diag.log` log entry; F-0117 false-positive
  note and F-0118 sampler description added to ws-autolaunch section

### Notes
- **Boot-script-only change** — no image rebuild required. Merge PR then reboot.
- Root-cause finding this session: F-0117's readiness check is a confirmed false positive
  (reads shared network namespace). The real LS failure is still invisible until the
  first cold boot with this sampler runs.
- Read `~/logs/hub-ls-diag.log` after the next cold boot where ws1 is blank.

## v1.24.10 — Hub boot resilience: readiness-based retry and instrumentation (2026-05-29)

### Fixed
- **Workspace 1 blank after cold boot — intermittent language_server non-readiness**
  (F-0117) — Root cause: the Hub's bundled `language_server` intermittently fails to
  reach "listening" state at cold boot. Without a listening server, Electron never fires
  the "Port changed!" event; the BrowserWindow is never navigated, no renderer process
  starts, and no `app_id=antigravity` window maps in sway. The prior single-shot
  `launch_and_wait 1 90` detected only sway windows and did not retry — the Hub stayed
  alive but renderer-less and ws1 remained blank.

### Changed
- **`workstation-image/boot/08-workspaces.sh`** — Three additions:
  - **Named constants** `HUB_LAUNCH_TIMEOUT=90`, `HUB_MAX_RETRIES=3`,
    `HUB_LS_LOG=/home/user/logs/language_server_boot_diag.log`
  - **`hub_language_server_ready()` function** — polls the `language_server` PID for a
    TCP socket in LISTEN state via `/proc/<pid>/net/tcp6` (hex state `0A`), falling back
    to `/proc/net/tcp6` and `/proc/net/tcp`. Returns 0 (ready) when a LISTEN socket is
    found; returns 1 if the PID is absent or no socket is open.
  - **Readiness-based retry loop** — replaces the single-shot `launch_and_wait 1 90`
    call. Each attempt (up to `HUB_MAX_RETRIES=3`) polls `hub_language_server_ready()`
    as the primary signal and a sway window on ws1 as the secondary signal. On failure:
    captures diagnostics to `HUB_LS_LOG`, kills stale processes via `_kill_stale_hub()`
    (same safe pgrep/exe-path filtering as F-0114), removes `Singleton*` lock files,
    and relaunches. All prior flags and behavior fully preserved.
- **`workstation-image/boot/10-tests.sh`** — 8 new F-0117 tests; updated F-0110/F-0112
  timeout test and ws1 layout test to match the new retry-loop structure.
- **`docs/STARTUP_SCRIPTS.md`** — new `~/logs/language_server_boot_diag.log` log entry;
  F-0117 readiness/retry description added to the `ws-autolaunch` section.

### Notes
- **Boot-script-only change** — no image rebuild required. Test by rebooting.
- On a successful boot `language_server_boot_diag.log` receives only a header line.
  On a boot where retries fire, the log contains diagnostic data for a targeted fix.
- The residual `Antigravity IDE absent` test FAIL (pre-existing from F-0116) requires
  a Docker image rebuild via `ws.sh setup` — unrelated to this fix.

## v1.24.9 — Remove Antigravity IDE; fix Hub window placement on ws1 (2026-05-29)

### Fixed
- **Hub window vanishing / not landing on workspace 1** (F-0116) — Root cause: both the
  Antigravity Hub (`~/.local/share/antigravity-hub/antigravity`) and the Antigravity IDE
  (`/usr/share/antigravity/antigravity`) report `app_id="antigravity"` to sway. No
  `for_window` placement rule existed. The Hub's BrowserWindow maps asynchronously after
  the bundled `language_server` picks its port, which at cold boot occurs after
  `launch_and_wait 1 90` times out — focus has drifted to ws3/ws4 by then, so the Hub
  window mapped on the wrong workspace and appeared to vanish.

### Changed
- **Antigravity IDE removed** — The IDE (`/usr/bin/antigravity`, `/usr/share/antigravity`)
  is no longer installed. Removed from:
  - `workstation-image/Dockerfile` — removed apt repo key, source list, and `apt-get install -y antigravity` layer
  - `workstation-image/boot/07-apps.sh` — removed `apt-get install -y --only-upgrade antigravity` boot-time upgrade
  - `workstation-image/boot/08-workspaces.sh` — removed `ANTIGRAVITY` variable and `launch_and_wait 2 30 "$ANTIGRAVITY" ...` ws2 block; ws2 is now empty
  - `workstation-image/configs/sway/config` — removed `$mod+n` (IDE desktop app) and `$mod+g` (IDE CLI terminal) keybindings
  - `scripts/cloud-build-setup.sh` — removed IDE apt comment and `which antigravity` verification from AI_VERIFY block
- **Hub placement rule added** — `workstation-image/configs/sway/config` gains:
  `for_window [app_id="antigravity"] move container to workspace number 1`
  Now unambiguous (IDE removed), this rule pins the Hub to ws1 regardless of when its
  BrowserWindow maps — defeating the async-mapping race condition.
- **Three-places persistence satisfied** — repo sway config, `~/.config/home-manager/sway-config`,
  and live `~/.config/sway/config` all updated; `swaymsg reload` confirmed success.
- **Boot tests updated** — `workstation-image/boot/10-tests.sh`:
  - Removed: IDE-present assertion, IDE version check, IDE ws2 launch check, `$mod+g→antigravity` keybinding check
  - Added: IDE-absent assertion, `for_window` rule presence check, IDE-keybindings-absent check, ws2-empty assertion

### Notes
- The Antigravity Hub (`~/.local/bin/antigravity-hub`) remains installed and functional.
  All Hub launch logic, auth flags, and ws1 focus handling in `08-workspaces.sh` are unchanged.
- ws2 is now empty — navigable via `$mod+i` but nothing launches there at boot.
- Live validation: Hub relaunched with focus on ws3; `swaymsg -t get_tree` confirmed Hub
  window landed on workspace 1 immediately.

## v1.24.8 — Hub keyring Secret Service for OAuth token persistence (2026-05-29)

### Fixed
- **Hub blank ws1 / logged-in state lost after first paint** (F-0115) — The Antigravity Hub
  authenticated successfully but immediately reverted to logged-out because the bundled
  `language_server` could not persist or reload its OAuth token: no Secret Service provider
  was running and `DBUS_SESSION_BUS_ADDRESS` was never exported to launched app processes.
  `language_server` logs confirmed:
  `auth_client.go:332] Failed to persist token to keyring: failed to unlock correct collection`
  `auth_client.go:106] Background token refresh failed: failed to load token: ...`

### Changed
- **`workstation-image/boot/08-workspaces.sh`** — Three changes:
  - Added `DBUS_ADDR="unix:path=/run/user/1000/bus"` constant near top
  - Added `DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR"` to the `env` block inside `launch_and_wait`
    so all launched Electron/`language_server` processes can reach the session bus
  - Added idempotent F-0115 block (before first `launch_and_wait`):
    - Logs WARNING and continues if `/usr/bin/gnome-keyring-daemon` is absent
    - Skips if `gnome-keyring-daemon` is already running (pgrep guard)
    - Otherwise starts `gnome-keyring-daemon --unlock --components=secrets` with empty
      password as `user` against the session bus; logs outcome
- **`workstation-image/boot/10-tests.sh`** — 4 new F-0115 grep-based tests:
  - Verifies `gnome-keyring-daemon --unlock` is present
  - Verifies `--components=secrets` is present
  - Verifies `DBUS_SESSION_BUS_ADDRESS` is exported in `launch_and_wait` env
  - Verifies idempotent `pgrep.*gnome-keyring-daemon` guard is present

### Notes
- `/usr/bin/gnome-keyring-daemon` is already present in the base Docker image (no new
  image rebuild required for this fix).
- `~/boot/08-workspaces.sh` and `~/boot/10-tests.sh` synced live immediately.
- `scripts/cloud-build-setup.sh` deploys boot scripts via tar — no change needed (verified).
- `docs/STARTUP_SCRIPTS.md` updated with F-0115 keyring note.

## v1.24.7 — Hub stale singleton lock cleanup before launch (2026-05-29)

### Fixed
- **Hub blank ws1 after unclean shutdown** (F-0114) — After an unclean reboot, stale
  `SingletonLock` / `SingletonCookie` / `SingletonSocket` files in
  `~/.config/Antigravity-Hub/` caused the Hub's bundled `language_server` to never report
  its dynamic port back to Electron; no BrowserWindow was created and ws1 remained blank.
  `launch_and_wait` timed out at 90 s. Root cause confirmed live: deleting the Singleton
  files and killing orphaned processes allowed the Hub to map in ~4 s.

### Changed
- **`workstation-image/boot/08-workspaces.sh`** — Added pre-launch cleanup block
  immediately before the Hub `launch_and_wait` call:
  - Kills orphaned `antigravity-hub/antigravity` processes by filtering `/proc/<pid>/exe`
    (safe: does not match the IDE's `/usr/bin/antigravity` or the boot script itself)
  - Kills orphaned `language_server` processes whose cmdline contains
    `antigravity-hub/resources` (safe: does not match IDE's language_server)
  - `rm -f /home/user/.config/Antigravity-Hub/Singleton*` after processes are reaped
  - Logs count of reaped processes + lock removal; no-op on a clean boot (nothing to kill)
- **`workstation-image/boot/10-tests.sh`** — 5 new F-0114 tests added:
  - Verifies `rm -f .../Antigravity-Hub/Singleton*` is present
  - Verifies exe-path filter `antigravity-hub/antigravity` is present
  - Verifies cmdline filter `antigravity-hub/resources` is present
  - Verifies log message `Cleared.*stale Hub processes.*singleton lock` is present
  - Fails if broad `pkill -f antigravity-hub` is found (safety regression guard)

### Notes
- `~/boot/08-workspaces.sh` and `~/boot/10-tests.sh` synced live immediately.
- `scripts/cloud-build-setup.sh` deploys boot dir via tar — no change needed (verified).
- Hub sign-in authentication is a separate manual step; out of scope for this fix.

## v1.24.6 — Remap workspace keybindings after Chrome/Hub swap (2026-05-29)

### Fixed
- **Keybinding mnemonic mismatch** (F-0113) — After F-0112 swapped the workspace assignments
  (ws1=Hub, ws5=Chrome), the sway keybindings were still pointing at the old numbers:
  - `$mod+h` (Hub mnemonic) was going to ws5, which is now Chrome — wrong
  - `$mod+u` was going to ws1, which is now Hub — no mnemonic meaning, confusing

### Changed
- **`workstation-image/configs/sway/config`** — Four bindings remapped:
  - `bindsym $mod+h workspace number 1` (was 5 — now correctly reaches the Hub)
  - `bindsym $mod+u workspace number 5` (was 1 — now reaches Chrome)
  - `bindsym $mod+Alt+h move container to workspace number 1` (was 5)
  - `bindsym $mod+Alt+u move container to workspace number 5` (was 1)
  - Layout comment added to workspace section for future reference
- **`~/.config/home-manager/sway-config`** — Identical change applied (Home Manager source)
- **`~/.config/sway/config`** — Live config updated and reloaded (`swaymsg reload` → success)
- **`workstation-image/boot/10-tests.sh`** — Tests updated:
  - F-0107 test corrected: asserts `$mod+h` → workspace 1 (was checking for workspace 5)
  - New test: `$mod+u` → workspace 5
  - New tests: `$mod+Alt+h` move → ws1, `$mod+Alt+u` move → ws5
- **`docs/specs/sway-keybindings.md`** — Cheat sheet updated: H→ws1(Hub), U→ws5(Chrome),
  with boot layout reference note and app labels for ws1–ws5

### Notes
- `~/boot/10-tests.sh` synced live. `scripts/cloud-build-setup.sh` deploys sway config via
  `cat` pipe from repo — no inline edit needed (verified lines 657-658, 731-732).
- Live reload validated: `swaymsg reload` returned `{"success":true}` via SWAYSOCK.
  `swaymsg -t get_config` confirms all four new bindings are active in the running compositor.
- PO does not need to reboot to use the new keybindings — they are live immediately.

---

## v1.24.5 — Swap Chrome and Hub workspace assignments (2026-05-29)

### Changed
- **Workspace layout** (F-0112) — Chrome and Antigravity Hub swap workspace positions:
  - **Before:** ws1 = Chrome, ws5 = Hub
  - **After:** ws1 = Hub, ws5 = Chrome
  - ws2 (Antigravity IDE), ws3 (foot), ws4 (foot) are unchanged.
- **`workstation-image/boot/08-workspaces.sh`** — Three targeted changes:
  1. Hub `launch_and_wait` now targets ws1 (was ws5). All F-0110/F-0111 flags, the 90s timeout, and the `hub-launch.log` redirect block travel with it.
  2. Chrome `launch_and_wait` now targets ws5 (was ws1). 15s timeout and `--disable-gpu` flag unchanged.
  3. Launch order updated: Chrome (ws5) launches first so the browser is available for IDE and Hub OAuth flows; Hub (ws1) second; IDE (ws2) third; foot terminals (ws3, ws4) last.
  4. End-of-boot focus is now unconditionally ws1 (Hub). Both success and timeout paths call `sway_cmd "workspace number 1"`, preserving the F-0110 intent (OAuth window visible on timeout) now that Hub IS ws1.
- **`workstation-image/boot/10-tests.sh`** — Tests updated:
  - Hub timeout test changed from `launch_and_wait 5 90` to `launch_and_wait 1 90`.
  - F-0098 workspace-order tests replaced with F-0112 layout tests (ws1=Hub, ws2=IDE, ws3=foot, ws4=foot, ws5=Chrome).
- **`docs/STARTUP_SCRIPTS.md`** — Execution flow updated with F-0112 workspace layout and launch order.

### Notes
- `~/boot/08-workspaces.sh` and `~/boot/10-tests.sh` updated live (three-places rule). `cloud-build-setup.sh` deploys boot dir via tar — no inline changes needed.
- `$mod+h` sway keybinding still maps to workspace 5 (now Chrome). This is a known semantic mismatch; a follow-up item will remap it to ws1 for the Hub.
- PO must reboot to validate the new layout. No live window-management changes were made (reboots required to test workspace autolaunch).

---

## v1.24.4 — Hub GPU-less fix and user-data-dir isolation (2026-05-29)

### Fixed
- **Hub ws5 blank window on GPU-less host** (F-0111) — Two distinct bugs prevented the Antigravity Hub from showing a usable window on ws5:
  1. `--use-gl=swiftshader` still spawned a GPU child process that immediately crashed in a `drmGetDevices2`/`Exiting GPU process` loop on a host with no GPU. The GPU process restarted repeatedly, preventing the renderer from initializing, leaving ws5 with a blank window. Fixed by replacing `--use-gl=swiftshader` with `--disable-gpu`, which prevents the GPU child process from starting entirely.
  2. The Hub binary defaulted to `~/.config/Antigravity` as its Electron userData directory — the same directory as the IDE binary on ws2. Electron's `ProcessSingleton` (SingletonLock/SingletonSocket) permits only one instance per userData directory. The IDE wins the lock (it boots first), so the Hub process ran silently with no window on ws5. Fixed by adding `--user-data-dir=/home/user/.config/Antigravity-Hub` to the Hub launch only.

### Changed
- **`workstation-image/boot/08-workspaces.sh`** — Three targeted changes:
  1. ws1 Chrome: `--disable-gpu` added (consistent GPU-less treatment; Chrome was working but had a silent crashing GPU process).
  2. ws2 Antigravity IDE: `--use-gl=swiftshader` → `--disable-gpu`.
  3. ws5 Antigravity Hub: `--use-gl=swiftshader` → `--disable-gpu`, `--user-data-dir=/home/user/.config/Antigravity-Hub` added.
- **`workstation-image/boot/10-tests.sh`** — 4 new F-0111 tests: Hub user-data-dir grep, IDE `--disable-gpu` grep, negative check that no `launch_and_wait` call still uses `--use-gl=swiftshader`.
- **`docs/STARTUP_SCRIPTS.md`** — Execution flow note added documenting the `--disable-gpu` flag choice and Hub `--user-data-dir` rationale.

### Notes
- Live validated before commit: Hub window appeared on ws5 within 15s with `--disable-gpu --user-data-dir=/home/user/.config/Antigravity-Hub`; no GPU process crash errors in launch log; `Starting app (v2.0.10)` and language server spawn confirmed.
- IDE userData directory (`~/.config/Antigravity`) is unchanged — auth tokens remain valid for the IDE.
- `~/boot/08-workspaces.sh` and `~/boot/10-tests.sh` updated live (three-places rule). `cloud-build-setup.sh` deploys the boot dir via tar — no inline script changes needed there.

---

## v1.24.3 — Hub WS5 Auth-Friendly Launch (2026-05-29)

### Fixed
- **Hub workspace 5 disappears after boot** (F-0110) — Antigravity Hub's window never registered within the previous 30-second timeout because the Google OAuth flow delays first-paint by 30–60 seconds. Hub timed out silently and focus switched back to ws1, hiding the auth window from the user.

### Changed
- **`workstation-image/boot/08-workspaces.sh`** — Three targeted changes at the Hub call site only:
  1. Hub `launch_and_wait` timeout raised from 30s → **90s** to accommodate OAuth first-paint delays.
  2. Hub stdout and stderr now redirected to **`~/logs/hub-launch.log`** (append mode, per-boot timestamp header `=== Hub launch: YYYY-MM-DD HH:MM:SS ===`), enabling diagnosis of auth failures without re-running the service.
  3. Final `sway_cmd "workspace number 1"` is now **conditional**: only executes when Hub launched successfully (`HUB_OK=0`). On timeout, focus remains on ws5 so the OAuth window is visible when it eventually paints.
- **`workstation-image/boot/10-tests.sh`** — Replaced false-positive Hub test (was grepping for a literal inline arg string that no longer exists after the redirect wrap) with three accurate tests: Hub timeout=90, hub-launch.log redirect presence, HUB_OK conditional logic.
- **`docs/STARTUP_SCRIPTS.md`** — Added `~/logs/hub-launch.log` to the Logs table.

### Fixed (validation patch)
- **`launch_and_wait` returned 0 on timeout** — the timeout path ended with `log "WARNING: ..."` (exit code of `echo`), so `HUB_OK=$?` was always 0 and the "stay on ws5" conditional was dead code. Added `return 1` immediately after the warning log line. Added a corresponding test in `10-tests.sh` (`grep -A1 "WARNING: Timeout" | grep -q "return 1"`).

### Notes
- `launch_and_wait` function signature is unchanged; the redirect and timeout change are isolated to the Hub call site. All other workspace timeouts (ws1=15, ws2=30, ws3=5, ws4=5) are unchanged.
- On a successful Hub launch (OAuth already completed from a prior boot), behaviour is identical to before: focus returns to ws1 after the workspace sequence completes.

---

## v1.24.1 — Fix SSH Authentication in Boot Sync (2026-05-29)

### Fixed
- **Boot sync SSH authentication failure** (F-0109) — `09-sync.sh` runs as root at boot to pull latest repo and sync configs. Root has no GitHub SSH key, causing silent "Permission denied (publickey)" failures on every boot. Fixed by passing `GIT_SSH_COMMAND` environment variable that explicitly uses user's `/home/user/.ssh/id_ed25519` key with `StrictHostKeyChecking=accept-new` (safe, non-interactive). Git pull now succeeds when running as root, enabling config updates to propagate to live workstations on every boot.

### Changed
- **`workstation-image/boot/09-sync.sh`** — Line 35: Added `GIT_SSH_COMMAND="ssh -i ${USER_HOME}/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${USER_HOME}/.ssh/known_hosts"` before `git pull --ff-only` invocation
- **`workstation-image/boot/10-tests.sh`** — Added 4 new boot tests for F-0109: verify GIT_SSH_COMMAND is set, verify SSH key path is id_ed25519, verify StrictHostKeyChecking safety setting

### Notes
- Boot sync remains non-fatal: if git pull still fails for any reason, the error is logged and boot continues using existing scripts on disk
- Fixes the root cause of config drift on live workstations — boot sync was silently failing while appearing to succeed in the log

---

## v1.24 — Automatic Boot Script Sync (2026-05-29)

### Added
- **Automatic boot script sync** (F-0108) — New `06-sync.sh` script runs on every boot to automatically synchronize boot scripts and Sway config from the git repo. Pulls latest code from repo and copies `workstation-image/boot/*.sh` to `~/boot/` and `workstation-image/configs/sway/config` to `~/.config/home-manager/sway-config`. Graceful error handling: missing repo or git pull failures are logged as warnings and do not fail the boot sequence.
- **Boot tests for sync** — Added verification tests to `10-tests.sh` ensuring `06-sync.sh` exists, has correct repo path, and creates log file with success markers
- **Sync log** — All sync operations logged to `~/logs/sync.log` for troubleshooting

### Changed
- **Boot sequence** — `06-sync.sh` added as order 6 script (before `06-prompt.sh`), ensuring subsequent boot scripts always have latest repo code
- **`docs/STARTUP_SCRIPTS.md`** — Updated boot sequence table with `06-sync.sh` entry, execution flow diagram, and logs section

### Notes
- **Bootstrap procedure**: On first deployment, user manually copies `workstation-image/boot/06-sync.sh` to `~/boot/06-sync.sh` and optionally runs it once; thereafter, it auto-syncs on every boot
- Graceful failure: If git repo is missing (e.g., freshly provisioned workstation not yet with repo clone), `06-sync.sh` logs a warning and continues boot using existing scripts on disk
- Non-fatal git errors: If `git pull --ff-only` fails (network down, merge conflict, etc.), the error is logged and sync is skipped; boot continues with existing scripts

---

## v1.23 — Antigravity Hub Auto-Launch + GPU Flag Fix (2026-05-29)

### Added
- **Workspace 5 auto-launch with Antigravity Hub** (F-0107) — Antigravity Hub now launches automatically in workspace 5 on boot, completing the auto-launch workspace setup (Chrome ws1, IDE ws2, terminals ws3-4, Hub ws5). Hub launch uses the same 30-second timeout as Antigravity IDE for full initialization.
- **Boot tests for keybinding uniqueness** (F-0107) — Added test assertions that `$mod+h` keybinding maps uniquely to `workspace number 5` (not duplicated as an exec), and that Hub auto-launch configuration is present in 08-workspaces.sh.

### Changed
- **`workstation-image/boot/08-workspaces.sh`** — Header updated to "5 workspaces", added HUB variable and ws5 launch block with guard condition, fixed ws2 Antigravity IDE GPU flags from `--disable-gpu` to `--use-gl=swiftshader` (closes blank-window bug on Wayland with nvidia GL libraries).
- **`workstation-image/configs/sway/config`** — Removed duplicate `$mod+h exec` binding that launched Hub (line 110 in v1.22), keeping only `workspace number 5` switch binding (line 179). Hub is now auto-started on boot, so manual keybinding launch is redundant. Also updated Antigravity IDE binding (`$mod+n`) from `--disable-gpu` to `--use-gl=swiftshader`.
- **`workstation-image/boot/10-tests.sh`** — Added tests for keybinding conflict fix (exactly one `$mod+h`, maps to workspace 5) and Hub ws5 auto-launch configuration in boot script.

### Fixed
- **`$mod+h` keybinding conflict** (F-0107) — In v1.22, `$mod+h` was defined twice: once to exec Hub, once to switch to workspace 5. Now it maps only to workspace 5, with Hub launched automatically on boot. Resolves the config ambiguity and simplifies the workspace-switching model.
- **Antigravity IDE blank-window bug** (F-0107) — Changed IDE Electron flags from `--disable-gpu` to `--use-gl=swiftshader`, fixing blank windows on Wayland when Nix nvidia GL libraries conflict with headless VNC rendering. Same fix applied to Hub launch flags.

### Notes
- Hub auto-launch timeout (30s) matches Antigravity IDE, is longer than terminals (5s), and is longer than Chrome (15s) to allow full UI initialization before returning focus to ws1.
- `$mod+h` keybinding now provides fast workspace switching to ws5, consistent with other workspace keybindings (`$mod+u/i/o/p/j/k/l`).
- Three-places rule: Home Manager sway-config on live workstations must be manually synced when deployed. See `docs/specs/F-0107-antigravity-hub-workspace.md`.

---

## v1.22 — Antigravity 2.0 Desktop App (Hub) (2026-05-29)

### Added
- **Antigravity 2.0 Desktop App (Hub)** — Standalone graphical launcher and project hub interface. Installed on first boot if missing, persists on subsequent boots. Location: `~/.local/share/antigravity-hub/`. Launcher symlink: `~/.local/bin/antigravity-hub`. Version 2.0.10 via GCS direct download (no apt package available).
- **Hub keybinding** — `$mod+h` launches Antigravity Hub with full Electron support (Wayland, GPU disabled for headless VNC, dev-shm constraints handled)
- **Boot tests for Hub** — Verification tests for Hub directory, symlink, and keybinding presence

### Changed
- **`07-apps.sh`** — Added Antigravity Hub download/extract/symlink block (idempotent: first boot only). URL is hardcoded; update required when new version released.
- **`workstation-image/configs/sway/config`** — Added `$mod+h` keybinding for Hub launch, placed alongside existing `$mod+n` (IDE) and `$mod+g` (CLI) Antigravity bindings
- **`10-tests.sh`** — Added three tests for Hub (directory existence, symlink existence, keybinding in config)

### Notes
- Hub is a separate product from the existing Antigravity IDE (apt) and CLI (curl installer)
- All three Antigravity products now available: IDE (`$mod+n`), Hub (`$mod+h`), CLI (`$mod+g`)
- Requires manual Home Manager sway-config sync on live workstations using HM-managed configs (`~/.config/home-manager/sway-config` must match repo config's `$mod+h` keybinding for persistent effect across reboots)

---

## v1.21 — Antigravity 2.0 + CLI (2026-05-29)

### Added
- **Antigravity CLI** — `curl -fsSL https://antigravity.google/cli/install.sh | bash` installs the new Antigravity CLI. Installed on first boot if missing, updated on every subsequent boot. Available on PATH via `~/.local/bin/antigravity-cli`
- **Antigravity 2.0** — Auto-updater repo delivers Antigravity 2.0 automatically from the base apt package. Desktop app (binary at `/usr/bin/antigravity`) launches via `$mod+n` keybinding
- **CLI keybinding** — `$mod+g` launches Antigravity CLI in a new foot terminal window
- **Boot tests** — Added verification tests for Antigravity 2.0 binary (`/usr/bin/antigravity`) and CLI (`~/.local/bin/antigravity-cli` or on PATH)

### Changed
- **`07-apps.sh`** — Added Antigravity CLI idempotent install block (first boot + every-boot update)
- **`sway/config`** — Comment updated to "Antigravity 2.0 desktop app", `$mod+g` added for CLI launch
- **`08-workspaces.sh`** — Workspace 3 comment updated to reference Antigravity 2.0
- **`cloud-build-setup.sh`** — Added Antigravity CLI curl install during fresh provisioning, updated verification step
- **`10-tests.sh`** — Added two new tests for Antigravity 2.0 and CLI verification

### Notes
- Antigravity 2.0 delivery via existing apt package + auto-updater repo (no package name change)
- Gemini CLI preserved alongside new CLI tools during transition period
- `~/.local/bin` already in PATH; CLI will be found automatically after install

---

## v1.17.2 — Xwayland -rootless persistence (2026-04-15)

Patch release covering F-0097. Closes the loop on the F-0096 fix (v1.17.1 /
v1.20) by making the `-rootless` flag survive reboots, and hardens the
boot test so any future regression fails at boot instead of silently
reintroducing the workspace-1 split.

### Fixed
- **Xwayland `-rootless` now persists across reboots** (F-0097) — Xwayland is now started from sway autostart via `xwayland disable` + `exec /usr/bin/Xwayland -rootless :0 &` in `workstation-image/configs/sway/config`, so the flag is present on every boot. Previously the F-0096 fix only applied during the session it was deployed in; after a reboot, sway's default Xwayland launch took over without `-rootless`, silently reintroducing the 50/50 workspace-1 split. See `docs/specs/F-0097-xwayland-rootless-persistence.md`.

### Changed
- **`workstation-image/boot/10-tests.sh` — runtime Xwayland assertion** (F-0097) — the boot test now asserts that the *running* Xwayland process command line contains `-rootless` (reads `/proc/<pid>/cmdline` for the live process), rather than only grepping the static config for the flag. Catches the F-0097 class of regression — correct config on disk but wrong process actually running — that a static grep would miss.

---

## v1.20 — Xwayland ws1 split fix (2026-04-15)

### Fixed
- **Xwayland no longer splits workspace 1** (F-0096) — `workstation-image/boot/08-workspaces.sh` now launches Xwayland with `-rootless`, the standard mode under a Wayland compositor. Previously, rootful Xwayland painted a workspace-sized root window that Sway tiled 50/50 alongside the autostart foot terminal on ws1. With `-rootless`, no phantom root surface is created and ws1 opens to a single fullscreen foot terminal matching ws2/ws3/ws4. See `docs/specs/F-0096-xwayland-ws1-split.md`.

---

## v1.18 — Claude Code Auto-Update Fix (2026-04-15)

Fixes the Claude Code in-process auto-updater so it can write to the
persistent disk instead of failing with `EACCES` on the ephemeral
`/usr/lib/node_modules` path.

See [docs/specs/F-0093-claude-autoupdate-fix.md](specs/F-0093-claude-autoupdate-fix.md).

### Fixed
- **Claude Code auto-updater `EACCES` on `/usr/lib/node_modules`** (F-0093) — the in-process auto-updater no longer fails when Claude tries to self-upgrade. Root cause: `install_claude_code` in `workstation-image/boot/11-custom-tools.sh` passed `--prefix=/home/user/.npm-global` inline only, so `npm config get prefix` still returned `/usr` (the base-image default) and any later `npm -g` invocation — including Claude Code's auto-updater — tried to write to the root-owned ephemeral `/usr/lib/node_modules`. Fix: `install_claude_code` now idempotently writes `prefix=/home/user/.npm-global` to `~/.npmrc`, so every `npm -g` invocation targets the persistent disk

### Added
- **Boot test for npm prefix** — `workstation-image/boot/10-tests.sh` now asserts `npm config get prefix` equals `/home/user/.npm-global`, catching any regression that would silently break the Claude Code auto-updater on future boots

---

## v1.19 — Foot Terminal CWD Regression Drift Guards (2026-04-15)

Third occurrence of the "foot does not start in `/home/user`" class of bug.
The configs were actually correct — the previous F-0087 boot test had
gone stale and was still looking for its own `cd ~ &&` pattern, so a
later drift back to the `--working-directory=/home/user` style (from
`0dd33b3`) passed the test silently instead of failing it. The fix
hardens the boot test into three drift guards so a fourth regression
fails `~/logs/boot-test-summary.txt` on the next boot.

### Fixed
- **Foot terminal CWD regression** (F-0095) — foot now reliably opens
  with `pwd=/home/user` from sway `$mod+Return`, `$mod+t`, and the
  autostart workspace script. Standardized on
  `--working-directory=/home/user` as the single CWD-guard style;
  F-0087's `cd ~ &&` wrapper is superseded. Root cause was a stale
  boot-test assertion, not a config regression — the configs already
  carried the correct flag

### Changed
- **`workstation-image/boot/10-tests.sh` — three R4 drift guards**
  (F-0095) replacing the single F-0087 `cd ~ &&` grep:
  - **R4a** — every sway keybinding that launches foot must carry
    `--working-directory=/home/user` (checks `$mod+Return`, `$mod+t`,
    and any other foot-launching binding in the active
    `~/.config/sway/config`)
  - **R4b** — every `foot` invocation in
    `workstation-image/boot/08-workspaces.sh` must carry the same
    flag; matcher broadened after SWE-Test caught a regex gap where a
    bare `"$FOOT"` at end of line slipped through
  - **R4c** — the repo `workstation-image/configs/sway/config` and
    the deployed `~/.config/home-manager/sway-config` must be
    byte-identical on the lines that launch foot, catching
    three-places-rule drift at boot instead of at the user

### Docs
- **F-0095 spec** — `docs/specs/F-0095-foot-cwd-regression.md`
  captures the regression history (`0dd33b3` → F-0087/`e7236a8` →
  F-0095), the four-hypothesis root-cause framework used during
  diagnosis, and the drift-guard requirement so any future repeat of
  this class is caught automatically

### Verification Status
- **Statically verified:** configs carry the correct flag in all three
  sources (repo / home-manager source / setup script); R4a/R4b/R4c
  assertions compile and run
- **Live-verified on the currently-drifted workstation:** R4 drift
  guards correctly produce a FAIL in
  `~/logs/boot-test-summary.txt` when any of the three sources is
  corrupted — AC3 headline validated
- **Pending live verification:** AC1 (`$mod+Return` → `pwd`), AC2
  (autostart foot windows), AC4(b) (teardown + re-setup on this
  project), AC4(c) (fresh project setup). PO to choose between
  verify-before-PR, verify-post-merge, or an SWE-QA light-verification
  pass before Milestone 20 closes

---

## v1.17 — GCP Organization Alignment, Font Cleanup, Fork Retrospective (2026-04-15)

This release captures the final alignment of the fork with the deployed
GCP Organization environment and cleans up the terminal font stack. It
also adds a retrospective **Fork Divergence Summary** covering fork-only
work that pre-dated the v1.14–v1.16 release notes and had never been
formally documented.

### Added
- **GCP Organization deployment alignment** (F-0091) — `scripts/cloud-build-setup.sh` rewritten to target the live deployed configuration: region `us-central1`, cluster `main-cluster`, config `sway-config`, workstation `sway-workstation`, image `dev-workstation:latest`, dedicated `sway-workstation-sa` service account, custom `workstations-vpc` (10.0.0.0/24), 2h idle timeout, daily 8PM Central stop scheduler
- **Nix-managed open-source fonts** — `cascadia-code`, `fira-code`, and `jetbrains-mono` added to `home.packages` so they are present on fresh setups without a tarball upload

### Changed
- **Machine spec** (F-0090) — documented target is now `n2-standard-8` with 200GB `pd-balanced` and **no GPU**. T4 GPU quota removed as a prerequisite. `02-nvidia.sh` is a documented no-op on this profile. README, SETUP.md, and STARTUP_SCRIPTS.md updated accordingly
- **Font deployment via Cloud Build** — only Operator Mono (~264K) is piped through `gcloud workstations ssh` (previously the full 61MB dev-fonts tarball hit the 300s timeout and silently failed). `--ssh-flag="-T"` added to prevent TTY corruption of binary stdin. Setup verify now does a real OTF count check instead of unconditional `test_pass`, and splits `fonts_operator` / `fonts_cascadia` so each deployment path is checked independently
- **Foot terminal font** — switched to `DejaVu Sans Mono` (confirmed present on the system) as the single source of truth managed only by `06-prompt.sh`. Home Manager no longer manages `foot.ini`, eliminating the double-write that resolved `font=monospace` to the proportional Noto Sans Regular and produced the "non-monospaced font" warning on every terminal open
- **Boot test** — `10-tests.sh` updated to assert the correct configured font

### Fixed
- **Silent font deployment failure** — root cause (tarball too large for SSH timeout) is fixed rather than hidden; the `font-monospace-warn=no` suppression is removed since the real warning is gone

---

## Fork Divergence Summary (retrospective, pre-v1.14)

The following fork-only work shipped in the markjkelly fork before the v1.14
release notes began tracking it. Documented here so the release history is
complete.

### Cloud Build Pipeline (F-0088)
- `cloudbuild/ws-image.yaml` — builds and pushes the workstation Docker image to Artifact Registry via Cloud Build, replacing manual `docker build/push` cycles
- `_AR_PROJECT` substitution so the Artifact Registry project can differ from the build project
- Integrated into the `ws.sh setup` flow so a `git push` + `ws.sh setup` cycle produces a fresh image

### Custom Tools Module (F-0089)
- New boot script `workstation-image/boot/11-custom-tools.sh` installs tools that are either unavailable in Nix or must live on the persistent disk to survive image rebuilds:
  - **Terraform** — pinned version, installed to `~/.local/bin`
  - **GitHub CLI (`gh`)** — pinned version, installed to `~/.local/bin`
  - **Java** — installed via SDKMAN into `$HOME`
  - **Eclipse IDE** — installed to the persistent disk
  - **Claude Code** — installed to `~/.npm-global` on boot
- Auto-launch of workspace apps disabled by default in this module so the user chooses what to start

### VNC Keyboard Compatibility (F-0090)
- `wayvnc --keyboard=us` so key codes are encoded correctly for the browser client
- `term=xterm-256color` added to `foot.ini` for VNC keyboard compatibility
- Boot-time patch of `noVNC`'s `rfb.js` to disable QEMU extended key events (fixes broken special keys in the browser)

### Fonts & Terminal
- JetBrains Mono installed via apt as a persistent boot-time step (later superseded by Nix packages in v1.17)
- Foot terminal non-monospace font warning suppressed (later root-caused and removed in v1.17)

### Docs & Templating
- `GEMINI.md` added with project context and branching/PR conventions for Gemini-driven workflows
- `REPO_URL` placeholder updated to point at the markjkelly fork

---

## v1.16 — Terminal UX (2026-04-15)

### Fixed
- **Foot terminals now open in `$HOME`** — sway bindings (`$mod+Return`, `$mod+t`) previously inherited sway's cwd, causing new terminals to start in whatever directory sway was launched from. Bindings now `cd ~` before exec. Boot test added to `10-tests.sh`.

---

## v1.15 — Composable Install Profiles (2026-04-02)

### Added
- **Install profiles** — choose `minimal`, `dev`, `ai`, `full`, or `custom` profile via `--profile` flag to control what gets installed. Minimal profile builds in ~14 min vs ~55 min for full (75% faster)
- **`--profile` flag** for `ws.sh setup` — selects a predefined set of modules (e.g., `--profile minimal`)
- **`--modules` flag** for `ws.sh setup` — enables individual modules with `--profile custom --modules "ides,ai-tools"`
- **`~/.ws-modules` config file** — records which modules are enabled. Boot scripts and tests automatically adapt to the selected profile
- **`ws-modules.sh` helper** — provides `ws_module_enabled()` function for boot scripts to check whether a module is enabled before running
- **Dynamic `home.nix` generation** — `cloud-build-setup.sh` generates Nix Home Manager config with only the packages needed for the selected profile. AI IDEs (Cursor, Windsurf, Zed, VSCode, IntelliJ) only included for ai/full profiles
- **Conditional boot tests** — `10-tests.sh` reports SKIP for disabled modules instead of FAIL, keeping test results clean and actionable

### Changed
- **`setup.sh`** — boot scripts now check `ws_module_enabled <module>` and skip if their module is disabled
- **`cloud-build-setup.sh`** — language and AI tool install steps gated by profile; `home.nix` generated dynamically

### Fixed
- **`ws-modules.sh` `$HOME` bug** — `$HOME` is empty when sourced by root during Cloud Build setup. Changed to hardcoded `/home/user` path

### Performance
| Profile | Build Time | Tests |
|---------|-----------|-------|
| minimal | ~14 min | 46 PASS, 0 FAIL, 8 SKIP |
| full | ~55 min | 77 PASS, 1 FAIL (false positive), 0 SKIP |

---

## v1.14 — Tailscale, tmux, Persistence (2026-04-02)

### Added
- **Tailscale VPN** — opt-in via `TAILSCALE_AUTHKEY` in `~/.env`. Auto-installs if missing (ephemeral root disk), auto-connects with SSH enabled, configures iptables
- **USER_PASSWORD** — set SSH password via `~/.env` for Tailscale/Termius access, auto-set on boot
- **claude-tmux wrapper** — crash-resistant tmux sessions that auto-launch `claude --dangerously-skip-permissions`. Aliases: `t1`-`t10`, `cc`, `tdbg`
- **tmux-debug** — same as claude-tmux but with server-level logging to `~/logs/tmux/`
- **tmux.conf** — Tokyo Night theme with true color, mouse, vi copy mode, auto-rename windows to current directory
- **Boot script 06b-tmux.sh** — deploys tmux.conf + claude-tmux + tmux-debug on boot
- **.gitignore** — protects `.env`, `*-sa-key.json` from accidental commit

### Fixed
- **PII scrubbed** from all docs (project IDs, emails, names replaced with placeholders)
- **ZSH aliases** — `~/.zsh/zsh_aliases.sh` now sourced in Home Manager initContent (was missing)

### Verified
- Full cycle: teardown 14 min + build 56 min + boot tests 5 min = ~76 min total
- Setup script: 52 PASS, 0 FAIL
- Boot tests: 77 PASS, 0 FAIL (1 false positive WARN)

---

## v1.13 — Setup Script Hardening & Boot Tests (2026-04-01)

### Added
- **Boot test script** (`10-tests.sh`) — 80+ automated tests across 12 categories, runs via systemd after all services up. Results at `~/logs/boot-test-{results,summary}.txt`
- **STARTUP_SCRIPTS.md** — full documentation of all 14 boot scripts, execution flow, logs

### Changed
- **Setup script bulletproofed** — SSH commands have 5-min timeout (15-min for long ops), Nix install split into download+install, silent `|| true` removed
- **AR race condition fixed** — 30s propagation wait + verification loop after Artifact Registry creation
- **Verified teardown** — all 9 resource types have `wait_deleted` polling: workstation, config, cluster, AR, NAT, router, scheduler, cloud function, cloud builds
- **Unified .zshrc** — Home Manager `programs.zsh` is single source of truth; `05-shell.sh` defers when Home Manager manages `.zshrc`
- **10-tests.sh via systemd** — runs after ws-autolaunch.service instead of during setup.sh, preventing false FAILs from services not yet started

### Fixed
- **AI tools install** — OpenCode, Aider, GH Copilot now properly install in setup script with error handling
- **Missing ZSH/Starship** — added to inline home.nix in setup script (was missing `programs.zsh` block)
- **Test false positives** — Zed binary name (`zeditor`), OpenCode version flag, Aider PATH, GH Copilot extension check

---

## v1.12 — AI IDEs, CLI Tools, and Timezone Fix (2026-03-31)

### Added
- **Cursor IDE** (v2.6.22) — AI-powered VSCode fork, installed via Nix Home Manager (`code-cursor`). Sway keybinding: `CTRL+SHIFT+C` with Electron flags and `env -u LD_LIBRARY_PATH` for nvidia compatibility
- **Windsurf IDE** (v1.108.2) — AI-powered VSCode fork, installed via Nix Home Manager (`windsurf`). Sway keybinding: `CTRL+SHIFT+W` with same Electron flags pattern
- **Zed IDE** (v0.229.0) — GPU-accelerated code editor, installed via Nix Home Manager (`zed-editor`). Launched from terminal
- **Aider** (v0.86.2) — AI pair programming CLI tool, installed via pip (Nix build fails due to sandbox network restrictions). Available as `aider` from the terminal
- **Sourcegraph Cody CLI** (v5.5.26) — AI coding assistant CLI, installed via npm global (`@sourcegraph/cody`). Upgrades on every boot
- **pi-coding-agent** (v0.64.0) — AI coding agent CLI, installed via npm global (`@mariozechner/pi-coding-agent`). Upgrades on every boot
- **GitHub Copilot CLI** — `gh copilot` extension installed on first boot, upgraded on subsequent boots. Enables `gh copilot suggest` and `gh copilot explain` commands

### Fixed
- **Timezone consistency** — Set `TZ=America/Los_Angeles` in three locations: `sway-desktop.service` (all sway child processes), `.zshrc` (interactive shells), and `sway-status` (status bar clock). All displays now show Pacific Time instead of UTC

### Changed
- **`home.nix`** — Added `code-cursor`, `windsurf`, and `zed-editor` to Nix Home Manager packages
- **`07-apps.sh`** — Added `@sourcegraph/cody` and `@mariozechner/pi-coding-agent` to npm global update line; added `gh extension install/upgrade gh-copilot` step; added `pip install aider-chat` step
- **`sway/config`** — Added `CTRL+SHIFT+C` (Cursor) and `CTRL+SHIFT+W` (Windsurf) keybindings following the established Electron IDE pattern
- **`03-sway.sh`** — Added `Environment=TZ=America/Los_Angeles` to sway-desktop.service
- **`05-shell.sh`** — Added `export TZ="America/Los_Angeles"` to .zshrc template
- **`sway-status`** — Added `export TZ="America/Los_Angeles"` at top of script

---

## v1.11 — AI CLI Tools Expansion (2026-03-31)

### Added
- **Codex CLI** (`@openai/codex` v0.118.0) — OpenAI's CLI coding assistant, installed via npm global alongside Claude Code and Gemini CLI. Upgrades to latest on every boot
- **OpenCode** (v0.0.55) — Open-source AI coding assistant, installed via `go install` to `$GOPATH/bin` on the persistent disk. Upgrades to latest on every boot

### Changed
- **`07-apps.sh`** — Updated npm global update line to include `@openai/codex` alongside `@anthropic-ai/claude-code` and `@anthropic-ai/gemini-cli`. Added `go install` step for OpenCode with proper GOROOT/GOPATH configuration

### Notes
- Requires Go from Milestone 8 (F-0050) for OpenCode installation
- API key configuration is user-managed (not included in boot scripts)

---

## v1.10 — UX Polish: Wofi, Clipboard, Snippets (2026-04-01)

### Added
- **Wofi app launcher styling** — Created `~/.config/wofi/config` (drun mode, case-insensitive search, app icons) and `~/.config/wofi/style.css` with Tokyo Night theme (bg=#1a1b26, accent=#7aa2f7, text=#c0caf5, rounded corners, modern look)
- **Snippet picker** (`~/.local/bin/snippet-picker`) — Wofi-based script that reads snippets from `~/.config/snippets/snippets.conf` (pipe-delimited `label | value` format), presents labels in a Wofi menu, and copies the selected snippet value to clipboard via `wl-copy`. Invoked with CTRL+SHIFT+S
- **Default snippet config** (`~/.config/snippets/snippets.conf`) — Starter snippets for common text (email, commands, code patterns). User-editable; boot script preserves existing customizations (no-clobber)
- **Boot scripts** — `09-wofi.sh` (deploys wofi config + style), `09-snippets.sh` (deploys snippet picker + default config with no-clobber)

### Fixed
- **Wofi app launcher (CTRL+SHIFT+R)** — Was only showing Antigravity because `XDG_DATA_DIRS` was empty in sway's environment. Fixed by setting `XDG_DATA_DIRS=/home/user/.nix-profile/share:/usr/share:/usr/local/share` and wrapping with `env -u LD_LIBRARY_PATH`. Now shows all Nix-installed and system apps
- **Clipboard history daemon (CTRL+SHIFT+A)** — `wl-paste + clipman store` daemon was not starting due to nvidia `LD_LIBRARY_PATH` conflict breaking Nix binaries. Fixed by wrapping autostart with `env -u LD_LIBRARY_PATH`. Also fixed `clipman pick --tool` invocation: expects tool name (`wofi`) not full path, so added Nix bin to PATH in exec
- **Snippet picker (CTRL+SHIFT+S)** — Keybinding existed but referenced a script (`~/.local/bin/snippet-picker`) that was never created. Script now exists and functions correctly

### Not Shipped
- **Waybar switch** — Attempted replacing swaybar with waybar but reverted: waybar uses wlr-layer-shell protocol which doesn't render through wayvnc in the headless Sway setup. Waybar config preserved in repo for future activation when layer-shell support is available. Swaybar remains the active bar

---

## v1.9 — Fix IDE Keybindings (2026-03-31)

### Fixed
- **IntelliJ keybinding (CTRL+SHIFT+M)** — binary name corrected from `idea-community` to `idea-oss` (matching Nix Home Manager package name). Added `DISPLAY=:0` so IntelliJ connects to system Xwayland instead of broken Nix-packaged Xwayland
- **VSCode keybinding (CTRL+SHIFT+Y)** — wrapped exec with `env -u LD_LIBRARY_PATH` to prevent nvidia's `libGLESv2.so.2` from shadowing the Nix version (was causing `undefined symbol: _glapi_tls_Current` crash)
- **Xwayland startup failure** — added `xwayland disable` to sway config to prevent Sway's built-in Xwayland (Nix binary) from starting under nvidia LD_LIBRARY_PATH, which caused `libX11.so.6: cannot open shared object file`. System Xwayland (`/usr/bin/Xwayland :0`) is launched explicitly instead

### Root Cause
All three bugs shared a common root cause: the nvidia `LD_LIBRARY_PATH=/var/lib/nvidia/lib64` set by `sway-desktop.service` injects nvidia GL libraries into the search path, shadowing Nix-provided libraries and breaking symbol resolution for Nix-built applications (Xwayland, VSCode/Electron). The fix applies per-app workarounds rather than changing the global GPU configuration.

---

## v1.8 — Programming Language Support (2026-03-31)

### Added
- **Go** (latest stable via direct tarball from go.dev) — installs to `~/go` (GOROOT) and `~/gopath` (GOPATH). Auto-detects latest version, updates on boot if newer available
- **Rust** (via `rustup`) — installs stable toolchain to `~/.rustup` and `~/.cargo`. Runs `rustup update` on subsequent boots
- **Python 3.12** (via `pyenv`) — compiles from source, installs to `~/.pyenv`. pyenv updated on boot; Python rebuild only on manual request
- **Ruby 3.3** (via `rbenv` + `ruby-build`) — compiles from source, installs to `~/.rbenv`. rbenv/ruby-build updated on boot; Ruby rebuild only on manual request
- **Boot script `07a-lang-deps.sh`** — installs apt build dependencies (build-essential, libssl-dev, zlib1g-dev, etc.) required by pyenv and rbenv to compile Python/Ruby from source
- **Boot script `07b-languages.sh`** — idempotent language installer. First boot installs all 4 languages (~15 min for Python/Ruby compilation); subsequent boots verify and update version managers in under 30 seconds. Logs to `~/logs/language-install.log`
- **Shell integration** — Go (GOROOT, GOPATH), Rust (~/.cargo/bin), pyenv init, and rbenv init added to `.zshrc` PATH
- **Language version management docs** in README.md — covers installed languages, version managers, and how to install additional versions

### Changed
- **`cloud-build-setup.sh`** — expanded from 17 to 19 steps: Step 18 installs language build deps + version managers, Step 19 verifies all language binaries on PATH
- **`setup.sh`** — updated glob pattern to support letter-suffixed boot scripts (`07a-*`, `07b-*`) in execution order

### Architecture
- **Hybrid approach**: Nix continues to manage system tools (ripgrep, neovim, tmux, VS Code, etc.), while native version managers handle programming languages for multi-version support and familiar developer workflows
- **No /nix copy needed**: All language managers install entirely within `$HOME` on the 500GB persistent SSD, surviving reboots naturally
- **Apt build deps are ephemeral**: Reinstalled on every boot by `07a-lang-deps.sh` since the Docker image is ephemeral; keeps the Docker image lean

---

## v1.7 — Repo Templatization (2026-03-26)

### Added
- **`scripts/configure.sh`** — Onboarding script for colleagues. Prompts for 7 values (GCP project, org, name, email, GitHub), validates inputs, and applies sed replacements across all config files
- **README Quick Start** — Added 3-step quick start section and configure.sh step in setup flow
- **Private repo backup** — Personal repo with all project-specific values pushed to `your-private-repo` (private)

### Changed
- **Templatized 38 files** — Replaced all personal/org-specific info with generic placeholders (`YOUR_PROJECT_ID`, `your-email@example.com`, etc.) across CLAUDE.md, agent configs, skill configs, setup docs, specs, and scripts
- **Public repo is now shareable** — Any colleague can clone, run configure.sh, and deploy their own workstation

### Fixed
- **Persistent `.env` sourcing** — `05-shell.sh` was overwriting `.zshrc` on every boot, losing `source ~/.env`. Added env sourcing to the `.zshrc` template so Claude Code Vertex AI config survives reboots

---

## v1.6 — Multi-Project Hardening (2026-03-24)

### Added
- **17-step setup script** (`cloud-build-setup.sh`) — expanded from 15 steps with Nix persistence (Step 11) and noVNC desktop verification (Step 17)
- **Weekday-only Cloud Scheduler** — `ws-weekday-start` (6AM Mon-Fri) and `ws-weekday-stop` (9PM Mon-Fri). Workstations stay off on weekends
- **25-test post-setup verification suite** — covers Sway, swaybar, wayvnc, noVNC, Antigravity, Nix, fonts, ZSH, Starship, AI tools, Cloud Scheduler, Chrome, VS Code
- **Consolidated `ws.sh`** — single script for setup (via Cloud Build) and teardown with webhook + email notifications

### Fixed
- **Fresh GCP project support** — auto-creates default VPC network, grants permissions to both Cloud Build and Compute Engine SAs, adds `--service-account` to workstation config
- **Nix store persistence** — copies /nix to /home/user/nix after all installs so the store survives container restarts (bind-mounted back by startup script)
- **Antigravity keybinding** — changed from non-existent `/home/user/.antigravity/` path to `/usr/bin/antigravity` (apt-installed in Docker image)
- **Antigravity autostart on workspace 3** — fixed path in `08-workspaces.sh`, increased timeout from 15s to 30s
- **Swaybar after reboot** — deployed current sway config to YOUR_PROJECT_ID (was using old i3status-rust config)
- **Window sizing** — removed outer gaps (12px → 0) for edge-to-edge windows
- **Webhook URL escaping** — array-based substitution building handles `&` characters in Google Chat webhook URLs
- **Cloud Logging visibility** — grants Logs Writer role to build SA so build logs appear

### Verified
- YOUR_PROJECT_ID: 33 PASS / 0 FAIL + 25/25 post-setup tests
- YOUR_PROJECT_ID: 33 PASS / 0 FAIL + 25/25 post-setup tests
- All 3 projects (YOUR_PROJECT_ID/02/03) have working schedulers and identical configurations

---

## v1.4 — Auto-Start & Daily Readiness (2026-03-20)

### Added
- **Persistent disk bootstrap** (`~/boot/setup.sh`) — All workstation setup now lives on the persistent disk as modular scripts (01-nix through 08-workspaces). Future changes require zero Docker rebuilds.
- **Cloud Scheduler** (`ws-daily-start`) — Workstation auto-starts daily at 7AM Pacific via Cloud Scheduler → Workstations API HTTP POST with OAuth
- **Custom fonts** — 223+ fonts installed: Operator Mono (12 variants), CascadiaCode (168), FiraCodeiScript (19), CaskaydiaCove Nerd Font (24)
- **ZSH default shell** — exec zsh in .bashrc, zsh-syntax-highlighting + zsh-autosuggestions via git clone, comprehensive .zshrc with Nix profile, PATH, history, completions
- **Starship prompt** — Starship 1.24.2 cross-shell prompt with ZSH integration
- **foot terminal config** — Operator Mono Book:size=18, Tokyo Night color scheme, 8px padding, 10K scrollback
- **App auto-update on boot** (`~/boot/07-apps.sh`) — Updates Claude Code, Gemini CLI (npm), VSCode, IntelliJ (Nix/Home Manager) on each boot, logs to ~/logs/app-update.log
- **Workspace auto-launch** (`~/boot/08-workspaces.sh`) — Pre-launches 4 Sway workspaces: ws1=foot, ws2=Chrome, ws3=Antigravity, ws4=foot
- **000_bootstrap.sh** — Docker image bridge script that delegates all setup to ~/boot/setup.sh on the persistent disk

### Architecture
- **Persistent bootstrap pattern**: Docker image only needs `000_bootstrap.sh` to call `~/boot/setup.sh`. All 8 sub-scripts live on the 500GB persistent disk. Adding features = adding a script file, no rebuild needed.
- **Script execution order**: 01-nix → 02-nvidia → 03-sway → 04-fonts → 05-shell → 06-prompt → 07-apps → 08-workspaces

### Fixed
- **swaymsg SWAYSOCK discovery** — root→user swaymsg calls now auto-discover the Sway IPC socket path
- **Chrome Wayland fallback** — Added `--ozone-platform=wayland` to prevent X11 crash in workspace auto-launch
- **foot.ini deprecation** — Updated `[colors]` → `[colors-dark]` for newer foot versions

---

## v1.3 — Documentation, Validation, and Sway Boot Fix (2026-03-20)

### Added
- **Comprehensive setup guide** (`docs/SETUP.md`, 1,137 lines) — 14-section step-by-step guide to recreate the entire Cloud Workstation from scratch, usable by humans and AI agents
- **Sway auto-start on boot** (`300_setup-sway-desktop.sh`) — startup script creates sway-desktop + wayvnc systemd services on every boot, disables TigerVNC, adds nvidia ldconfig
- **Docker image rebuilt** — natively includes `300_setup-sway-desktop.sh` (Sway auto-start on boot). No more manual deployment of startup scripts after workstation reboot.

### Fixed
- **GNOME starting instead of Sway on reboot** — Sway/wayvnc services were on ephemeral disk and lost on restart. New startup script recreates them before systemd boots
- **nvidia-smi LD_LIBRARY_PATH** — ldconfig now runs on boot to make nvidia libs available system-wide without manual env vars

### Verified
- **Post-reboot E2E validation** (33 PASS, 1 WARN, 0 FAIL):
  - All 17 Nix apps, 2 AI CLI tools, GPU (Tesla T4), Antigravity, Nix store (8,346 packages), persistent disk (479GB free), all configs intact after stop/start cycle

---

## v1.2 — Modern Desktop (Tokyo Night) (2026-03-20)

### Added
- **Modern Sway config** with Tokyo Night color scheme — 6px inner / 12px outer gaps, smart gaps, 2px pixel borders (focused=#7aa2f7, urgent=#f7768e)
- **Color-coded swaybar status** using i3bar JSON protocol — CPU, memory, disk, GPU temp/utilization, network, clock with green/yellow/red thresholds
- **Waybar config + CSS** (for future use) — pill-shaped modules, semi-transparent background, hover effects, urgent-pulse animation
- All config files stored in repo at `workstation-image/configs/` for reproducibility
- F-0023 backlog item for comprehensive setup documentation

### Changed
- Sway config now uses Tokyo Night palette (bg=#1a1b26, accent=#7aa2f7) with modern gaps and borders
- Swaybar upgraded from plain text to i3bar JSON protocol with per-module color coding
- Added floating window rules for dialogs, pop-ups, file operations

### Preserved
- All 33 keybindings from F-0016 (CTRL+SHIFT modifier, 8 workspaces, all app launchers)

---

## v1.1 — Nix Home Manager + Full App Suite (2026-03-20)

### Added
- Nix Home Manager v26.05-pre — all packages declared in `~/.config/home-manager/home.nix`
- **Dev Tools**: Neovim 0.11.6 (custom init.lua), tmux 3.6a, zsh 5.9, ffmpeg 8.0.1, ripgrep, fd, jq, tree
- **Browsers**: Chromium 146.0.7680.80, Google Chrome 146.0.7680.80
- **IDEs**: VS Code 1.111.0, IntelliJ IDEA OSS
- **Sway Desktop**: Sway 1.11, Waybar 0.15.0, foot 1.26.1, wofi, thunar, clipman, wayvnc, mako
- **AI CLI Tools**: Claude Code 2.1.80, Gemini CLI 0.34.0 (via npm to `~/.npm-global/bin`)
- **Sway Config**: 8 workspaces (CTRL+SHIFT+U/I/O/P/H/J/K/L), CTRL+SHIFT modifier, full keybinding set
- **Neovim Config**: Space leader, habamax theme, floating terminal, auto yank highlight
- Waybar with workspace indicators, CPU, memory, disk, clock
- Startup script `200_persist-nix.sh` for /nix bind mount + nvidia paths

### Changed
- /nix uses bind mount instead of symlink (Nix rejects symlinks)
- Docker image rebuilt with startup script for persistent Nix
- IntelliJ: `idea-community` removed from nixpkgs, using `idea-oss`
- Antigravity wrapper path fixed (double directory: `~/.antigravity/antigravity/bin/`)

### Known Issues
- Cursor IDE not in nixpkgs — needs AppImage approach
- Sway VNC integration needs testing (wayvnc vs TigerVNC)

---

## v1.0 — Cloud Workstation Live (2026-03-20)

### Added
- Cloud Workstation cluster `workstation-cluster` in us-west1
- Artifact Registry `workstation-images` with custom Docker image (~3.3GB)
- Workstation config `ws-config`: n1-standard-16 + NVIDIA Tesla T4 GPU, 500GB pd-ssd, 4h idle / 12h run timeout
- Workstation `dev-workstation` — GNOME desktop via noVNC in browser
- Google Antigravity v1.20.6 installed and accessible from desktop
- Google Chrome with `--no-sandbox --no-zygote --disable-gpu --disable-dev-shm-usage` flags
- TigerVNC (port 5901) + noVNC (port 80) for browser-based desktop access
- NVIDIA Tesla T4 GPU (15GB VRAM, Driver 535.288.01, CUDA 12.2)
- Nix package manager 2.34.2 on persistent HOME disk (492GB available)
- Cloud Router + Cloud NAT for internet access (org policy blocks public IPs)
- Shielded VM enabled (secure boot, vTPM, integrity monitoring — org policy)
- IAM: admin@your-org.example.com has workstations.user access

### Access
- **URL:** `https://dev-workstation.cluster-wg3q6vm6rnflcvjsrq5k7aqoac.cloudworkstations.dev`
- **noVNC:** Auto-redirects to VNC desktop on port 80
- **GPU:** `nvidia-smi` at `/var/lib/nvidia/bin/nvidia-smi` (PATH set via `/etc/profile.d/nvidia.sh`)
- **Nix:** `. /home/user/.nix-profile/etc/profile.d/nix.sh` (auto-sourced on login)

### Known Issues
- Machine type is n1-standard-16 (60GB RAM) instead of g2-standard-16 (64GB) — g2 not supported by Cloud Workstations
- GPU is Tesla T4 instead of L4 — L4 not supported as Cloud Workstations accelerator
- `/etc/profile.d/nvidia.sh` is on ephemeral disk — will need re-creation after container restart (should be added to Dockerfile or startup script)

---

## v0.1 — Initial Release

Build a Cloud Workstation in GCP Project ID YOUR_PROJECT_ID with Google Antigravity installed (antigravity.google) following the blog at this link https://medium.com/google-cloud/running-antigravity-on-a-browser-tab-6298bb7e47c4. The Cloud Workstation machine should have a GPU and 64GB RAM as well as 500GB SSD drive. The 500GB SSD drive is a persistent disk with HOME folder mounted to it. All apps must be installed inside the peristent disk. The main docker image should be minimal so all changes, app installs persist inside the persistent disk. For OS, I prefer NixOS with Nix package manager. Follow the blog for what to install and ask questions as necessary

### Features
- Project scaffolding generated with appteam
- Multi-agent team structure configured
- Development pipeline and workflow established

### Team
- SWE-1: General Engineer 1
- SWE-2: General Engineer 2
- SWE-3: General Engineer 3
- SWE-Test: Automated testing
- SWE-QA: E2E testing & QA
- Platform Engineer: Infrastructure & deployment
- Reviewer: Code review & quality
