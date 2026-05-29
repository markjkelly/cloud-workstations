# F-0090: VNC Keyboard Compatibility (wayvnc + noVNC + foot)

**Type:** Bug
**Priority:** P1
**Status:** Done
**Requested by:** PO
**Date:** 2026-04-13

## Problem

Browser-based desktop access via noVNC → wayvnc had multiple keyboard
issues that broke common developer workflows:

1. **Wrong key encoding** — wayvnc did not know the client keyboard
   layout, so symbols and modifier combinations were mistranslated
2. **QEMU extended key events** — noVNC's `rfb.js` sends QEMU-extended
   key events by default; wayvnc handles them incorrectly, producing
   duplicate or swallowed keypresses for special keys (arrows, Home/End,
   function keys)
3. **Foot terminal on VNC** — without `term=xterm-256color`, foot
   advertised a `$TERM` value that confused line editors (readline, zsh
   vi mode) when keystrokes arrived via VNC

## Requirements

1. `wayvnc` must be launched with `--keyboard=us` so key codes are
   encoded for the expected client layout.
2. On every boot, `noVNC`'s `rfb.js` must be patched to disable QEMU
   extended key events.
3. `foot.ini` must set `term=xterm-256color`.
4. Boot tests must verify each of these conditions holds after boot.

## Acceptance Criteria

- [x] Typing symbols, arrow keys, and function keys in foot over noVNC
      produces the expected characters / escape sequences
- [x] Readline and zsh vi-mode editing work correctly over noVNC
- [x] Boot tests cover the `--keyboard=us` flag, the patched `rfb.js`,
      and the `term=xterm-256color` setting

## Out of Scope

- Non-US keyboard layouts — tracked separately if a user requests one
- Replacing noVNC or wayvnc with a different stack

## Dependencies

- F-0001 cloud-workstation (VNC stack)

## Open Questions

- None
