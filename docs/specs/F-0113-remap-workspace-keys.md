# F-0113: Remap Workspace Keybindings After Chrome/Hub Swap

**Type:** Bug / Enhancement
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-05-29

## Problem

F-0112 swapped the boot layout so ws1=Hub and ws5=Chrome (previously ws1=Chrome, ws5=Hub).
The sway keybindings were left pointing at the old workspace numbers:

- `$mod+h` (mnemonic: Hub) → ws5, which is now **Chrome** — wrong semantics
- `$mod+u` → ws1, which is now **Hub** — no mnemonic meaning, orphaned key

The result is that pressing `$mod+h` (the "go to Hub" muscle-memory binding) now opens
the Chrome workspace instead of the Hub workspace. This was explicitly flagged as out-of-scope
in the F-0112 spec with a note that a follow-up spec should fix it.

## Requirements

1. `$mod+h` must switch to workspace 1 (Hub) — the `h` mnemonic aligns with Hub.
2. `$mod+u` must switch to workspace 5 (Chrome) — the orphaned key takes the vacated Chrome slot.
3. `$mod+Alt+h` (move container) must also move to workspace 1 (Hub).
4. `$mod+Alt+u` (move container) must also move to workspace 5 (Chrome).
5. The numeric bindings `$mod+1..5` are NOT changed (they don't exist in this config — it uses
   letter mnemonics only, so this is a no-op requirement, confirmed).
6. The change must be applied to all three canonical locations:
   - `workstation-image/configs/sway/config` (repo source of truth)
   - `~/.config/home-manager/sway-config` (Home Manager source — overwrites live config on boot)
   - `scripts/cloud-build-setup.sh` deploys the repo config via `cat` pipe (no inline edit needed;
     verified that lines 657-658 copy `workstation-image/configs/sway/config` into
     `~/.config/home-manager/sway-config`, and lines 731-732 copy it to `~/.config/sway/config`)
7. Live config must be reloaded: `home-manager switch` regenerates the Nix-store symlink, then
   `swaymsg reload` picks up the new binding.
8. The keybinding cheat sheet `docs/specs/sway-keybindings.md` must be updated to describe the
   correct workspace numbers for H and U.
9. `workstation-image/boot/10-tests.sh` must be updated:
   - The F-0107 test that asserts `$mod+h is workspace 5` must be corrected to assert workspace 1.
   - A new test must assert `$mod+u is workspace 5`.
   - The move-container bindings ($mod+Alt+h and $mod+Alt+u) should be tested.
10. `~/boot/10-tests.sh` must be updated (live copy matches repo).

## Acceptance Criteria

- [x] `bindsym $mod+h workspace number 1` in repo sway config (not 5)
- [x] `bindsym $mod+u workspace number 5` in repo sway config (not 1)
- [x] `bindsym $mod+Alt+h move container to workspace number 1` in repo sway config
- [x] `bindsym $mod+Alt+u move container to workspace number 5` in repo sway config
- [x] Home-manager sway-config matches repo config (identical swap applied)
- [x] `docs/specs/sway-keybindings.md` updated: H → ws1 (Hub), U → ws5 (Chrome)
- [x] `swaymsg reload` returns success (no parse errors) after applying changes
- [x] `10-tests.sh` F-0113 test: `$mod+h` → workspace 1 (not 5)
- [x] `10-tests.sh` F-0113 test: `$mod+u` → workspace 5 (not 1)
- [x] `10-tests.sh` F-0113 test: move-container bindings correct
- [x] `~/boot/10-tests.sh` updated live

## Out of Scope

- Changing any application-launch bindings (they use different keys — `$mod+b` for Chrome etc.)
- Renaming workspace labels (the config uses numeric workspaces with no name strings)
- Changing `$mod+i/o/p/j/k/l` or their Alt+move counterparts
- Any changes to `08-workspaces.sh` (workspace launch order is correct from F-0112)

## Dependencies

- F-0112 (Chrome/Hub workspace swap — root cause of the mismatch)
- F-0107 (original $mod+h keybinding conflict fix — test being updated here)
