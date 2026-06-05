# F-0118: Hub language_server Boot Diagnostics — Sampler Instrumentation

**Type:** Enhancement (Diagnostic)
**Priority:** P0 (critical path — prerequisite for any real fix)
**Status:** Archived — Superseded by F-0124

> [!NOTE]
> Hub language server diagnostics code was removed when Hub autostart was removed in F-0124.
**Requested by:** PO
**Date:** 2026-05-29

## Problem

Workspace 1 remains blank after cold boot. Eight prior fixes (F-0110 → F-0117) all failed
to resolve the root cause. The latest investigation (post-F-0117) revealed:

1. **F-0117's readiness check is a guaranteed false positive.** `hub_language_server_ready()`
   reads `/proc/<hubpid>/net/tcp6` for any LISTEN socket (state `0A`). Because the
   network namespace is shared with init (`/proc/<hubpid>/ns/net == /proc/1/ns/net`), that
   file shows the ENTIRE HOST's sockets. Chrome + sway + wayvnc + sshd always provide 8+
   LISTEN sockets, so the check returns "ready" the instant a `language_server` process
   merely exists — even one that is about to die. The diagnostic log records "Attempt 1
   SUCCEEDED" in ~3 s on every boot, so the retry loop never retries. The readiness check
   does not detect the actual failure.

2. **The deeper failure is invisible.** `language_server` fails to bind/report its HTTPS port
   at cold boot, then dies. Its log (`~/.config/Antigravity-Hub/logs/language_server.log`)
   is only written on successful/warm runs. The Hub Electron process swallows LS
   stdout/stderr. The failing LS dies without leaving any trace.

3. **Leading hypothesis: network-dependent init races cold-boot DNS/connectivity.** Every
   warm/manual relaunch succeeds in ~0.3 s; every cold-boot auto-launch fails. LS makes
   network calls to `https://daily-cloudcode-pa.googleapis.com` and
   `https://cloudcode-pa.googleapis.com` early in its startup. At cold boot, DNS resolution
   and TCP connectivity to those endpoints may not yet be available.

4. **Immediate need:** thorough per-sample diagnostic capture during the Hub launch window
   on the NEXT cold boot, so we can actually root-cause the failure and design a targeted
   fix.

## Requirements

1. A background sampler MUST run during the Hub launch window (for the full
   `HUB_LAUNCH_TIMEOUT` duration), sampling every ~3 seconds, appending to
   `~/logs/hub-ls-diag.log`.
2. The sampler MUST NOT change when or how the Hub is launched.
3. The sampler MUST be robust: it never blocks the boot sequence, never fails the boot
   script, and guards every operation with `|| true`.
4. The sampler MUST capture, per sample:
   a. All `language_server` processes whose cmdline contains `antigravity-hub/resources`:
      pid, state from `/proc/<pid>/stat` field 3. MUST note when a previously-seen LS
      pid disappears and at what elapsed time.
   b. The REAL listening sockets OWNED BY the LS pid — correctly, not via F-0117's
      shared-namespace approach: collect socket inodes from `/proc/<pid>/fd/*` (readlink,
      match `socket:[INODE]`), then match those inodes against `/proc/net/tcp` and
      `/proc/net/tcp6` filtering to LISTEN state (`0A`). Report actual port(s) the LS
      itself owns (decode hex local_address port). If none, say so explicitly.
   c. The port the Hub THINKS it should use: grep for the latest
      `Port changed! Reloading all windows with URL: https://127.0.0.1:<PORT>/` in
      `~/logs/hub-launch.log`.
   d. For each real LS-owned port AND the Hub-reported port: an actual probe — `curl -sk
      -o /dev/null -w "%{http_code} %{time_total}s" --max-time 3 https://127.0.0.1:<port>/`
      (fall back to a bash `/dev/tcp` test if curl is absent; log which method was used).
   e. Count of Hub renderer processes (`pgrep -af -- '--type=renderer'` filtered to
      `antigravity`).
   f. Network/DNS readiness: `getent hosts daily-cloudcode-pa.googleapis.com` (resolves?)
      and a `--max-time 3` curl connect attempt to that host.
   g. A one-time-per-boot snapshot of LS log locations:
      `ls -la --time-style=full-iso ~/.config/Antigravity-Hub/logs/`
      `ls -la --time-style=full-iso ~/.config/Antigravity/logs/`
      `find ~/.config -name 'language_server*.log' -newer ~/logs/hub-ls-diag.log`
