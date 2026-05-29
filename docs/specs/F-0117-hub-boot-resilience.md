# F-0117: Hub Boot Resilience — Readiness-Based Wait, Retry, and Instrumentation

**Type:** Bug Fix
**Priority:** P0 (critical path)
**Status:** Done
**Requested by:** PO
**Date:** 2026-05-29

## Problem

After all prior fixes (F-0114 stale-lock cleanup, F-0115 keyring, F-0116 IDE removal +
`for_window` rule), workspace 1 is still intermittently blank after a cold boot. Systematic
debugging by the orchestrator confirmed the root cause:

- The Hub's Electron **main process starts fine** (pid alive, DevTools port listening).
- It spawns the bundled `language_server`
  (`~/.local/share/antigravity-hub/resources/bin/language_server`,
  launched with `--https_server_port 0` = random port).
- **At cold boot the language_server intermittently fails to reach "listening."** When it
  does, the Electron event `[Auto-Restart] Port changed! Reloading windows with URL
  https://127.0.0.1:<port>/` NEVER fires, so the BrowserWindow never navigates to a working
  URL. No `--type=renderer` process ever starts; no `app_id=antigravity` window ever maps in
  sway.
- `08-workspaces.sh`'s `launch_and_wait 1 90` waits for a **window** to appear, not for the
  language_server to become ready. If no window maps within 90 s the call times out — but the
  Hub process is still alive (just renderer-less). The script does not retry; it moves on and
  ws1 remains blank.
- The `for_window [app_id="antigravity"] move container to workspace number 1` rule from
  F-0116 only works when the window eventually maps; it cannot help if the window never maps.

Auth is **not** the problem: language_server.log entries show "Auth succeeded" on working
boots. The keyring fix (F-0115) is healthy.

## Requirements

1. **Readiness-based wait** — instead of waiting only for a sway window, the Hub launcher
   must also poll whether the `language_server` HTTPS port is listening (the real readiness
   signal). Consider a window mapped OR a port listening as success.
2. **Retry on failed launch** — if the Hub process is alive but neither the language_server
   port nor the sway window appears within a bounded timeout, the launcher must:
   a. Kill stale Hub processes cleanly (same safe pgrep-based approach as F-0114).
   b. Remove stale singleton locks.
   c. Relaunch the Hub (up to a fixed retry limit, e.g. 3 attempts).
   d. Log each attempt number and the final outcome.
3. **Named constants for timeouts and retry count** — no magic numbers inline.
4. **Instrumentation** — on a retry-triggering failure, capture the relevant boot environment
   (uptime, key env vars, language_server process state) to a dedicated log under `~/logs/`
   so the next failing boot provides enough data for a targeted root-cause fix.
5. **Preserve the existing `for_window` rule** — once the window maps (first attempt or
   retry), the sway rule places it on ws1. Do not remove or weaken this.
6. **Idempotency and explicit error handling** — no silent failures; every attempt is logged
   with a timestamp.
7. **Boot-script-only change** — no image rebuild required; PO can test by REBOOTING.

## Acceptance Criteria

- [ ] AC1: `08-workspaces.sh` polls for language_server port listening as a readiness signal
  during Hub launch (in addition to or instead of the sway window check).
- [ ] AC2: If neither port nor window appears within the per-attempt timeout, the launcher
  kills stale Hub processes, removes Singleton* files, and relaunches (up to
  `HUB_MAX_RETRIES` attempts).
- [ ] AC3: Named constants `HUB_LAUNCH_TIMEOUT` and `HUB_MAX_RETRIES` appear in
  `08-workspaces.sh`.
- [ ] AC4: A new log file captures boot environment and retry timeline on failure — path
  referenced in both `08-workspaces.sh` and `docs/STARTUP_SCRIPTS.md`.
- [ ] AC5: The `for_window [app_id="antigravity"] move container to workspace number 1` rule
  remains unchanged in the sway config.
- [ ] AC6: Tests in `10-tests.sh` assert: (a) the retry-loop and readiness-poll logic exists;
  (b) the language_server port-listening check is present; (c) the new log path is referenced;
  (d) the named constants are present.
- [ ] AC7: All previously passing tests remain green (no regressions).
- [ ] AC8: The change is boot-script-only — the PO can validate by rebooting (no image
  rebuild required).

## Out of Scope

- Installing a different version of the Hub or reinstalling it (v2.0.10 is correct).
- Investigating _why_ the language_server fails at cold boot in detail (that is the purpose
  of the instrumentation; the targeted fix comes in a subsequent feature).
- Changes to the Docker image or Cloud Build pipeline.
- Waybar, sway keybindings, or other desktop configuration.

## Dependencies

- F-0114 (stale-lock cleanup — the same safe kill pattern is reused here)
- F-0115 (keyring/DBUS — already in place; not changed)
- F-0116 (IDE removed, `for_window` rule added — preserved, not changed)
