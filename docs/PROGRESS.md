# Development Progress Log — Cloud Workstation

## Session 24 — 2026-04-15

### Goals
- Close out Milestone 22 / F-0097: make Xwayland's `-rootless` flag survive a full reboot so the ws1 split fix from F-0096 stays fixed on live sessions, not just on in-session re-execs of `08-workspaces.sh`.

### Completed
- **PM** authored `docs/specs/F-0097-xwayland-rootless-persistence.md` identifying F-0097 as a persistence regression on top of the F-0096 code fix.
- **TPM** added F-0097 to `docs/BACKLOG.md` under Milestone 22 (commit `117f210`).
- **SWE** implemented the fix on branch `fix/xwayland-rootless-persistence` (commit `77a6b93`): added `xwayland disable` plus `exec /usr/bin/Xwayland -rootless :0 &` to the sway config autostart block so Xwayland is started with `-rootless` directly by sway on session startup. The existing `08-workspaces.sh` boot-script guard is kept as belt-and-braces but is no longer the primary mechanism — the earlier guard was racing sway IPC availability on cold boot, which is why the flag was being dropped after reboot even though the F-0096 fix was in place.
- **SWE-Test** strengthened `workstation-image/boot/10-tests.sh` with a runtime assertion: `pgrep -af Xwayland | grep -- -rootless`, which fails the boot-test summary if the live Xwayland process is ever running without `-rootless`. This turns a silent regression into a loud one, matching the F-0095 drift-guard philosophy.
- **SWE-QA** verified live on the workstation post-reboot: Xwayland PID 2816 is running with `-rootless` in its argv; ws1 renders a single fullscreen foot terminal with no phantom Xwayland root client in `swaymsg -t get_tree`.
- **PR #11** merged to `main` as `399408b`.
- **SWE-1** marked F-0097 done in `docs/BACKLOG.md` (commit `e505fd0`), keeping the combined Milestone 21/22 row per the existing F-0096/F-0097 convention.

### Key Decisions
- **Start Xwayland from sway autostart, not from a boot-script `sway_cmd exec`**: the boot-script approach depended on sway IPC being ready when the script ran, which was racy on cold boot. Having sway itself start Xwayland via `exec` in its own config removes the race entirely — sway is necessarily running by the time it processes its own `exec` lines.
- **Keep the `08-workspaces.sh` guard as belt-and-braces**: even though the sway-autostart path is now primary, the script guard stays in place so any future drift (e.g. someone removes the sway-config `exec` line) is caught by the same mechanism that originally shipped with F-0096. Cost is zero, defensive value is non-zero.
- **Runtime assertion in `10-tests.sh`, not static grep**: the earlier F-0096 test only checked that the repo config *contained* `-rootless`. That passed even when the live Xwayland was running without the flag (which is exactly what F-0097 was). Asserting on the live `pgrep` output is the only check that would have caught F-0097 at boot time.

### Files Changed
- `docs/specs/F-0097-xwayland-rootless-persistence.md` (new)
- `docs/BACKLOG.md` (Milestone 22 entry, then marked done)
- `workstation-image/configs/sway/config` and `~/.config/home-manager/sway-config` (autostart `xwayland disable` + `exec /usr/bin/Xwayland -rootless :0 &`)
- `workstation-image/boot/10-tests.sh` (runtime `pgrep` assertion)

### Pipeline
- Full PO → PM → TPM → SWE → SWE-Test/QA → TPM → PM pipeline via interactive tmux team `fix-xwayland-rootless-persistence`. Merged as PR #11 (`399408b`).

### Next Steps
- Monitor the next few reboot cycles for any regression of the `-rootless` flag — the `10-tests.sh` runtime assertion should catch it in the boot-test summary if it recurs.
- Milestone 22 closeout: PM to produce release-notes entry and report back to PO; tag on PO approval.

### Open Items / Risks
- None specific to F-0097. Standing F-0094 AC4(b)/AC4(c) items remain open from earlier milestones.

---

## Session 23 — 2026-04-15

### Goals
- Fix Xwayland splitting workspace 1 on boot (F-0096) — ws1 should open to a single fullscreen foot terminal like ws2/ws3/ws4, not tile foot next to a phantom Xwayland root window.

### Completed
- **PM** authored `docs/specs/F-0096-xwayland-ws1-split.md` with reproduction, root-cause analysis, two fix options, and acceptance criteria (commit `b8d7915`).
- **TPM** added F-0096 to `docs/BACKLOG.md` under Milestone 21 (commit `98ac784`).
- **SWE** implemented Option 2 — added `-rootless` to the Xwayland invocation in `workstation-image/boot/08-workspaces.sh`, updated log lines, and left a comment pointing at F-0096 (commit `2cf39b1`).
- **SWE-Test + SWE-QA** verified end-to-end on the live workstation: after `swaymsg reload` + re-exec of `08-workspaces.sh`, ws1 shows a single fullscreen foot terminal; no `org.freedesktop.Xwayland` client is visible in `swaymsg -t get_tree`. Boot test suite: **53 PASS / 30 FAIL**, with all 30 FAILs pre-existing hygiene issues unrelated to this fix (mostly AI CLI version probes).
- **SWE** marked F-0096 Done, tested + verified in `docs/BACKLOG.md` (commit `ae692e6`).

### Key Decisions
- **Chose `-rootless` over a sway `for_window` scratchpad rule**: root-cause fix vs. symptom-masking. With `-rootless`, Xwayland never spawns the phantom root window in the first place, matching the standard mode for Xwayland under a Wayland compositor. A `for_window` rule would leave a useless process rendering into the void and could silently mask a future regression.
- **Deferred AC4 (reboot persistence) to the deployment step**: the fix lives in the repo at `workstation-image/boot/08-workspaces.sh`, which the setup pipeline deploys to both `~/boot/` and the image. Verification at reboot requires `ws.sh setup` after merge + push; the live verification confirmed the code path works when re-executed.
- **Did not add defense-in-depth `for_window` rule**: per the spec's open question, a future regression should surface loudly rather than be silently hidden by a second layer.

### Files Changed
- `docs/specs/F-0096-xwayland-ws1-split.md` (new)
- `docs/BACKLOG.md` (Milestone 21 entry, then marked Done)
- `workstation-image/boot/08-workspaces.sh` (`-rootless` flag + comment)

### Pipeline
- Full PO → PM → TPM → SWE → SWE-Test/QA → TPM/PM pipeline used via interactive tmux team `fix-xwayland-ws1`.

### Next Steps
- PM to produce release-notes entry (v1.17.1 bugfix) on `fix/xwayland-ws1-split`.
- Open PR `fix/xwayland-ws1-split` → `main`.
- After PO approval: tag `v1.17.1` and push; run `ws.sh setup` to confirm AC4 (reboot persistence) end-to-end.
- Separate follow-up: triage the 30 pre-existing FAILs in `10-tests.sh` (out of scope for F-0096).

---

## Session 22 — 2026-04-15

### Goals
- Diagnose and fix F-0095: foot terminal CWD regression (third occurrence) — newly spawned foot terminals no longer start in `/home/user`, forcing manual `cd ~` on every new terminal
- Close the drift loop so a fourth regression of this class fails the boot-test summary instead of shipping silently

### Completed
- **PM** wrote `docs/specs/F-0095-foot-cwd-regression.md` (commit `429def7`) with four root-cause hypotheses (H1–H4), requirements R1–R5 (including mandatory boot-level drift guard in R4), and acceptance criteria AC1–AC6. Spec prohibits silencing via shell aliases or profile hacks.
- **TPM** added Milestone 20 / F-0095 entry to `docs/BACKLOG.md` on branch `fix/foot-font-regression` (commit `a41e570`) — P0, owner SWE-1, deps F-0087 + F-0094.
- **SWE** diagnosed and fixed on branch `fix/foot-cwd-regression-f0095`:
  - Commit `dbcdfc1` — Root cause: **H1 + stale 10-tests.sh assertion**. The existing F-0087 test grepped for the old `exec cd ~ && .*foot` pattern, so when someone standardized back to `0dd33b3`'s `--working-directory=/home/user` style the drift check silently passed instead of catching the resurfaced regression. The repo sway config and `08-workspaces.sh` already carried the correct `--working-directory=/home/user` guard from commits `0dd33b3` / `20d3352`; only `workstation-image/boot/10-tests.sh` needed a change. Three R4 drift guards added: R4a (sway `$mod+Return` / `$mod+t` bindings), R4b (every foot invocation in `08-workspaces.sh`), R4c (repo sway config and `~/.config/home-manager/sway-config` byte-identical on foot-launch lines).
  - Commit `f47e4ed` — Follow-up from SWE-Test verification: the R4b matcher `(\$FOOT|/foot)[[:space:]]` required trailing whitespace and therefore missed the real live-drift pattern `launch_and_wait 1 5 "$FOOT"` (bare `"$FOOT"` at end-of-line, no args). Broadened to `("\$FOOT"|\$FOOT|/foot)([[:space:]"]|$)` with the `FOOT=` assignment line filtered out — now catches the ws1/ws4 autostart drift the guard was specifically designed to catch.
- **SWE-Test** live-verified on the drifted workstation (pre-resetup) — R4a FAILs × 2 (sway keybindings drifted back), R4b FAILs (08-workspaces.sh drift, post-f47e4ed fix), R4c SKIPs cleanly (no Home Manager sway-config on this workstation). All three will flip to PASS post-`ws.sh setup` once the repo-correct configs are re-synced. `bash -n` clean on the test script.

### Key Decisions
- **Standardize on `--working-directory=/home/user`**: per spec recommendation, chosen over `cd ~ && …` because it is explicit, does not depend on shell expansion, and is the identical flag on both sway keybindings and `08-workspaces.sh` `launch_and_wait` invocations. F-0087's shell-guard style is superseded.
- **Fix lives in the boot test, not the configs**: the repo sway config and `08-workspaces.sh` already had the correct flag; the real failure was that the test couldn't detect when the live deploy drifted away from the repo. Fixing just the test makes future drift noisy instead of silent.
- **No shell-alias silencing**: deliberately rejected adding a `cd ~` shim in `~/.zshrc` / `~/.profile` or wrapping foot with a CWD-forcing script, per R3. Those would have hidden the drift that F-0095 is specifically about exposing.
- **`docs/STARTUP_SCRIPTS.md` not updated**: no boot-script purpose or ordering changed — the edit is a regex tightening inside `10-tests.sh` whose documented role already covers it.

