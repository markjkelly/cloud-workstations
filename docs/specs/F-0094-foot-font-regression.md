# F-0094: Foot Terminal Font Regression After Reboot

**Type:** Bug
**Priority:** P0 (critical)
**Status:** Draft
**Requested by:** PO
**Date:** 2026-04-15

## Problem

After a workstation reboot, the foot terminal emits:

```
foot: Noto Sans Regular: font does not appear to be monospace; check your config,
or disable this warning by setting [tweak].font-monospace-warn=no
```

This indicates foot is silently falling back to Noto Sans because its configured
monospace font (per commits `0aca479` "deploy Operator Mono only and add Nix font
packages" and `5c714dd` "use DejaVu Sans Mono in foot, remove conflicting Home
Manager foot config") does not resolve at boot. The visual result is a proportional
sans-serif font in the terminal — unusable for code — with a warning banner every
time foot starts.

This is a **persistence failure**: the font resolves on the first provisioning of
the workstation, but after reboot something (Home Manager activation order, font
cache timing, or a stale Home Manager foot config) breaks font resolution.

Prior related work: F-0030 (shell fonts / ZSH) established Operator Mono and the
`dev-fonts/` deploy path. This spec addresses the regression that has resurfaced
on the current workstation.

## Hypothesis

One or more of the following is true on boot:

1. `~/.local/share/fonts/` is populated but `fc-cache` has not run (or ran before
   fonts were copied), so `fc-match "Operator Mono"` / `fc-match "DejaVu Sans Mono"`
   returns a non-monospace fallback.
2. A stale Home Manager `foot` module is re-asserting an old `foot.ini` that
   references a font name that doesn't match any installed family post-boot.
3. The configured font in `workstation-image/configs/foot/foot.ini` (or the
   Home-Manager-rendered equivalent) names a font family/style string that does
   not resolve exactly (e.g. `Operator Mono Book` vs the installed postscript
   name), causing fontconfig to fall through to the default sans family.

Investigation during implementation must identify which of these is the actual
cause before applying a fix.

## Requirements

1. **R1 — Deterministic font resolution at boot.** On a fresh boot, `fc-match`
   for foot's configured monospace font must return that font's file, not Noto
   Sans or any proportional fallback.
2. **R2 — No Noto fallback warning.** Launching foot on a fresh boot must not
   emit the `font does not appear to be monospace` warning. The fix is to make
   the configured font actually resolve — not to silence the warning via
   `[tweak].font-monospace-warn=no`.
3. **R3 — Three-places rule compliance.** The fix must be reflected in:
   - the repo config at `workstation-image/configs/foot/foot.ini` (source of truth),
   - any Home Manager source that renders a foot config (`~/.config/home-manager/home.nix`
     and/or related modules on active workstations) — or the Home Manager foot
     module must be explicitly removed so it cannot overwrite the repo config,
   - `scripts/cloud-build-setup.sh` so fresh project setups deploy the working
     config and font set.
4. **R4 — Font cache rebuild ordering.** Boot must guarantee `fc-cache -fv` runs
   *after* fonts are deployed to `~/.local/share/fonts/`. If this is already
   the case, the fix must document which boot script enforces the ordering.
5. **R5 — Mandatory test coverage.** Add a test to
   `workstation-image/boot/10-tests.sh` that:
   - greps foot's configured primary font family from `~/.config/foot/foot.ini`,
   - runs `fc-match "<family>"` and asserts the returned file is **not** a
     Noto Sans / DejaVu Sans (non-mono) / generic sans file,
   - additionally asserts `fc-match "<family>:spacing=mono"` resolves to the
     expected font family name (regex match on family), failing otherwise.
   The test must write PASS/FAIL to `~/logs/boot-test-results.txt` and the
   one-liner to `~/logs/boot-test-summary.txt`, consistent with existing tests.

## Acceptance Criteria

- [ ] AC1: On a freshly rebooted workstation, launching `foot` produces no
      `font does not appear to be monospace` warning (verified from foot's
      stderr / journal).
- [ ] AC2: `fc-match "<configured-foot-font>"` returns a file under
      `~/.local/share/fonts/` (or Nix store for Nix-packaged fonts) and the
      returned family matches the configured family — no Noto fallback.
- [ ] AC3: The `10-tests.sh` font-resolution test passes on boot and is visible
      in `~/logs/boot-test-summary.txt`.
- [ ] AC4: Persistence verified in all three scenarios:
      (a) `reboot` — foot font remains correct,
      (b) `ws.sh teardown && ws.sh setup` on the same project — foot font correct,
      (c) fresh project setup on a new GCP project disk — foot font correct.
- [ ] AC5: Repo config, Home Manager source (or its removal), and
      `scripts/cloud-build-setup.sh` are all consistent — no drift. Reviewer
      confirms three-places rule compliance.
- [ ] AC6: `docs/STARTUP_SCRIPTS.md` is updated if any boot script's purpose
      or ordering changed as part of the fix.

## Out of Scope

- Changing the chosen monospace font family (Operator Mono vs DejaVu Sans Mono
  vs another). If the investigation concludes the currently-configured font
  cannot be made to resolve reliably, the PM will open a follow-up spec to
  choose a different font — this spec is about making the configured font work.
- Font configuration for GUI apps other than foot (covered by F-0030 and future
  specs as needed).
- Silencing the warning via `[tweak].font-monospace-warn=no` — explicitly
  prohibited; the font must actually resolve.

## Dependencies

- F-0030 (shell fonts / ZSH) — established the `dev-fonts/` deploy path and
  Operator Mono as the primary terminal font.
- Prior commits `0aca479` and `5c714dd` — most recent foot font changes; the
  regression is relative to the intent of those commits.

## Open Questions

- Is the current configured font Operator Mono (per `0aca479`) or DejaVu Sans
  Mono (per `5c714dd`)? The SWE picking this up must verify against the repo's
  current `workstation-image/configs/foot/foot.ini` before debugging.
- Does any Home Manager module still render a `foot.ini` on this workstation?
  `5c714dd` removed a conflicting one, but if it has crept back in (via
  `home.nix` edits on the live workstation that weren't synced to the repo)
  that is a likely root cause.
