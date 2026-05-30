# F-0124 — Remove Hub Autostart Machinery

**Status:** Done
**Priority:** P0
**Author:** SWE-1
**Date:** 2026-05-29

---

## Problem

Boot-time autostart of the Antigravity Hub was attempted across F-0110 through F-0121 and never made reliable. The cold-boot blank-ws1 failure was reproducible and never fully solved:

- F-0117 added a readiness-based retry loop, but the readiness check was a false positive (reads the shared network namespace, sees host-wide LISTEN sockets — always returns "ready" in ~3s even when LS died).
- F-0118 added a diagnostic sampler; F-0119/F-0120 added a capture shim.
- F-0121 added a user-session gate before the Hub launch.
- Despite all this, the problem persisted.

The accumulated autostart machinery (retry loop, readiness check, diagnostic sampler, LS capture shim, stale-process reaper) is now dead weight — it adds complexity and runtime cost but never solved the problem. The live language_server binary is currently a bash shim (F-0119/F-0120), not the real ELF.

## Decision

**Option A (chosen):** Stop trying to autostart the Hub at boot. Boot no longer launches the Hub. Workspace 1 starts empty. The user runs `hub-restart` (F-0122) after connecting — which always works reliably.

## What Is Removed

All of the following from `workstation-image/boot/08-workspaces.sh`:

- `HUB_LAUNCH_TIMEOUT`, `HUB_MAX_RETRIES`, `HUB_LS_LOG` constants (F-0117)
- `HUB_LS_DIAG_LOG`, `HUB_LS_DIAG_INTERVAL` constants (F-0118)
- `hub_language_server_ready()` function (F-0117)
- `_kill_stale_hub()` helper (F-0114 / F-0117)
- `_f0118_ls_diag_sampler()` function (F-0118)
- `_f0119_install_ls_shim()` function and constants (F-0119 / F-0120)
- F-0121 Part B only: `wait_for_user_session()` helper and its call site in `08-workspaces.sh`
  (the helper in `07-apps.sh` is F-0121 Part A — kept)
- The Hub launch block (the `runuser … antigravity-hub` invocation, the F-0117 retry loop,
  `HUB_OK` variable, the attempt/poll while loop)
- The pre-launch stale-Hub reaping block (F-0114) — only needed because boot launched the Hub
- `HUB` variable (path to the Hub binary) — only used in the launch block

## What Is Kept

- Sway-ready wait loop
- Xwayland startup (rootless)
- F-0115 gnome-keyring Secret Service block
- Chrome launch on ws5
- foot terminals on ws3 / ws4
- `launch_and_wait()` helper (used by Chrome + terminals)
- `sway_cmd`, `count_windows_on_ws`, `find_swaysock`, `log` helpers
- `DBUS_ADDR` constant (used by gnome-keyring + launch_and_wait)
- `USER`, `NIX`, `SWAYMSG`, `FOOT` variables
- sway config `for_window [app_id="antigravity"] move container to workspace number 1` (F-0116)
  — Hub window from `hub-restart` lands on ws1
- F-0122 `hub-restart` utility (unchanged)
- `07-apps.sh` entirely (including F-0121 Part A)

## Kept Out of Caution

- `DBUS_ADDR` constant: used by both `launch_and_wait` (still present) and gnome-keyring. Kept.

## Live Binary Restore

The F-0119/F-0120 capture shim is currently installed on the live disk. Removing the installer
from the boot script is not enough — the live binary stays a shim. This change includes an
explicit step to restore the real ELF:

1. Detect shim: if `language_server` contains `# F-0119 LS capture shim` AND
   `language_server.real` exists and is an ELF
2. `mv -f language_server.real language_server` (overwrite shim with real ELF)
3. `chmod +x language_server`
4. Verify with `file language_server` → "ELF"
5. Confirm no `.real` remains

This is safe to perform while the Hub is running (the running process holds the old inode;
the next launch uses the restored binary). For fresh setups the installer is gone, so the
binary is never shimmed.

## Final Focus Behavior

With no Hub launched, ws1 starts empty. End-of-script focus lands on **ws3** (terminal) so
the user has a prompt ready to type `hub-restart`. A hint log message is emitted:
`"Hub not auto-launched (F-0124) — run 'hub-restart' to start it."`

## Tests

Removed from `10-tests.sh`:
- All F-0117 tests (HUB_LAUNCH_TIMEOUT, HUB_MAX_RETRIES, hub_language_server_ready, HUB_LS_LOG,
  retry loop, language_server_boot_diag.log)
- All F-0118 tests (HUB_LS_DIAG_LOG, HUB_LS_DIAG_INTERVAL, _f0118_ls_diag_sampler,
  hub-ls-diag.log, sampler PID, kill sampler, diag header, inode socket, DNS probe)
- All F-0119 tests (shim installed, language_server.real exists, shim executable,
  _f0119_install_ls_shim function present)
- All F-0120 tests from the boot-script source (shim heredoc #!/bin/bash, # F-0120 marker,
  ls-spawn.env, PATH repair, SHIM_VERSION, upgrade log)
- F-0121 Part B tests: (f) 08-workspaces.sh defines wait_for_user_session, (g) calls before
  gnome-keyring, (h) fail-open, (i) logs elapsed time
- Workspace layout test that asserts `\$HUB` + `workspace number 1` in launch block

Kept in `10-tests.sh`:
- All F-0115 keyring tests
- F-0116 for_window rule test
- F-0122 hub-restart tests
- All F-0121 Part A tests (07-apps.sh)
- Workspace layout tests: ws2 empty, ws3 foot, ws4 foot, ws5 Chrome
- All Xwayland rootless tests
- All sway config, foot terminal tests

Added to `10-tests.sh`:
- Regression: `language_server` is NOT a shim (is an ELF, does NOT contain shim marker,
  no `language_server.real` exists)
- Regression: `08-workspaces.sh` does NOT launch the Hub (no `antigravity-hub` launch,
  no `_f0119`, no `_f0118`, no `hub_language_server_ready`)

## Acceptance Criteria

1. `08-workspaces.sh` passes `bash -n`
2. `10-tests.sh` passes `bash -n`
3. Keyring block still present in `08-workspaces.sh`
4. Chrome still launched on ws5; foot terminals on ws3/ws4
5. Focus ends on ws3 at end of script
6. `language_server` is a real ELF on the live disk; no `.real` file
7. `~/boot/` matches repo (diff clean)
8. `hub-restart` unaffected (F-0122)