5. The sampler MUST also attempt to capture LS's own stdout/stderr WITHOUT changing
   launch behavior. Specifically: log the targets of `/proc/<lspid>/fd/1` and
   `/proc/<lspid>/fd/2` (where is its output going?) and log whether `--log_dir` or
   `GLOG_log_dir` or `--logtostderr` flags/env are visible in the LS cmdline or env.
6. Named constants must be used for all magic numbers (matching existing F-0117 comment
   style).
7. The diagnostic log MUST start each boot with a
   `=== F-0118 LS diag: <date> ===` header.
8. The existing (broken) `hub_language_server_ready()` function MUST NOT be changed in
   this feature — F-0118 is diagnostic only.
9. A copy of the updated `08-workspaces.sh` MUST be deployed to `~/boot/08-workspaces.sh`
   so the next reboot picks it up without an image rebuild.
10. `docs/STARTUP_SCRIPTS.md` MUST be updated to document `~/logs/hub-ls-diag.log`.
11. `workstation-image/boot/10-tests.sh` MUST include tests verifying the F-0118
    instrumentation is present in `08-workspaces.sh`.

## Acceptance Criteria

- [ ] `docs/specs/F-0118-hub-ls-boot-diagnostics.md` created
- [ ] `docs/BACKLOG.md` has F-0118 entry under a new Milestone 33
- [ ] `workstation-image/boot/08-workspaces.sh` contains the `_f0118_ls_diag_sampler()`
      function and the `HUB_LS_DIAG_LOG` constant
- [ ] The sampler is started in background immediately after Hub launch and killed at the
      end of the launch-window poll loop
- [ ] Per-sample output includes: LS pid/state, LS-owned LISTEN sockets (correct inode
      method), Hub-reported port, connectivity probes (a-d above), renderer count, DNS/
      network check (f), one-time log-file snapshot (g), LS fd/1 + fd/2 targets (req 5)
- [ ] `~/boot/08-workspaces.sh` matches repo source (persistence rule satisfied)
- [ ] `docs/STARTUP_SCRIPTS.md` documents `hub-ls-diag.log`
- [ ] `workstation-image/boot/10-tests.sh` has F-0118 tests for sampler presence and log path
- [ ] Feature branch committed and PR opened against `main`

## Out of Scope

- Changing launch timing or Hub startup behavior — strictly diagnostic only
- Fixing the LS bind failure — requires the diagnostic data from this feature first
- Capturing LS stderr via a binary wrapper — if the only way to capture LS stderr is to
  wrap/replace the `language_server` binary, that is deferred as a follow-up feature.
  This feature instead logs `/proc/<lspid>/fd/1` and `/proc/<lspid>/fd/2` targets so we
  know where the output is going. The wrapper approach should be considered in F-0119 if
  the fd targets do not reveal the log location.
- Removing or fixing `hub_language_server_ready()` — deferred to the fix feature once
  root cause is confirmed

## Dependencies

- F-0117 (implemented — provides the retry loop and `HUB_LS_LOG` constant this feature
  extends)

## Open Questions

- Is there a `--log_dir` or `GLOG_log_dir` env var that the Hub passes to LS, which we
  can read from `/proc/<lspid>/environ`? The sampler will capture this and answer it on
  the first cold boot.
- Does LS die (disappear from `/proc`) within the 90 s timeout, or does it stay alive
  but in a zombie/stopped state? The sampler's per-sample state reporting will answer this.
- Is the DNS failure hypothesis correct? The sampler's `getent` + curl probe will confirm
  or refute within the first sample.

## Follow-up Candidates (post-F-0118)

- **F-0119**: LS stderr capture via wrapper — if `/proc/<lspid>/fd/2` points to
  `/dev/null` or a pipe with no reader, wrap the `language_server` binary to redirect its
  stderr to a log file and capture the actual error.
- **Fix feature** (number TBD): once root cause is confirmed from the F-0118 diag log,
  implement the targeted fix (e.g., delay Hub launch until DNS resolves, or pre-warm the
  network connection, or inject retry logic inside LS startup).