### Verification Status
- **Statically verified (this session)**: diff scope correct (+6/−1 to `10-tests.sh` net across both commits), `bash -n` clean, repo-copy grep shows both `08-workspaces.sh` call sites (lines 117, 130) carry `--working-directory=/home/user`, repo sway config carries the flag on both `$mod+Return` / `$mod+t` bindings.
- **Live-verified on the drifted workstation (pre-resetup)**: R4a/R4b fail as designed when the live deploy has drifted — this is the AC3 headline validation (drift guard catches regression).
- **Not yet verified (needs live display + boot sequence)**: AC1 (`$mod+Return` → `pwd == /home/user`), AC2 (autostart ws1/ws4 foot pwd), AC4(b) `ws.sh teardown && ws.sh setup`, AC4(c) fresh-project setup, AC3 tail (all three guards flip to PASS post-setup). AC5 three-places diff deferred until after setup runs. Corruption check (AC3 negative) skipped to respect no-edits constraint on live configs.

### Next Steps
- PO decides verification path for AC1/AC2/AC4(b)/AC4(c) (verify-before-PR vs verify-post-merge vs SWE-QA light verification) — same choice as F-0094.
- PM to pick up task #5: RELEASENOTES.md entry + PO report.

### Open Items / Risks
- **BLOCKING for release merge**: `main` currently has a residual unresolved `UU docs/BACKLOG.md` three-stage conflict (`:2` pre-F-0094 state, `:3` combined F-0095+F-0096 state) with no `.git/MERGE_HEAD` — not a live merge, but an orphan state. F-0096 (Xwayland ws1 split, Milestone 21) is a separate workstream whose ownership is unclear. Escalated to team-lead and then to PO. PM must NOT merge F-0095 to `main` until this is resolved, or the release-notes edit will collide.
- Standing F-0094 items still open: AC4(b) teardown+setup and AC4(c) fresh-project setup verification.

---

## Session 21 — 2026-04-15

### Goals
- Diagnose and fix F-0094: foot terminal falling back to Noto Sans after reboot with "font does not appear to be monospace" warning

### Completed
- **PM** wrote `docs/specs/F-0094-foot-font-regression.md` with P0 bug spec, hypotheses, requirements (R1–R5), and acceptance criteria (AC1–AC6). Prohibited silencing via `[tweak].font-monospace-warn=no`.
- **TPM** added Milestone 19 / F-0094 entry to `docs/BACKLOG.md` (P0, owner SWE-1, branch `fix/foot-font-regression`, deps F-0030/F-0092). Initial backlog commit `bf5ce46`.
- **SWE-1** diagnosed root cause and implemented fix on branch `fix/foot-font-regression`, commit `62d90fc` (pushed):
  - Root cause: `~/boot/06-prompt.sh` was a stale copy writing `font=JetBrains Mono` inline. JetBrains Mono was not installed on this workstation, so foot fell back to Noto Sans (non-monospace) and emitted the warning every launch.
  - Created `workstation-image/configs/foot/foot.ini` as the single source of truth for foot config.
  - Updated `workstation-image/boot/06-prompt.sh` to deploy `~/boot/foot.ini` to `~/.config/foot/foot.ini` instead of writing an inline heredoc.
  - Updated `scripts/cloud-build-setup.sh` step 13 to deploy the same `foot.ini` to `~/boot/foot.ini` for fresh project setups (three-places rule satisfied).
  - Verified `fc-cache -fv` ordering: `04-fonts.sh` rebuilds the cache before `06-prompt.sh` runs, so the foot config lands after fonts are indexed.
  - Added boot test to `workstation-image/boot/10-tests.sh` that greps the primary family from `~/.config/foot/foot.ini`, runs `fc-match "<family>"` and `fc-match "<family>:spacing=mono"`, and asserts the returned font is the configured monospace family (not Noto/DejaVu sans).
  - Live boot-test-summary on the workstation: 51→53 PASS, 31→30 FAIL.
- **TPM** updated `docs/BACKLOG.md` to mark F-0094 done with commit SHA and verification status, and updated this `docs/PROGRESS.md`.

