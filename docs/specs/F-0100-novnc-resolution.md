# F-0100: noVNC Resolution & Clarity (1080p + 1440p)

**Type:** Feature
**Priority:** P1 (important)
**Status:** Done
**Requested by:** PO
**Date:** 2026-04-15

## Problem

The noVNC desktop session opens with default settings that produce blurry or
incorrectly scaled output. Three root causes:

1. **No runtime resolution control** — the Sway HEADLESS-1 output runs at a
   default resolution that may not match the PO's display. Changing resolution
   requires knowing `swaymsg` syntax, and the change is lost on reboot.
2. **wayvnc quality too low** — wayvnc defaults to JPEG quality that's fine for
   low-bandwidth but causes visible artefacts on a LAN/Cloud connection where
   bandwidth isn't a bottleneck.
3. **noVNC browser defaults** — the browser client opens with quality=6 and no
   scaling mode, requiring manual Options tuning every session.

Target: 1:1 pixel-sharp rendering at 1920×1080 on FHD displays, and crisp
output at 2560×1440 on QHD displays, with zero manual tuning required.

## Requirements

1. The system must provide a `ws-resolution` helper script on PATH that accepts
   `WxH` (e.g. `ws-resolution 1920x1080`) and applies it immediately to Sway's
   HEADLESS-1 output.
2. The chosen resolution must persist to `~/.config/ws-resolution` and be
   automatically restored on the next boot after Sway starts.
3. The system must deploy `~/.config/wayvnc/config` with `quality=9` for
   maximum JPEG fidelity in wayvnc's tight encoding.
4. The noVNC browser client must open with JPEG quality=9 and remote-resize
   scaling mode enabled by default, without requiring any manual Options changes.
5. All three components must be covered by boot test assertions in `10-tests.sh`.
6. The setup script (`cloud-build-setup.sh`) must deploy `ws-resolution` and the
   wayvnc config on fresh project setup (three-places rule).

## Acceptance Criteria

- [x] AC1: `ws-resolution 1920x1080` changes sway output and persists resolution
      to `~/.config/ws-resolution`
- [x] AC2: On boot, persisted resolution is restored automatically after Sway
      reports ready
- [x] AC3: wayvnc config deployed at `~/.config/wayvnc/config` with `quality=9`
- [x] AC4: noVNC opens with remote-resize mode and quality=9 by default (no
      manual Options tuning required)
- [x] AC5: `10-tests.sh` assertions pass — ws-resolution on PATH, wayvnc config
      present, quality setting verified

## Out of Scope

- Persistent resolution changes that also update the container image (ephemeral
  root disk is discarded on teardown; only `~/.config` persists)
- wayvnc config options beyond quality (subsampling, encryption, etc.) — those
  are deferred until wayvnc exposes stable config-file support for them
- noVNC server-side configuration (only client-side `ui.js` defaults are patched)

## Dependencies

- F-0016 (Sway compositor baseline)
- F-0090 (noVNC base deployment)

## Open Questions

- wayvnc's config file format is only partially documented; `quality=` is the
  only confirmed option. Additional options (subsampling, etc.) may be added in
  a future wayvnc release. The config is deployed regardless — unknown options
  are ignored by older wayvnc versions.
