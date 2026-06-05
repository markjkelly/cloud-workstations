# F-0119: Hub language_server spawn capture shim

**Type:** Enhancement (Diagnostic)
**Priority:** P0 (critical — blocks root-cause fix F-0120)
**Status:** Archived — Superseded by F-0124

> [!NOTE]
> Hub language server spawn capture code was removed when Hub autostart was removed in F-0124.
**Requested by:** PO
**Date:** 2026-05-29

## Problem

At cold boot, the Antigravity Hub shows a blank workspace 1. The confirmed failure chain:

1. Hub's Electron main process spawns `~/.local/share/antigravity-hub/resources/bin/language_server … --https_server_port 0 …`
2. On a successful (warm) launch, ~0.3 s later Electron logs `[Auto-Restart] Port changed! Reloading all windows with URL: https://127.0.0.1:<port>/`, a renderer starts, and an `app_id=antigravity` window maps on ws1.
3. On **every cold boot**, `language_server` spawns but `Port changed!` never fires → no renderer → no window. The LS process later exits.
4. **The Hub swallows `language_server`'s stdout and stderr**, so we have never seen WHY it dies on cold boot. F-0118's diagnostic sampler captures external process state but cannot see what LS itself emits.

The only way to capture LS's own output is to interpose a shim between the Hub and the real binary.

**This is diagnostic only.** F-0120 will carry the targeted fix once we have evidence.

## Requirements

1. A wrapper shim script must be installed at the `language_server` binary path, transparently forwarding all args and **both** stdout+stderr to the Hub UNMODIFIED (the Hub parses LS stdout for the dynamic HTTPS port).
2. While forwarding, the shim must also tee stdout to `~/logs/ls-spawn.out` and stderr to `~/logs/ls-spawn.err`, and write human-readable spawn/exit records to `~/logs/ls-spawn.log`.
3. The real binary must be moved to `language_server.real` (same directory) before the shim is installed. If the Hub auto-updates, the install logic must detect a new ELF binary at the shim path and refresh `.real` accordingly.
4. Installation must be idempotent: detected via a marker comment inside the shim (`# F-0119 LS capture shim`), so re-running on every boot is safe.
5. Installation must run **before** the Hub is launched in `08-workspaces.sh`.
6. The shim must forward SIGTERM/SIGINT to the real child so the Hub's lifecycle management continues to work.
7. The shim must be dependency-free (bash + coreutils only).
8. **No change to Hub launch behavior.** The warm path must continue to work after shim installation.
9. Boot must never fail due to shim installation errors (all failure paths guarded with `|| true`).

## Acceptance Criteria

- [ ] `~/.local/share/antigravity-hub/resources/bin/language_server` is the shim script (contains `# F-0119 LS capture shim`), is executable.
- [ ] `~/.local/share/antigravity-hub/resources/bin/language_server.real` is the ELF binary (`file` output confirms), is executable.
- [ ] After a warm Hub relaunch: `~/logs/ls-spawn.out` and/or `~/logs/ls-spawn.err` contain new content (capture works).
- [ ] After the warm relaunch: `~/logs/hub-launch.log` shows `Port changed!` OR an `app_id=antigravity` window appears in `swaymsg -t get_tree` (warm path unbroken).
- [ ] Boot tests in `10-tests.sh` cover shim marker, `.real` ELF, executability, logs dir, and call-site ordering.
- [ ] After the next cold boot (PO reboots), `~/logs/ls-spawn.out` and `~/logs/ls-spawn.err` contain the language_server output from the failing cold-boot spawn.

## Out of Scope

- Fixing the cold-boot failure — that is F-0120.
- Modifying Hub launch flags, timeouts, or retry behavior.
- Any change to `hub_language_server_ready()` or the F-0117/F-0118 instrumentation.

## Dependencies

- F-0118 (Hub LS boot diagnostics — context for why this shim is needed)

## Open Questions

- None. Design is fully specified in the pipeline prompt.

## Forward Reference

After the next cold boot, the PO should read:
- `~/logs/ls-spawn.log` — timestamps for each LS spawn and exit with exit code
- `~/logs/ls-spawn.out` — raw language_server stdout (may contain the dynamic port line)
- `~/logs/ls-spawn.err` — raw language_server stderr (likely contains the error/crash reason)

The F-0120 fix will be designed based on this evidence.