### Key Decisions
- **Repo foot.ini is the source of truth, not an inline heredoc**: the previous approach had `06-prompt.sh` generate `foot.ini` inline, which is exactly what caused the drift (repo changes to the font family didn't propagate to the live deploy). Going forward boot scripts deploy a checked-in config file.
- **`docs/STARTUP_SCRIPTS.md` not updated**: no boot script's purpose or ordering changed — only the internal mechanism of how `06-prompt.sh` produces `foot.ini`. Documentation entry for 06-prompt.sh remains accurate.
- **Reboot persistence verified in place (AC4a)**; full teardown+setup (AC4b) and fresh-project setup (AC4c) verification deferred pending PO direction (verify-before-PR vs verify-post-merge vs SWE-QA light verification).

### Next Steps
- PO decides verification path for AC4(b) and AC4(c).
- Once PO direction is confirmed, TPM pings PM to write RELEASENOTES.md entry and close out the milestone.

### Open Items
- End-to-end verification of `ws.sh teardown && ws.sh setup` (AC4b) and fresh-project setup on a new GCP project disk (AC4c).

---

## Session 20 — 2026-04-15

### Goals
- Audit fork divergence against `upstream/main` and bring docs in line with the fork state
- Cut v1.17 release notes covering GCP Organization alignment, font cleanup, and a retrospective for pre-v1.14 fork-only work
- Add specs and backlog entries for all fork-only features that had never been formally tracked

### Completed
- **PM** produced `docs/RELEASENOTES.md` v1.17 entry (including a "Fork Divergence Summary" retrospective) and four new specs:
  - `docs/specs/F-0088-cloud-build-pipeline.md`
  - `docs/specs/F-0089-custom-tools-module.md`
  - `docs/specs/F-0090-vnc-keyboard-compat.md`
  - `docs/specs/F-0091-gcp-org-alignment.md`
- **TPM** updated `docs/BACKLOG.md` — added Milestone 17 with F-0088/F-0089/F-0090/F-0091 marked Done and linked to their specs, plus F-0092 for the foot-font cleanup
- **TPM** updated `README.md` "After Setup" commands to reflect the deployed configuration (`us-central1`, `main-cluster`, `sway-config`, `sway-workstation`)
- **TPM** added `11-custom-tools.sh` to `docs/STARTUP_SCRIPTS.md` boot sequence table and execution flow
- Verified `docs/SETUP.md` top-of-file machine-spec note and `docs/PIPELINE.md` MermaidJS diagram are still accurate — no changes needed
- Verified README machine-spec table (`n2-standard-8`, 200GB `pd-balanced`, no GPU) matches commit `fe29dfe`

### Audit Scope — `git log upstream/main..HEAD`
Fork-only commits mapped to specs/backlog items:
- `82373e1`, `aa1fc95` → F-0088 (Cloud Build pipeline)
- `11fe006`, `85f6c56`, `bea5b61`, `33a038b`, `0ebd8f3`, `f0c4e54` → F-0089 (custom tools + noVNC patch)
- `493d541`, `eb2d56c` → F-0090 (VNC keyboard compat)
- `df99d3d`, `fe29dfe` → F-0091 (GCP Organization alignment + machine spec docs)
- `6fef7ff`, `f871cd1`, `5c714dd`, `0aca479`, `1639c59` → F-0092 (foot font cleanup)
- `a1672ff` → REPO_URL placeholder (captured in RELEASENOTES retrospective)
- `9d419f2`, `660e0ca` → GEMINI.md (captured in RELEASENOTES retrospective)
- `e7236a8` → F-0087 (already tracked in Session 19)

### Key Decisions
- **Retrospective in RELEASENOTES over back-dated versions**: rather than invent v1.14.1/v1.14.2/... for every pre-v1.14 fork commit, the release notes carry a single "Fork Divergence Summary" section so history is complete without fiction
- **F-0092 added by TPM, no separate spec**: the font cleanup is a small subset of v1.17 that is adequately described by the release-notes "Changed/Fixed" bullets; a standalone spec would be make-work
- **PIPELINE.md not touched**: agent workflow is unchanged, so the MermaidJS diagram remains accurate

### Pipeline
- Full PM → TPM pipeline used (PM drafted specs + RELEASENOTES; TPM updated BACKLOG/PROGRESS/README/STARTUP_SCRIPTS)
- No SWE work this session — docs-only catch-up

### Next Steps
- PO review of v1.17 release notes and four new specs
- After PO approval: `git tag -a v1.17 -m "..."` and push tags
- Future: decide whether F-0089 custom-tools module should be folded into a dedicated `--profile extras` or remain opt-in via module flag

---

## Session 19 — 2026-04-15

### Goals
- Fix foot terminals opening in arbitrary cwd (F-0087)

### Completed
- **F-0087** (Foot terminals start in $HOME): Updated sway bindings in `workstation-image/configs/sway/config` — `$mod+Return` and `$mod+t` now `exec cd ~ && $nix/foot` so new terminals land in `$HOME` regardless of sway's launch cwd. Added `check_grep` in `workstation-image/boot/10-tests.sh` to verify the binding survives future edits.

### Key Decisions
- Bypassed the full PM→TPM→SWE pipeline for this 2-line config fix at PO's direction; still maintained persistence rule (repo config is single source of truth; setup script already deploys it to both home-manager source and live config) and mandatory test coverage.

### Next Steps
- Tag v1.16 and push.

---

## Session 18 — 2026-04-02

### Goals
- Implement composable install profiles (F-0081, F-0082) — allow users to choose minimal/dev/ai/full/custom profile to control what gets installed
- Reduce minimal build time from 55 min to ~14 min

### Completed

- **F-0081** (Composable install profiles): Implemented in 5 phases + 1 bug fix across 6 commits on `feature/composable-install`:
  - **Phase 1** (commit 95cdd38): Added `--profile` and `--modules` CLI flags to `ws.sh`. Created `~/.ws-modules` config file format. Created `ws-modules.sh` helper script with `ws_module_enabled()` function for boot scripts to check module state
  - **Phase 2** (commit c10782d): Updated `setup.sh` to gate boot scripts by module — scripts check `ws_module_enabled <module>` and skip if disabled. Modules: core (always), desktop, ides, ai-tools, languages, tailscale, tmux
  - **Phase 3** (commit d96385e): Updated `cloud-build-setup.sh` to generate dynamic `home.nix` per profile — AI IDEs (Cursor, Windsurf, Zed, VSCode, IntelliJ) only included for ai/full profiles, saving significant Nix build time
  - **Phase 4** (implicit in Phase 3): `cloud-build-setup.sh` gates language install steps (07a-lang-deps, 07b-languages) and AI tool install steps by profile
  - **Phase 5** (commit cf68015): Updated `10-tests.sh` to conditionally test enabled modules — disabled modules show SKIP instead of FAIL
  - **Bug fix** (commit 155e265): `ws-modules.sh` used `$HOME` which is empty when sourced by root during setup. Changed to hardcoded `/home/user` path

- **F-0082** (Dynamic home.nix generation per profile): Implemented as part of Phase 3 — `cloud-build-setup.sh` generates `home.nix` with conditional package lists based on the selected profile. IDE packages only added for ai/full profiles.

### Test Results
- **minimal** (gement03): 14 min build, 46 PASS, 0 FAIL, 8 SKIP
- **full** (gement02): 55 min build, 77 PASS, 1 FAIL (false positive), 0 SKIP
- 75% build time reduction for minimal profile

### Key Decisions
- **Module config at `~/.ws-modules`**: Simple key=value format, sourced by bash scripts. Profile sets module defaults, `--modules` overrides individual modules
- **`ws-modules.sh` helper**: Centralized `ws_module_enabled()` function avoids duplicating config-reading logic across boot scripts
- **Hardcoded `/home/user`**: `$HOME` is empty when scripts run as root during Cloud Build setup. Hardcoded path is safe since workstation always uses this path
- **SKIP vs FAIL**: Disabled modules show SKIP in boot tests instead of FAIL, keeping test results clean and actionable

### Pipeline
- SWE-1 implemented all 6 commits on `feature/composable-install`
- Tested on gement02 (full) and gement03 (minimal)
- All documentation updated

### Next Steps
- Merge `feature/composable-install` to `main`
- Tag v1.15 release after PO approval
- Consider adding `ws.sh update` command for config-only changes (F-0085)

---

## Session 17 — 2026-04-01/02

### Goals
- Fix ALL setup/teardown issues so the pipeline is bulletproof for any user
- Achieve 0 FAIL on boot tests across fresh teardown+setup
- Add Tailscale, tmux, persistent aliases

### Completed

- **F-0070** (Bulletproof SSH): Added timeouts (5min default, 15min long) to all ws_ssh commands. Split Nix install into download+install. Removed 5 silent `|| true` that hid failures.
- **F-0071** (AR race fix): Added 30s propagation wait + verification loop after Artifact Registry creation. Docker push no longer fails with "Repository not found".
- **F-0072** (Verified teardown): All 9 resource types now have `wait_deleted` verification — workstation, config, cluster, AR, NAT, router, scheduler, cloud function, cloud builds.
- **F-0073** (Boot tests): Created 10-tests.sh with 80+ tests across 12 categories. Runs via systemd service after all services are up. Results at ~/logs/boot-test-{results,summary}.txt.
- **F-0074** (Unified .zshrc): Moved all shell config into Home Manager programs.zsh.initContent. 05-shell.sh skips .zshrc creation when Home Manager manages it. Tests check home.nix instead of .zshrc.
- **F-0075** (AI tools in setup): Fixed OpenCode (go install), Aider (pip), GH Copilot (gh extension), .env creation in cloud-build-setup.sh.
- **F-0076** (Tailscale): Opt-in via TAILSCALE_AUTHKEY in ~/.env. Auto-installs if binary missing (ephemeral root disk). Configures SSH + iptables. Dockerfile also includes tailscale.
- **F-0077** (tmux): Tokyo Night tmux.conf. claude-tmux/tmux-debug scripts launch Claude with --dangerously-skip-permissions in crash-resistant tmux sessions. t1-t10 aliases use claude-tmux.
- **F-0078** (.gitignore): Protects .env, SA keys from accidental commit.
- **F-0079** (PII scrub): Replaced all personal info in docs with placeholders.
- **F-0080** (STARTUP_SCRIPTS.md): Full documentation of boot sequence.

### Key Decisions
- **Single source of truth for .zshrc**: Home Manager's programs.zsh, not 05-shell.sh. Boot script defers if Home Manager manages .zshrc.
- **Tailscale auto-install**: Boot script reinstalls tailscale if binary missing (handles ephemeral root disk without Docker rebuild).
- **claude-tmux wrapper**: Crash-resistant tmux sessions with --dangerously-skip-permissions. Prevents tmux detach-on-destroy issues with agent teams.
- **Verified teardown**: Every delete operation is polled until the resource is confirmed gone. Prevents setup/teardown race conditions.
- **AR propagation wait**: 30s sleep + active verification before Docker build prevents "Repository not found" push failures.
- **Boot tests via systemd**: 10-tests.sh runs as ws-boot-tests.service after ws-autolaunch, ensuring all services are up when tests execute.

### Final Test Results
- Full cycle timed: teardown 14 min, build 56 min, boot tests 5 min, total ~76 min
- Setup script: 52 PASS, 0 FAIL
- Boot tests: 77 PASS, 0 FAIL (1 false positive — WARN only)
- All documentation updated to reflect Milestones 9-14 features

### Next Steps
- Test on additional projects for multi-project validation
- Implement build speed optimizations (docs/research/build-speed-optimization.md)
- Composable install profiles (F-0081)

---

## Session 16 — 2026-03-31

### Goals
- Execute Milestone 12: AI IDEs, CLI Tools, and Timezone Fix (F-0066 through F-0069)
- Add Cursor, Windsurf, Zed, and Aider as AI-powered IDEs
- Add Cody CLI, pi-coding-agent, and GitHub Copilot CLI
- Add sway keybindings for Cursor (CTRL+SHIFT+C) and Windsurf (CTRL+SHIFT+W)
- Fix timezone to Pacific Time across all runtime contexts

### Completed

- **F-0066** (Add AI IDEs via Nix Home Manager): Added `code-cursor`, `windsurf`, and `zed-editor` to Nix Home Manager `home.nix`. `aider-chat` installed via pip instead of Nix (Nix build fails due to sandbox network restrictions). Verified: Cursor 2.6.22, Windsurf 1.108.2, Zed 0.229.0, Aider 0.86.2. (SWE-1, commit 8cade9e)

- **F-0067** (Add CLI tools via npm + GitHub Copilot CLI): Added `@sourcegraph/cody` and `@mariozechner/pi-coding-agent` to the npm global update line in `07-apps.sh`. Added `gh extension install github/gh-copilot` (first boot) and `gh extension upgrade gh-copilot` (subsequent boots) to `07-apps.sh`. Verified: Cody 5.5.26, pi 0.64.0, gh copilot working. (SWE-1, commit 8cade9e)

- **F-0068** (Sway keybindings for Cursor and Windsurf): Added `CTRL+SHIFT+C` for Cursor and `CTRL+SHIFT+W` for Windsurf to sway config. Both use Electron flags (`--no-sandbox --ozone-platform=wayland --disable-gpu --disable-dev-shm-usage`) and `env -u LD_LIBRARY_PATH` to prevent nvidia GL conflicts — same pattern as VSCode. (SWE-1, commit 8cade9e)

- **F-0069** (Fix timezone to Pacific Time): Set `TZ=America/Los_Angeles` in three locations for consistent Pacific Time:
  - `03-sway.sh` — `Environment=TZ=America/Los_Angeles` in sway-desktop.service
  - `05-shell.sh` — `export TZ="America/Los_Angeles"` in .zshrc template
  - `sway-status` script — `export TZ="America/Los_Angeles"` at top of script
  - Swaybar clock now shows Pacific time instead of UTC. (SWE-2, commit 6b16472)

### Key Decisions
- **aider-chat via pip, not Nix** — Nix build fails due to sandbox network restrictions during the build phase. pip install is reliable and places binary on PATH via `~/.local/bin/`
- **Per-app `env -u LD_LIBRARY_PATH`** pattern continues — Cursor and Windsurf follow the same workaround as VSCode for nvidia GL library conflicts
- **Timezone set in 3 places** — sway-desktop.service (for all sway child processes), .zshrc (for interactive shells), and sway-status (for status bar clock) ensures no context falls back to UTC

### Pipeline
- PM created spec (F-0038-milestone-12-ai-ides-tools-timezone.md) with 5 features and acceptance criteria
- TPM created backlog items (F-0066 through F-0069) in Milestone 12
- SWE-1 implemented AI IDEs, CLI tools, keybindings
- SWE-2 implemented timezone fix
- Both SWEs ran in parallel on feature/languages branch

### Next Steps
- Verify all new tools after next workstation boot (cursor, windsurf, zed, aider, cody, pi, gh copilot)
- Verify timezone shows Pacific Time on status bar and in shell
- F-0055/F-0058/F-0063: E2E test carryovers from Milestones 8, 9, and 10
- Tag v1.12 release after PO approval

---

## Session 15 — 2026-03-31

### Goals
- Add OpenCode and Codex CLI as additional AI coding assistants (Milestone 11, F-0065)

### Completed

- **F-0065** (Add OpenCode + Codex CLI to boot scripts): Updated `workstation-image/boot/07-apps.sh` to install and upgrade two new AI CLI tools on every boot:
  - **Codex CLI** (`@openai/codex` v0.118.0) — installed via npm global, alongside existing Claude Code and Gemini CLI update line
  - **OpenCode** (`opencode` v0.0.55) — installed via `go install github.com/opencode-ai/opencode@latest`, binary placed in `$GOPATH/bin` on persistent disk
  - Both tools upgrade to latest on every subsequent boot
  - (SWE-1, commit 97f20fc)

### Key Decisions
- Codex added to existing npm global update line (same pattern as Claude Code / Gemini CLI)
- OpenCode uses `go install` since it's a Go binary — requires Go from Milestone 8 (F-0050)
- No API key configuration included (user manages their own keys per spec)

### Pipeline
- PM created spec (F-0037-ai-cli-tools.md) with 6 acceptance criteria
- TPM created backlog item (F-0065) in Milestone 11
- SWE-1 implemented boot script changes on feature/languages branch

### Next Steps
- Verify `codex --version` and `opencode --version` after next workstation boot
- F-0055/F-0058/F-0063: E2E test carryovers from Milestones 8, 9, and 10
- Tag v1.11 release after PO approval

---

## Session 14 — 2026-04-01

### Goals
- Execute Milestone 10: UX Polish — Wofi, Clipboard, Snippets, Waybar (F-0059 through F-0063)
- Fix broken Wofi app launcher (missing XDG_DATA_DIRS, no config/styling)
- Fix broken CTRL+SHIFT+A clipboard history daemon (nvidia LD_LIBRARY_PATH conflict)
- Create CTRL+SHIFT+S snippet picker (script never existed)
- Switch from swaybar to waybar with Apps dropdown button

### Completed

- **F-0059** (Fix Wofi app launcher + Tokyo Night styling): Fixed Wofi exec in sway config to set `XDG_DATA_DIRS=/home/user/.nix-profile/share:/usr/share:/usr/local/share` and wrap with `env -u LD_LIBRARY_PATH` so all Nix and system apps are discoverable. Created `workstation-image/configs/wofi/config` and `workstation-image/configs/wofi/style.css` with Tokyo Night palette. Created `workstation-image/boot/09-wofi.sh` to deploy wofi configs on boot. (SWE-1, commits e91bc08, ee67545)

- **F-0060** (Fix CTRL+SHIFT+A clipboard history daemon): Wrapped `wl-paste -t text --watch clipman store` autostart with `env -u LD_LIBRARY_PATH` and full Nix binary paths. Clipboard daemon now starts and runs without nvidia library conflicts. (SWE-2, commit e91bc08)

- **F-0064** (Fix clipman pick --tool invocation): `clipman pick --tool` expects tool name (`wofi`), not full path (`$nix/wofi`). Fixed by adding `PATH=/home/user/.nix-profile/bin:$PATH` to exec command so clipman can find wofi by name. (team-lead, commit 225aea7)

- **F-0061** (Fix CTRL+SHIFT+S snippet picker): Created `workstation-image/scripts/snippet-picker` — Wofi-based script that reads `~/.config/snippets/snippets.conf` (pipe-delimited `label | value` format), copies selected value to clipboard via `wl-copy`. Created `workstation-image/boot/09-snippets.sh` (no-clobber on existing snippets.conf). (SWE-2, commit e91bc08)

### Not Shipped

- **F-0062** (Switch to Waybar + Apps dropdown): **Reverted.** Waybar uses wlr-layer-shell protocol which doesn't render through wayvnc in headless Sway setup. Swaybar restored (commit 225aea7). Waybar config kept in repo for future activation. Apps dropdown needs alternative approach (e.g., swaybar click event or dedicated keybinding).

### Key Decisions
- **Per-invocation `env -u LD_LIBRARY_PATH`** workaround for all Nix binary invocations from sway — consistent pattern from Milestone 9
- **`XDG_DATA_DIRS`** must be explicitly set since wayvnc headless sessions don't populate it
- **Snippet config no-clobber** — boot script preserves existing user customizations
- **Waybar blocked by wayvnc** — wlr-layer-shell surfaces don't render through VNC. Swaybar remains the only viable bar for headless wayvnc. Waybar config preserved for when layer-shell support becomes available
- **clipman --tool** expects a tool name, not a full path — need PATH manipulation for Nix binaries

### Pipeline
- PM created spec (F-0036-milestone-10-ux.md) with 4 features
- TPM created backlog items (F-0059 through F-0063) in Milestone 10
- 3 SWEs ran in parallel: SWE-1 (wofi), SWE-2 (clipboard/snippets), SWE-3 (waybar)
- Post-deployment testing found waybar doesn't render via wayvnc — reverted to swaybar
- Post-deployment testing found clipman --tool bug — fixed

### Next Steps
- Brainstorm alternative Apps dropdown approach (swaybar doesn't support custom click modules — need creative solution)
- F-0063: E2E test Milestone 10 features (wofi, clipboard, snippets)
- F-0055/F-0058: E2E test carryovers from Milestones 8 and 9
- Tag v1.10 release after PO approval

---

## Session 13 — 2026-03-31

### Goals
- Execute Milestone 9: Fix IDE Keybindings (F-0056 through F-0058)
- Fix broken CTRL+SHIFT+M (IntelliJ) and CTRL+SHIFT+Y (VSCode) keybindings in sway config

### Completed

- **F-0056** (Fix sway config IDE keybindings): Fixed 3 bugs in `workstation-image/configs/sway/config`:
  1. IntelliJ binary name `idea-community` changed to `idea-oss` (matching Nix Home Manager package)
  2. Added `xwayland disable` directive + explicit `DISPLAY=:0` for IntelliJ exec (uses system `/usr/bin/Xwayland :0` instead of broken Nix Xwayland)
  3. Wrapped VSCode exec with `env -u LD_LIBRARY_PATH` to prevent nvidia GL library conflict
  - Root cause: nvidia `LD_LIBRARY_PATH=/var/lib/nvidia/lib64` from sway-desktop.service shadows Nix-provided libraries, breaking Xwayland (libX11 not found) and VSCode (libGLESv2 symbol mismatch)
  - (SWE-1, commit 526ecbb)

- **F-0057** (Boot script check): Verified no `idea-community` references in boot scripts (08-workspaces.sh or others) — only the sway config needed fixing. (SWE-1, commit 526ecbb)

- **F-0058** (E2E verification): Pending — requires testing on actual workstation to verify CTRL+SHIFT+M/Y work without errors

### Key Decisions
- **Per-app workaround** (not global fix): Clearing LD_LIBRARY_PATH for VSCode and using system Xwayland for IntelliJ avoids changing the sway-desktop.service GPU setup that other apps depend on
- **xwayland disable** prevents Sway's built-in Xwayland (Nix binary) from starting, which would fail under nvidia LD_LIBRARY_PATH

### Pipeline
- PM created spec (F-0035-fix-ide-keybindings.md)
- TPM created 3 backlog items (F-0056 through F-0058) in Milestone 9
- SWE-1 implemented sway config fix
- E2E verification pending (SWE-QA)

### Next Steps
- F-0058: E2E verify IDE keybindings on actual workstation (2+ projects)
- F-0055: E2E test language installations (Milestone 8 carryover)
- Tag v1.9 release after PO approval

---

## Session 12 — 2026-03-31

### Goals
- Execute Milestone 8: Programming Language Support (F-0050 through F-0055)
- Install Go, Rust, Python, Ruby with native version managers on persistent disk

### Completed

- **F-0050** (Language boot script `07b-languages.sh`): Created `workstation-image/boot/07b-languages.sh` — installs Go (tarball from go.dev), Rust (rustup), Python 3.12 (pyenv), Ruby 3.3 (rbenv). Idempotent: first boot does full install, subsequent boots update version managers only. (SWE-1, commit 2f8d437)

- **F-0051** (Language build deps `07a-lang-deps.sh`): Created `workstation-image/boot/07a-lang-deps.sh` — installs apt build dependencies (build-essential, libssl-dev, zlib1g-dev, etc.) needed by pyenv/rbenv to compile from source. Uses `dpkg -s` to skip already-installed packages. (SWE-1, commit 2f8d437)

- **F-0052** (Shell integration for language managers): Updated `workstation-image/boot/05-shell.sh` — added Go (GOROOT, GOPATH), Rust (.cargo/bin), pyenv (init), rbenv (init) to .zshrc. All entries placed before Starship init. Guarded with `command -v` checks to avoid errors if a manager isn't installed yet. (SWE-2, commit e702deb)

- **F-0053** (Cloud Build setup integration): Updated `scripts/cloud-build-setup.sh` — added Step 15/19 (language build deps) and Step 16/19 (language install + verification). Renumbered total steps from 17 to 19. Updated final summary output. (SWE-3, commit fbc537b)

- **F-0054** (README documentation): Updated `README.md` — added Languages row to "What's Included" table, added "Language Version Management" section with commands for switching Go, Rust, Python, and Ruby versions. (SWE-3, commit fbc537b)

- **F-0055** (E2E testing): Pending — requires running on actual workstation with stop/start cycle and testing on 2+ projects.

### Key Decisions
- **Hybrid approach**: Nix for system tools, native version managers (rustup, pyenv, rbenv) for programming languages — better ecosystem compatibility and multi-version support
- **Direct Go tarball** (not goenv) since multi-version Go is rare in practice
- **Python/Ruby compiled on first boot** (5-15 min); subsequent boots just update version managers (<30s)
- **Build deps via boot script** (not Docker image) to keep the base image lean
- **setup.sh glob pattern** updated from `[0-9][0-9]-*.sh` to `[0-9][0-9]*.sh` to support letter-suffixed scripts (07a, 07b)

### Pipeline
- PM created spec (F-0001-language-support)
- TPM created 6 backlog items (F-0050 through F-0055)
- SWE-1 implemented language deps + language install scripts
- SWE-2 implemented shell PATH integration
- SWE-3 updated cloud-build-setup.sh and README
- All three SWEs ran in parallel on feature/languages branch

### Next Steps
- F-0055: Run E2E test on actual workstation (stop/start cycle, verify on 2+ projects)
- Tag v1.8 release after PO approval
- Backlog otherwise empty — await next PO direction

---

## Session 1

### Goals
- Initial project setup and configuration

### Completed
- Generated project scaffolding with appteam
  - CLAUDE.md with team workflow, conventions, and pipeline rules
  - Agent definitions for PM, TPM, SWE-1, SWE-2, SWE-3, SWE-Test, SWE-QA, Platform Engineer, Reviewer
  - BACKLOG.md, PROGRESS.md, RELEASENOTES.md

### Next Steps
- Define initial feature backlog in BACKLOG.md
- Begin implementation of first milestone

---

## Session 2 — 2026-03-20

### Goals
- Execute Milestone 1: Stand up the Cloud Workstation with GPU, Antigravity, GNOME, noVNC

### Pre-existing State (discovered at session start)
- F-0001 (Cluster): `workstation-cluster` already exists in us-west1 — DONE
- F-0002 (Artifact Registry): `workstation-images` repo exists in us-west1 with images — DONE
- F-0003 (Docker Image): `workstation` image built and pushed (~3.3GB) with GNOME, Antigravity, Chrome, TigerVNC, noVNC — DONE
- All required APIs enabled (workstations, artifactregistry, compute)
- No SA key file found; using admin@your-org.example.com identity

### Completed
- **F-0001** (Cluster): Pre-existing `workstation-cluster` in us-west1
- **F-0002** (Artifact Registry): Pre-existing `workstation-images` repo in us-west1
- **F-0003** (Docker Image): Pre-existing `workstation` image (~3.3GB) with GNOME, Antigravity, Chrome, TigerVNC, noVNC
- **F-0004/F-0005** (Config): Created `ws-config` — n1-standard-16 + nvidia-tesla-t4, 500GB pd-ssd, 4h idle/12h run, no public IP, Shielded VM
- **F-0006** (GPU): Tesla T4 verified — Driver 535.288.01, CUDA 12.2, nvidia-smi at `/var/lib/nvidia/bin/`. Created `/etc/profile.d/nvidia.sh` for PATH/LD_LIBRARY_PATH
- **F-0007** (Nix): Nix 2.34.2 installed on persistent HOME disk. `nix-env -iA` works. Created Cloud Router `ws-router` + Cloud NAT `ws-nat` for internet access
- **F-0008** (IAM/Network): admin@your-org.example.com has workstations.user. AR reader granted to service agent. No public IP + Shielded VM (org policies). your-email@example.com access pending (API precondition issue — can be set when workstation is stopped) (removed — no longer needed)
- **F-0009** (Workstation): `dev-workstation` RUNNING at `dev-workstation.cluster-wg3q6vm6rnflcvjsrq5k7aqoac.cloudworkstations.dev`
- **F-0010** (E2E): All verified — Antigravity installed, noVNC active (HTTP 302 via proxy), TigerVNC active, T4 GPU working, Nix 2.34.2 with package install, 492GB home disk available

### Issues Encountered and Resolved
1. `--idle-timeout=14400s` invalid — int expected, no suffix — FIXED
2. `g2-standard-16` NOT supported by Cloud Workstations — used `n1-standard-16` + `nvidia-tesla-t4` instead
3. `nvidia-l4` accelerator NOT supported — used `nvidia-tesla-t4` (T4 16GB VRAM)
4. `roles/workstations.user` cannot be bound at project level — granted at workstation level automatically on create
5. Org policy `constraints/compute.vmExternalIpAccess` — added `--disable-public-ip-addresses`
6. Org policy `constraints/compute.requireShieldedVm` — added `--shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring`
7. No internet inside workstation — created Cloud Router + Cloud NAT
8. `nvidia-smi` not in PATH — found at `/var/lib/nvidia/bin/`, created profile script
9. `owner-sa` service account does not exist — not critical, skipped

### Decisions
- Used admin@your-org.example.com identity (no SA key file)
- Machine type: n1-standard-16 (60GB RAM) since g2-standard-16 not supported by Cloud Workstations
- GPU: nvidia-tesla-t4 since nvidia-l4 not supported as accelerator
- Cloud NAT for internet access (required due to no public IP org policy)

### Next Steps
- Grant your-email@example.com access (stop workstation, set IAM, restart) (removed — no longer needed)
- Test stop/start cycle to verify persistence (Nix, GPU profile, data)
- Tag v1.0 release after PO approval

---

## Session 3 — 2026-03-20 (continued)

### Goals
- Milestone 2: Migrate all app installs to Nix Home Manager
- Install Sway + Waybar with 8 workspaces and custom keybindings
- Install full app suite: neovim, tmux, zsh, ffmpeg, chromium, chrome, vscode, intellij, cursor, claude-code, gemini-cli
- Configure Neovim with custom init.lua

### Completed So Far
- Moved /nix to persistent disk at /home/user/nix with bind mount (not symlink — Nix rejects symlinks)
- Added 200_persist-nix.sh startup script to Docker image (restores /nix bind mount + nvidia paths on boot)
- Rebuilt Docker image via Cloud Build (SUCCESS)
- Rebooted workstation — startup scripts verified working (/nix bind mount, nvidia, VNC)
- Copied Antigravity to persistent disk at ~/.antigravity — verified working after reboot (v1.107.0)
- Created specs: F-0011 (nix migration), F-0016 (sway/waybar), F-0017 (nix HM apps)
- Saved Sway keybindings, Neovim keybindings, and Neovim init.lua config locally
- Created Milestone 2 backlog (F-0011 through F-0019)
- Committed all specs and configs
- Installed Nix Home Manager v26.05-pre
- Created comprehensive home.nix with ALL packages: neovim, tmux, tree, zsh, ffmpeg, chromium, google-chrome, vscode, jetbrains.idea-community, sway, waybar, foot, wofi, thunar, clipman, wayvnc, nodejs_22
- Created Sway config with full keybindings (CTRL+SHIFT modifier, 8 workspaces)
- Created Waybar config (workspaces, CPU, memory, disk, clock)
- Created Neovim init.lua config (Space leader, floating terminal, habamax theme)
- Running home-manager switch to install everything
- Fixed: jetbrains.idea-community removed from nixpkgs — using jetbrains.idea-oss
- Fixed: Added nixpkgs.config.allowUnfree = true for Chrome, VSCode, etc.
- Fixed: /nix must be bind mount, not symlink — Nix rejects symlinks
- home-manager switch SUCCESS — all packages installed
- Verified all apps: NVIM 0.11.6, tmux 3.6a, zsh 5.9, ffmpeg 8.0.1, Chromium 146, Chrome 146, VSCode 1.111.0, IntelliJ OSS, Sway 1.11, Waybar 0.15.0, foot 1.26.1, Node.js 22.22.1
- Claude Code 2.1.80 and Gemini CLI 0.34.0 installed via npm to ~/.npm-global/bin
- All configs deployed: Neovim init.lua, Sway config (8 workspaces, CTRL+SHIFT keybindings), foot config
- Switched from GNOME to Sway desktop via wayvnc (headless backend)
- Waybar layer-shell surfaces don't render with headless+wayvnc — using swaybar (sway's built-in bar) instead
- Swaybar showing: workspace indicators (left), LOAD/MEM/datetime (right), dark #1a1b26 theme
- Created sway-status script at ~/.local/bin/sway-status for bar status output
- Created systemd services: sway-desktop.service, wayvnc.service (replacing TigerVNC)

### Pending
- F-0019: E2E validation (blocked on all above)

---

## Session 4 — 2026-03-20 (continued)

### Goals
- Milestone 3: Modernize Sway and status bar appearance (Tokyo Night theme, gaps, colored status)
- Fix boring/dated desktop look
- Add comprehensive setup documentation to backlog

### Completed
- **F-0020** (Modern Sway config): Created `workstation-image/configs/sway/config` with:
  - Tokyo Night color palette (10 variables: bg, fg, accent, urgent, green, yellow, magenta, cyan, muted, inactive)
  - Gaps: 6px inner, 12px outer, smart_gaps on
  - 2px pixel borders with Tokyo Night-themed client colors (focused=#7aa2f7, unfocused=#414868, urgent=#f7768e)
  - All 33 keybindings from F-0016 preserved (CTRL+SHIFT modifier, 8 workspaces, all app launchers)
  - Floating window rules for dialogs, pop-ups, file operations
  - Integrated swaybar with Tokyo Night workspace colors
  - Headless output config (HEADLESS-1 1920x1080) for wayvnc
  - Clipboard manager autostart (wl-paste + clipman)

- **F-0021** (Modern swaybar status): Created `workstation-image/configs/swaybar/sway-status` with:
  - i3bar JSON protocol ({"version":1} header + continuous JSON array stream)
  - 6 modules: NET, GPU, CPU, MEM, DISK, Clock
  - Color-coded thresholds: green (#9ece6a) < warn, yellow (#e0af68) < crit, red (#f7768e)
  - CPU: real-time via /proc/stat delta sampling (500ms)
  - Memory: used/total from /proc/meminfo
  - Disk: /home partition from df
  - GPU: nvidia-smi temp + utilization (graceful N/A fallback)
  - Network: ping-based connectivity check
  - 2-second refresh loop

- **F-0022** (Waybar config for future): Created for when layer-shell works on wayvnc:
  - `workstation-image/configs/waybar/config.jsonc` — modules: workspaces, mode, window, network, gpu, cpu, memory, disk, clock with warning/critical states and calendar tooltip
  - `workstation-image/configs/waybar/style.css` — Tokyo Night CSS with semi-transparent bg, pill-shaped modules (12px radius), hover effects, urgent-pulse animation, color-coded states

- **F-0020 spec**: Created `docs/specs/F-0020-modern-sway-waybar.md` with 4 requirements and 7 acceptance criteria
- **Backlog updated**: Added Milestone 3 section with F-0020 through F-0024, including F-0023 for comprehensive setup documentation

### Pipeline
- PM created spec and backlog items
- SWE-1 implemented Sway config (all 33 keybindings verified)
- SWE-2 implemented swaybar status script and Waybar config/CSS
- All three agents ran in parallel

### Decisions
- Kept swaybar (not Waybar) as active bar — Waybar layer-shell doesn't render on wayvnc headless
- Tokyo Night as the standard theme across all components
- i3bar JSON protocol for color-coded status output
- Created Waybar config+CSS for future swap when layer-shell issue is resolved
- Added F-0023 (comprehensive setup documentation) to backlog per PO request

### Deployment
- **Deployed all 4 configs** to workstation via `gcloud workstations ssh` pipe:
  - `~/.config/sway/config` (7937 bytes) — replaced Nix HM symlink with regular file
  - `~/.local/bin/sway-status` (4758 bytes, executable) — i3bar JSON protocol script
  - `~/.config/waybar/config` (2638 bytes) — for future use
  - `~/.config/waybar/style.css` (5088 bytes) — for future use
- Removed stale Nix Home Manager symlinks pointing to old configs in Nix store
- **Sway reloaded** via swaymsg — `{"success": true}`
- Fixed gcloud auth (corrupted GCE credential entry in credentials.db)
- Verified: 3 workspaces active on HEADLESS-1 (1920x1080), inner gaps (6px) and outer gaps (12px) applied

### Bug Fix
- **Swaybar not spawning**: Sway's process PATH only included system dirs, not Nix store paths. Swaybar binary couldn't be found. Fixed by adding explicit `swaybar_command /home/user/.nix-profile/bin/swaybar` and using absolute path for `status_command`. After reload, swaybar spawned successfully with sway-status script running.
- **PO confirmed** swaybar visible with Tokyo Night theme and color-coded status modules.

### Critical Bug Fixes (Nix PATH isolation)
- **Root cause discovered**: Sway's systemd service PATH doesn't include Nix profile dirs. ALL Nix-installed binaries (foot, wofi, thunar, code, clipman, swaynag, swaymsg, idea-community) were unfindable from keybindings.
- **Fix**: Added `$nix` variable (`/home/user/.nix-profile/bin`) in sway config, all exec commands now use full paths
- **Antigravity crash (code 4)**: Electron app was trying X11 backend (`Missing X server or $DISPLAY`). Fixed with `--no-sandbox --ozone-platform=wayland` flags. Xwayland also started for X11 apps.
- **VS Code**: Same Electron fix applied (`--no-sandbox --ozone-platform=wayland`)
- **GPU N/A in status bar**: sway-status script used bare `nvidia-smi` which wasn't in PATH. Fixed to `/var/lib/nvidia/bin/nvidia-smi`. GPU now shows T4 temp + utilization.
- **NVIDIA libs system-wide**: Added `/var/lib/nvidia/lib64` to `/etc/ld.so.conf.d/nvidia.conf` and ran ldconfig. All apps can now find CUDA/nvidia libs without LD_LIBRARY_PATH.
- **floating_modifier**: Changed from `Ctrl+Shift` (invalid — sway only accepts single modifier) to `Mod4`
- **sway-desktop.service**: Updated with `LD_LIBRARY_PATH=/var/lib/nvidia/lib64`

### Antigravity Renderer Crash (code 5)
- **Root cause**: `/dev/shm` only 64MB (k8s container default). Chromium renderer OOM on shared memory.
- **Fix**: `--disable-dev-shm-usage` on all Electron/Chromium apps (Antigravity, VS Code, Chrome) — uses `/tmp` (31GB) instead.
- **Not GPU-related** — Tesla T4 is healthy. GPU compositing disabled (`--disable-gpu`) since we're on VNC; CUDA compute unaffected.
- **PO confirmed** Antigravity launches and runs stable.

### Next Steps
- F-0023: Create comprehensive setup guide for recreating workstation from scratch
- F-0019: Post-reboot E2E validation (Milestone 2 carryover)
- Persist nvidia ldconfig fix in Docker image startup scripts (ephemeral disk)

---

## Session 5 — 2026-03-20

### Goals
- Complete remaining open items: F-0019 (Post-reboot E2E validation), F-0023 (Comprehensive setup documentation)
- Fix Sway not starting on boot (F-0025)

### Completed
- **F-0019** (Post-reboot E2E validation): SWE-QA validated all components after workstation stop/start cycle.
  - 33 PASS, 1 WARN, 0 FAIL
  - All 17 Nix apps verified (nvim 0.11.6, tmux 3.6a, zsh 5.9, ffmpeg 8.0.1, Chromium 146, Chrome 146, VSCode 1.111.0, foot 1.26.1, sway 1.11, waybar 0.15.0, wofi 1.5.3, thunar 4.20.7, node 22.22.1, rg 15.1.0, fd 10.4.2, jq 1.8.1, tree 2.3.1)
  - AI tools: Claude Code 2.1.80, Gemini CLI 0.34.0
  - GPU: Tesla T4, Driver 535.288.01, CUDA 12.2 (WARN: nvidia-smi needs LD_LIBRARY_PATH in non-login shells)
  - Nix store: 8,346 packages on persistent disk (symlink /nix → /home/user/nix)
  - Antigravity binary: 199MB at ~/.antigravity/antigravity/antigravity
  - Persistent disk: 492G total, 13G used, 479G available (3%)
  - Configs: home.nix, sway config, sway-status, init.lua all present and functional

- **F-0023** (Comprehensive setup documentation): SWE-3 created `docs/SETUP.md` (1,137 lines, 14 sections).
  - Prerequisites, Infrastructure, Docker Image, Workstation Config, Nix, Home Manager, Sway Desktop, App Config, AI CLI Tools, Antigravity, GPU Setup, Troubleshooting (10 issues), Architecture Reference
  - Includes actual gcloud commands, full config files, keybinding tables, ASCII architecture diagram

- **F-0025** (Sway auto-start on boot): SWE-1 created `workstation-image/assets/etc/workstation-startup.d/300_setup-sway-desktop.sh`.
  - Creates sway-desktop.service and wayvnc.service on every boot (ephemeral disk)
  - Disables TigerVNC (port 5901 conflict), keeps noVNC (proxies port 80 → 5901)
  - Adds nvidia ldconfig (/var/lib/nvidia/lib64 → /etc/ld.so.conf.d/nvidia.conf)
  - Deployed to running workstation and verified: Sway active, wayvnc on 5901, swaymsg responding

### Issues Found and Fixed
1. **Workstation was stopped** — SWE-QA started it automatically before running validation
2. **GNOME running instead of Sway** — TigerVNC/GNOME services baked into Docker image; Sway services were on ephemeral disk. Fixed by F-0025 startup script
3. **nvidia-smi LD_LIBRARY_PATH** — Non-login shells can't find libnvidia-ml.so. Fixed by F-0025 startup script (ldconfig)

### Decisions
- Used in-process background agents (tmux panes too small for interactive teams)
- F-0025 added as P0 bug fix when PO noticed GNOME instead of Sway after reboot
- Startup script approach (not Docker rebuild) for fast deployment; script in repo for next image build

### Next Steps
- Rebuild Docker image to include 300_setup-sway-desktop.sh natively
- All milestones 1-3 items complete (F-0001 through F-0025)
- Tag v1.3 release after PO approval

---

## Session 6 — 2026-03-20

### Goals
- Tag v1.3 release
- Rebuild Docker image with startup scripts baked in
- Clean up docs (remove obsolete your-email@example.com IAM item)

### Completed
- **v1.3 tagged** — Annotated git tag for Milestone 3 completion
- **F-0026** (Docker image rebuild): Rebuilt image via Cloud Build to natively include `300_setup-sway-desktop.sh` (Sway auto-start on boot). Old AR images cleaned up.
- **your-email@example.com IAM** — Removed from all docs (PO confirmed no longer needed)
- **All docs updated**: BACKLOG.md, PROGRESS.md, RELEASENOTES.md

### Decisions
- your-email@example.com IAM access removed per PO direction (no longer needed)
- Docker image now includes all 3 startup scripts natively (no manual deployment needed after reboot)

### Next Steps
- Reboot workstation to verify new image works end-to-end
- Future items backlog is empty — await next PO direction

---

## Session 7 — 2026-03-20

### Goals
- Tag v1.3 release and rebuild Docker image (final rebuild)
- Plan Milestone 4: Auto-start workspace, shell/font setup, persistent disk bootstrap
- Architectural shift: move all setup to persistent disk, eliminate future Docker rebuilds

### Completed
- **F-0026** (Docker image rebuild): Cloud Build SUCCESS (`sha256:eeaea8493bdc`). Image pushed to AR. Old images cleaned up.
- **v1.3 tagged**: Annotated git tag for Milestone 3 completion
- **F-0027 spec** created: Auto-start workspace with Cloud Scheduler (7AM PT), app updates, 4 pre-launched workspaces
- **F-0030 spec** created: ZSH shell + Nerd Fonts + Starship prompt + terminal config
- **F-0030 spec updated**: PO added `dev-fonts/` directory with Operator Mono, CascadiaCode, CaskaydiaCove NF, FiraCodeiScript. Terminal font changed to Operator Mono Book size=18
- **F-0033 spec** created: Persistent disk bootstrap architecture — lean Docker image + `~/boot/setup.sh`
- **Milestone 4 backlog** created with 7 items: F-0027 through F-0033
- **your-email@example.com IAM** removed from all docs (PO confirmed no longer needed)
- **Interim commits** made after each agent completes to prevent data loss
- **Workstation restarted** with new image — E2E validation: 10 PASS, 1 FAIL (VNC port conflict)
- **VNC port conflict fixed**: TigerVNC from base image was grabbing port 5901 before wayvnc. Fixed by masking tigervnc.service and killing Xtigervnc in startup script. Sway desktop now served correctly via wayvnc + noVNC.

### Architectural Decision: Persistent Disk Bootstrap (F-0033)
- **Problem**: Docker image is 3.3GB and requires Cloud Build rebuild for every change
- **Solution**: Minimal Docker image with single `000_bootstrap.sh` that calls `~/boot/setup.sh` on persistent disk
- **Impact**: All future features (fonts, ZSH, configs, apps) deploy to persistent disk only — zero Docker rebuilds
- **Migration**: One-time rebuild to create lean image, then move all setup logic to `~/boot/` sub-scripts
- PO approved this approach

### Decisions
- Milestone 4 scope expanded: auto-start + shell/fonts + persistent bootstrap
- Operator Mono selected as primary terminal font (from PO's dev-fonts/ directory)
- ZSH plugins via direct git clone (no plugin manager per PO requirement)
- All future changes target persistent disk, not Docker image

### Next Steps
- Begin Milestone 4 execution: F-0033 first (persistent bootstrap), then F-0027-F-0032
- Note: startup script fix (mask TigerVNC) needs to be included in next Docker rebuild or persistent bootstrap

---

## Session 8 — 2026-03-20

### Goals
- Execute Milestone 4: Auto-Start & Daily Readiness (F-0027 through F-0033)
- Create persistent disk bootstrap architecture
- Install fonts, ZSH, Starship, foot config
- Set up Cloud Scheduler and workspace auto-launch

### Completed

- **F-0033** (Persistent disk bootstrap): Created 9 scripts in `workstation-image/boot/`:
  - `setup.sh` — Master orchestrator, sources all `[0-9][0-9]-*.sh` scripts in order
  - `01-nix.sh` — Restores /nix bind mount from /home/user/nix
  - `02-nvidia.sh` — nvidia ldconfig + PATH/LD_LIBRARY_PATH profile script
  - `03-sway.sh` — Creates sway-desktop + wayvnc systemd services, masks TigerVNC
  - `04-fonts.sh` — Installs fonts from ~/boot/fonts/ to ~/.local/share/fonts/
  - `05-shell.sh` — ZSH default shell + plugins + .zshrc
  - `06-prompt.sh` — Starship install + foot.ini config
  - `07-apps.sh` — npm and Nix app updates, logs to ~/logs/app-update.log
  - `08-workspaces.sh` — Auto-launches foot, Chrome, Antigravity, foot on 4 workspaces
  - `000_bootstrap.sh` — Docker image bridge script (delegates to ~/boot/setup.sh)
  - All scripts deployed to workstation persistent disk at ~/boot/

- **F-0030** (Fonts): 223+ fonts installed from dev-fonts/ repo directory:
  - 12 Operator Mono variants (XLight through Bold, Regular/Italic)
  - 168 CascadiaCode variants (Code, Mono, PL in OTF+TTF)
  - 19 FiraCodeiScript variants
  - 24 CaskaydiaCove Nerd Font variants
  - Font cache rebuilt via fc-cache

- **F-0031** (ZSH): Default shell configured:
  - `exec zsh` added to .bashrc (container chsh workaround)
  - zsh-syntax-highlighting cloned to ~/.zsh/
  - zsh-autosuggestions cloned to ~/.zsh/
  - .zshrc: Nix profile, PATH, history (10K lines), emacs bindings, completions, plugins, Starship init

- **F-0032** (Starship + foot): Terminal environment configured:
  - Starship 1.24.2 installed via curl to ~/.local/bin/
  - foot.ini: Operator Mono Book:size=18, Tokyo Night [colors-dark] theme, 8px padding, 10K scrollback

- **F-0028** (App updates): Boot-time app update script:
  - npm update for Claude Code + Gemini CLI
  - nix-channel --update + home-manager switch for VSCode, IntelliJ
  - Logs to ~/logs/app-update.log

- **F-0029** (Workspace auto-launch): 4 workspaces pre-populated:
  - ws1=foot, ws2=Chrome (--ozone-platform=wayland), ws3=Antigravity, ws4=foot
  - SWAYSOCK auto-discovery for root→user swaymsg calls
  - Waits up to 120s for Sway ready, idempotent (skips if windows exist)

- **F-0027** (Cloud Scheduler): Daily 7AM PT auto-start:
  - Job `ws-daily-start` in us-west1
  - Cron: `0 7 * * *` America/Los_Angeles
  - HTTP POST to Workstations API startWorkstation with OAuth token
  - Next scheduled run: 2026-03-21T14:00:00Z

### Issues Found and Fixed
1. **swaymsg SWAYSOCK**: Running swaymsg as root via runuser couldn't find Sway socket. Fixed by auto-discovering `/run/user/1000/sway-ipc.*.sock` and passing as SWAYSOCK env var.
2. **Chrome X11 fallback**: `google-chrome-stable` without `--ozone-platform=wayland` tried X11 and crashed. Fixed by adding wayland flag in 08-workspaces.sh.
3. **foot.ini [colors] deprecated**: Newer foot versions require `[colors-dark]` instead of `[colors]`. `[cursor].color` also invalid. Fixed both.
4. **cp -n warning**: GNU coreutils deprecated `-n` flag. Changed to `--update=none` in 04-fonts.sh.
5. **Tmux pane size**: Interactive agent teams failed (tmux panes too small). Work done directly by orchestrator.

### Decisions
- All boot scripts stored in repo at `workstation-image/boot/` and deployed to `~/boot/` on persistent disk
- Starship installed via curl (not in Nix) — more reliable for standalone binary
- Chrome in 08-workspaces.sh uses system wrapper (`google-chrome-stable` with Docker divert) + `--ozone-platform=wayland`
- 07-apps.sh runs Nix channel update + home-manager switch (may take 10-15s on boot)
- Docker image lean rebuild deferred — 000_bootstrap.sh created but current image still has old startup scripts (harmless, 000_bootstrap runs first by sort order)

### Next Steps
- Rebuild lean Docker image (remove GNOME, Chrome APT, Antigravity APT — keep only base + systemd + TigerVNC/noVNC + 000_bootstrap.sh)
- Reboot workstation to verify full bootstrap flow end-to-end
- Tag v1.4 release after PO approval
- Backlog is empty — await next PO direction

---

## Session 8b — 2026-03-20

### Goals
- Fix workspace auto-launch timing (apps not appearing on noVNC login)
- Fix TigerVNC overlay filesystem masking bug
- Build Milestone 5: One-click setup via Cloud Build

### Completed

- **Workspace auto-launch fixed (F-0029)**:
  - Root cause: 08-workspaces.sh ran from setup.sh during entrypoint (before systemd), but Sway starts as a systemd service after entrypoint
  - Fix: Created `ws-autolaunch.service` in 03-sway.sh that runs 08-workspaces.sh after wayvnc.service
  - Excluded 08-workspaces.sh from setup.sh (runs via systemd now)
  - Fixed workspace assignment: replaced fixed sleep with window-count polling (waits for window to appear before switching workspace)
  - Reboot verified: ws1=foot, ws2=chrome, ws3=antigravity, ws4=foot

- **TigerVNC overlay fix**:
  - `ln -sf /dev/null` fails on container overlay fs with regular files
  - Fixed to `rm -f` then `ln -s` in both 300_setup-sway-desktop.sh and 03-sway.sh
  - Docker image rebuilt (sha256:7b785b48) with fix + 000_bootstrap.sh
  - Reboot verified: TigerVNC masked, wayvnc on port 5901

- **Milestone 5: One-click setup (F-0034 through F-0037)**:
  - `scripts/setup.sh` — Launcher script (~80 lines): parses -p PROJECT_ID, validates auth/Owner, enables Cloud Build, grants SA Owner role, submits build async
  - `scripts/cloud-build-setup.sh` — Main setup (~350 lines): 15 idempotent steps with retry logic (retry up to 3x with delays), self-recovery, and built-in verification tests (PASS/FAIL/WARN counters)
  - Steps: Enable APIs → AR → Docker build → Cloud NAT → Cluster → IAM → Config → Workstation → Nix → Home Manager → Boot scripts/fonts → Configs → Initial setup → AI tools → Cloud Scheduler
  - `README.md` — Quick start guide for colleagues
  - `docs/specs/F-0034-one-click-setup.md` — Full spec

- **GitHub repo**: All changes pushed to https://github.com/your-github-username/cloud-workstations

### Decisions
- Cloud Build as execution engine (not Cloud Shell) — persistent, survives terminal close
- setup.sh uses --async so user can close terminal immediately
- cloud-build-setup.sh runs nested Cloud Build for Docker image (build-within-build)
- All steps idempotent with resource_exists checks
- Built-in test suite validates each step (PASS/FAIL/WARN)

### Next Steps
- E2E test one-click setup on a clean project (F-0038)
- Tag v1.5 after PO approval

---

## Session 9 — 2026-03-20 to 2026-03-21

### Goals
- Test ws.sh setup script on project YOUR_PROJECT_ID (fresh project)
- Fix all issues discovered during testing
- Teardown and re-setup to verify fixes

### Completed

- **F-0038** (E2E test of one-click setup): Tested on YOUR_PROJECT_ID, discovered and fixed 5 critical issues
- **F-0039** (Fix setup for fresh GCP projects): Fixed VPC network creation, SA permissions, webhook URL escaping
- **F-0040** (Nix store persistence): Added Step 11/17 to copy /nix → /home/user/nix for restart survival
- **F-0041** (noVNC tests): Added Step 17/17 verifying Sway, wayvnc:5901, noVNC:80, HTTP accessibility
- **F-0046** (Consolidated ws.sh): Single script handles setup (via Cloud Build) and teardown with webhook notifications

### Issues Found and Fixed
1. **No default VPC network** — fresh projects don't have one. Script now auto-creates
2. **Wrong service account** — newer GCP projects use Compute Engine SA, not Cloud Build SA. Now grants to both
3. **No --service-account on workstation config** — image pull 403. Added to Step 7
4. **Nix store not persisted** — /nix is ephemeral on restart. Added copy to /home/user/nix (Step 11)
5. **Webhook URL & in substitutions** — broke Cloud Build submission. Fixed with array-based escaping
6. **No Cloud Logging permissions** — build logs invisible. Added Logs Writer role

### Test Results
- YOUR_PROJECT_ID final run: 33 PASS / 0 FAIL / 0 WARN / 41 min
- YOUR_PROJECT_ID first run: 33 PASS / 0 FAIL / 0 WARN / 41 min
- Setup steps expanded from 15 to 17 (added Nix persistence + noVNC tests)

### Decisions
- Run setup directly (not via Cloud Build) for better log visibility during development
- Auto-detect REPO_DIR so script works both in Cloud Build and locally
- NIX_SOURCE helper handles both old and new Nix profile paths

---

## Session 10 — 2026-03-22 to 2026-03-24

### Goals
- Fix noVNC accessibility issues on YOUR_PROJECT_ID/03
- Fix Antigravity keybinding and autostart
- Fix swaybar on YOUR_PROJECT_ID
- Configure weekday-only schedulers on all 3 projects
- Full teardown and re-setup verification

### Completed

- **F-0042** (Fix Antigravity path): Sway config and 08-workspaces.sh both referenced /home/user/.antigravity/antigravity/antigravity which didn't exist. Changed to /usr/bin/antigravity (apt-installed in Docker image). Removed dummy .antigravity download from setup script.
- **F-0043** (Fix swaybar on YOUR_PROJECT_ID): YOUR_PROJECT_ID had old sway config using i3status-rust. Deployed current repo config (sway-status). Also removed outer gaps (12→0) for better window sizing.
- **F-0044** (Weekday scheduler): All 3 projects now have ws-weekday-start (6AM Mon-Fri) and ws-weekday-stop (9PM Mon-Fri). Workstations off on weekends. Old ws-daily-start (7AM daily) removed.
- **F-0045** (Fix Antigravity autostart ws3): 08-workspaces.sh had old Antigravity path, causing -x check to fail silently. Fixed path + increased timeout 15s→30s.

### Full Re-Setup Results (teardown + setup from scratch)
- YOUR_PROJECT_ID: 33 PASS / 0 FAIL / 0 WARN + 25/25 post-setup tests
- YOUR_PROJECT_ID: 33 PASS / 0 FAIL / 0 WARN + 25/25 post-setup tests
- Antigravity autostart verified on both after full stop/start cycle

### Post-Setup Test Suite (25 tests per workstation)
1. Sway running, 2. Swaybar running, 3. wayvnc on 5901, 4. noVNC on 80, 5. noVNC HTTP,
6. Antigravity binary, 7. Antigravity version, 8. Desktop entry, 9. Keybinding correct,
10. Nix store persisted, 11. Nix binary works, 12. Sway binary, 13. wayvnc binary,
14. Boot scripts (9), 15. Fonts, 16. ZSH, 17. Starship, 18. foot.ini, 19. ZSH plugins,
20. Claude Code, 21. Gemini CLI, 22. Cloud Scheduler, 23. Gaps outer 0, 24. Chrome, 25. VS Code keybind

### Decisions
- Antigravity is apt-installed (/usr/bin/antigravity) — never use .antigravity download path
- Outer gaps set to 0 for edge-to-edge windows (inner gaps 6px retained)
- Scheduler changed from daily to weekday-only (Mon-Fri) per PO request
- Agent teams used for parallel work across projects

### Next Steps
- All 3 workstations operational and tested
- Memory files created for future session context

---

## Session 11 — 2026-03-26

### Goals
- Fix Claude Code not working after workstation reboot (missing env vars)
- Investigate gcloud auth persistence across reboots

### Completed

- **F-0047** (Persistent .env sourcing): Root cause found and fixed.
  - **Root cause**: `05-shell.sh` uses `cat > "$ZSHRC"` to recreate `.zshrc` from scratch on every boot, destroying any manually added `source ~/.env` line
  - **Fix**: Added `source ~/.env` block (with `set -a` / `set +a` for auto-export) to the `.zshrc` template inside `05-shell.sh` (lines 89-94), so it survives reboots
  - Also replaced the current `.zshrc` (was a Nix store symlink, read-only) with a writable copy including the fix for immediate effect
  - Verified: new ZSH shell correctly picks up `CLAUDE_CODE_USE_VERTEX=1` and `ANTHROPIC_VERTEX_PROJECT_ID=YOUR_PROJECT_ID`

- **gcloud auth investigation**: Confirmed credentials persist on disk (`~/.config/gcloud/credentials.db` and `application_default_credentials.json` on persistent disk with valid refresh tokens). No boot scripts touch gcloud. Auth should survive reboots — the real issue was likely the missing env vars causing Claude Code to fail, leading to re-auth as troubleshooting habit.

### Files Changed
- `boot/05-shell.sh` — Added `source ~/.env` block to .zshrc template
- `~/.zshrc` — Replaced Nix store symlink with writable file including .env sourcing

### Decisions
- Used `set -a` / `set +a` wrapper around `source ~/.env` to auto-export all variables (needed for Claude Code subprocess inheritance)
- gcloud SA key-based auth deferred — will revisit if refresh tokens still expire after the .env fix eliminates the Claude Code failure

### Next Steps
- Verify after next reboot that Claude Code works without manual `source ~/.env`
- If gcloud auth still requires re-login after reboot, set up service account key-based auth

---

## Session 11b — 2026-03-26

### Goals
- Split repo into public template + private personal repo
- Make cloud-workstations shareable with colleagues (no personal info)

### Completed

- **F-0048** (Repo split: private personal + public template):
  - **Private repo**: Pushed current repo (with all personal info) to `your-private-repo` (private) including all branches and tags (v1.3, v1.4)
  - **Templatization**: Replaced all personal info across 38 files with generic placeholders:
    - `YOUR_PROJECT_ID/02/03` → `YOUR_PROJECT_ID`
    - `938099127340` → `YOUR_PROJECT_NUMBER`
    - `your-org.example.com` → `your-org.example.com`
    - `admin@...` → `admin@your-org.example.com`
    - `your-email@example.com` → `your-email@example.com`
    - `Your Name` → `Your Name`
    - `your-github-username` (GitHub) → `your-github-username`
  - **configure.sh**: Created `scripts/configure.sh` (221 lines) — onboarding script that prompts for 7 values, validates inputs, shows confirmation, runs sed replacements across all files, prints next steps
  - **README updated**: Added Quick Start section (clone → configure → setup), added Step 2 (configure.sh) between auth and setup
  - **Verified**: grep confirms zero remaining personal identifiers in tracked files

### Agent Team
- SWE-1: Pushed to private repo (your-private-repo)
- SWE-2: Templatized all 38 files
- SWE-3: Created configure.sh + updated README

### Files Changed
- 36 files modified (all personal info replaced with placeholders)
- 1 new file: `scripts/configure.sh`

- **F-0049** (Remove configure.sh): Eliminated separate configure.sh script that was modifying 38 tracked files and creating permanent dirty git state. ws.sh now auto-detects REPO_URL from `git remote get-url origin`. README simplified from 3 steps to 2 (clone → ws.sh setup). Repo stays clean with generic placeholders.

### Decisions
- Two-repo approach: public template (cloud-workstations) + private personal (your-private-repo)
- Private repo added as `private` remote for easy syncing
- configure.sh uses sed with proper escaping for special characters
- Replacement order: specific patterns first (SA email) before generic (PROJECT_ID) to avoid double-replacement

### Next Steps
- For daily work, use `your-private-repo` (private repo with personal values)
- To share improvements, cherry-pick from private to public repo
- Colleagues: clone public repo → run configure.sh → run ws.sh setup

---

## Session 21 — 2026-04-15

### Date
2026-04-15

### Milestone
Milestone 18 — Claude Code Auto-Update Fix (F-0093)

### Goals
- Fix Claude Code's in-process auto-updater failing with EACCES on `/usr/lib/node_modules`
- Make the npm user prefix (`/home/user/.npm-global`) persistent across shells and auto-update subprocesses
- Ensure the fix survives teardown + re-setup (no live-only changes)

### Completed
- **PM** produced `docs/specs/F-0093-claude-autoupdate-fix.md` capturing root cause (Claude auto-updater invokes `npm install -g` and reads `npm config get prefix`, which returned `/usr` because only `--prefix` was passed inline during install) and acceptance criteria
- **SWE-1** fixed `workstation-image/boot/11-custom-tools.sh::install_claude_code` to idempotently write `prefix=/home/user/.npm-global` into `~/.npmrc` (user-owned, preserves any existing non-prefix entries) in addition to the existing `--prefix` install flag, so `npm config get prefix` resolves correctly for all future invocations including Claude's auto-update subprocess
- **SWE-1** added a boot test in `workstation-image/boot/10-tests.sh` asserting `npm config get prefix` returns `/home/user/.npm-global`, so regressions are caught on every boot
- **SWE-1** updated `docs/STARTUP_SCRIPTS.md` to describe the new `~/.npmrc` persistence behavior in the `11-custom-tools.sh` entry
- **PO** confirmed the live fix works on the running workstation — `claude update` no longer fails and the in-process auto-updater completes cleanly

### Agent Team
- PM: spec authoring (F-0093)
- SWE-1: boot script fix, test, docs
- TPM: backlog + progress updates (this entry)

### Files Changed
- `workstation-image/boot/11-custom-tools.sh` — idempotent `~/.npmrc` prefix write in `install_claude_code`
- `workstation-image/boot/10-tests.sh` — new assertion on `npm config get prefix`
- `docs/STARTUP_SCRIPTS.md` — documented the new behavior
- `docs/specs/F-0093-claude-autoupdate-fix.md` — new spec
- `docs/BACKLOG.md` — F-0093 marked done in Milestone 18
- `docs/PROGRESS.md` — this entry

### Decisions
- **Write `~/.npmrc` instead of exporting `NPM_CONFIG_PREFIX`**: Claude's auto-updater shells out to `npm install -g` from its own process; `~/.npmrc` is read unconditionally by npm regardless of environment, making it the most robust place for the fix
- **Idempotent edit over clobber**: the fix only adds/replaces the `prefix=` line so any future user-added `.npmrc` entries (registry tokens, proxy, etc.) are preserved
- **No changes to the PATH-level install**: `npm install -g --prefix=/home/user/.npm-global` continues to work; the `.npmrc` fix is purely to cover invocations that don't pass `--prefix` (auto-update, ad-hoc user `npm -g`)

### Next Steps
- SWE-1 commits the branch `fix/claude-autoupdate` and opens a PR (task #3, blocked by this TPM update and the PM RELEASENOTES update)
- PM adds a v1.18 entry to `docs/RELEASENOTES.md` (task #2)
- After merge + PO approval: `git tag -a v1.18` and push tags
