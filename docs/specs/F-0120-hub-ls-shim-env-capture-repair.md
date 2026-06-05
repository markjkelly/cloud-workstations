# F-0120: Hub language_server cold-boot — capture Hub child-spawn env + repair it in the shim

**Type:** Bug / Enhancement
**Priority:** P0 (critical)
**Status:** Archived — Superseded by F-0124

> [!NOTE]
> Hub language server shim environment repair code was removed when Hub autostart was removed in F-0124.
**Requested by:** PO
**Date:** 2026-05-29

## Problem

The Antigravity Hub shows a blank workspace 1 on every cold boot because the bundled
`language_server` (LS) child the Hub spawns dies in <60 ms — before binding its HTTPS port,
writing any log, or (since F-0119) even writing the shim's first-line header.

Extensive controlled experiments (F-0117 through F-0119) have **proved**:
- The LS binary itself works correctly (~150 ms under every replicated boot condition including
  the exact stripped systemd env from `/proc/<hub-pid>/environ`, cwd=`/`, setsid,
  redirected stdio, `/dev/null` stdin, and via the F-0119 shim).
- **Refuted causes:** network (up at boot), env vars (tested), rlimits (identical),
  dynamic linking (`--stamp` loads the ELF fine), bash/shim mechanics, cwd.
- The failure **only** manifests when the real Hub (Electron) spawns the LS while the
  Hub runs as a systemd-service grandchild via `runuser` (`ws-autolaunch.service`, `Type=oneshot`).

**Key diagnostic clue from F-0119:** On cold boot, the `--stamp` invocation writes a shim
header to `~/logs/ls-spawn.log`, but `--standalone` does NOT. The Hub's `execve` of the
SAME shim file succeeds for `--stamp` but fails for the long-running `--standalone` spawn.

**Root-cause theory:** The Hub passes the `--standalone` LS a **curated (stripped) environment**
with an empty or broken `PATH`. This breaks the shim's `#!/usr/bin/env bash` shebang — the
kernel executes `/usr/bin/env`, which then cannot find `bash`. `--stamp` inherits the outer
full environment; `--standalone` does not.

This feature:
1. **Confirms** the theory by capturing the Hub's child-spawn environment in a new log
   `~/logs/ls-spawn.env` as the shim's very first action.
2. **Fixes** it by rewriting the shim with an absolute shebang (`#!/bin/bash`) and
   prepending a guaranteed sane `PATH` + `HOME` before exec.

## Requirements

1. The shim shebang MUST change from `#!/usr/bin/env bash` to `#!/bin/bash`
   (absolute path; executes even if the Hub passes an empty/broken PATH to its children).
2. The shim MUST log the Hub-supplied environment to `~/logs/ls-spawn.env` as its very
   first action (timestamp, pid, args, explicit PATH value, full `env` dump).
3. The shim MUST repair the environment before exec-ing the real binary:
   - Prepend standard dirs to PATH: `export PATH="/usr/bin:/bin:/usr/local/bin${PATH:+:$PATH}"`
   - Set `export HOME=/home/user` if HOME is empty.
4. Both stdout and stderr MUST continue to be passed through to the Hub UNMODIFIED
   (the Hub parses LS stderr for the dynamic HTTPS port — this is load-bearing).
5. SIGTERM/SIGINT forwarding to the real child MUST be preserved.
6. The `_f0119_install_ls_shim()` function MUST be extended to perform an
   **idempotent upgrade**: if the installed shim contains `# F-0119 LS capture shim`
   but NOT the `# F-0120` version marker, overwrite it in-place with the new shim
   content without touching `language_server.real`.
7. The first-install path (ELF present, no shim) MUST continue to work unchanged.
8. All writes in the shim MUST be guarded with `|| true` — boot MUST never fail here.

## Acceptance Criteria

- [ ] After next cold boot: `~/logs/ls-spawn.env` exists and contains the Hub's child `PATH`
      for the `--standalone` invocation (confirms/refutes broken-PATH theory).
- [ ] After next cold boot: a `=== LS spawn ===` header appears in `~/logs/ls-spawn.log`
      for the `--standalone` invocation (confirms shim now executes under empty-PATH spawn).
- [ ] Ideally: `Port changed!` appears in `~/logs/hub-launch.log` and ws1 is no longer blank
      (confirms PATH repair fixed the LS startup failure).
- [ ] Static test: shim heredoc in `workstation-image/boot/08-workspaces.sh` begins with `#!/bin/bash`.
- [ ] Static test: shim heredoc contains `# F-0120` version marker.
- [ ] Static test: shim heredoc writes to `ls-spawn.env`.
- [ ] Static test: shim heredoc repairs PATH (`/usr/bin:/bin:/usr/local/bin`).
- [ ] Static test: `_f0119_install_ls_shim()` contains upgrade logic that checks for `# F-0120`
      and rewrites the shim if the marker is absent.
- [ ] Three-places parity: `workstation-image/boot/08-workspaces.sh` matches
      `~/boot/08-workspaces.sh` (diff produces no output).

## Out of Scope

- Changing Hub launch flags or environment.
- Changing ws-autolaunch.service unit file.
- Any change to the `language_server.real` binary.
- Changes to F-0118 sampler or F-0117 retry logic.

## Dependencies

- F-0119 (LS capture shim — installed and warm-path verified)

## Open Questions

- If broken PATH is refuted by the env dump, the dump will reveal the actual environment
  and provide the next hypothesis. The shim captures more than before either way.
- `/bin/bash` vs `/usr/bin/bash`: `/bin/bash` is confirmed present on Ubuntu 24.04
  (standard symlink: `/bin` → `/usr/bin` in recent Ubuntu, so both resolve to the same binary).
