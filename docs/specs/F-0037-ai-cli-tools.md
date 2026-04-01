# F-0037: Add OpenCode and Codex CLI Tools

**Type:** Enhancement
**Priority:** P2 (nice to have)
**Status:** Approved
**Requested by:** PO
**Date:** 2026-03-31

## Problem

The workstation currently ships Claude Code and Gemini CLI as AI coding assistants, but is missing two other popular tools: OpenAI's Codex CLI and OpenCode. Adding these gives the PO a complete set of AI coding assistants available on every boot.

## Requirements

1. **Codex CLI** (`@openai/codex`) must be installed globally via npm, following the same pattern as Claude Code and Gemini CLI
2. **OpenCode** (`github.com/opencode-ai/opencode@latest`) must be installed via `go install`, placing the binary in `$GOPATH/bin` on the persistent disk
3. Both tools must be installed on first boot (setup script)
4. Both tools must be upgraded to latest on every subsequent boot (07-apps.sh)
5. Both tools' binaries must be on `$PATH` so they are immediately usable from the terminal

## Acceptance Criteria

- [ ] `codex --version` works after first boot
- [ ] `opencode --version` works after first boot
- [ ] 07-apps.sh upgrades both tools to latest on every boot
- [ ] Codex is added to the npm global update line alongside Claude Code and Gemini CLI
- [ ] OpenCode go install runs with correct `GOPATH` pointing to persistent disk
- [ ] No regressions to existing Claude Code or Gemini CLI installs

## Out of Scope

- API key configuration for either tool (user manages their own keys)
- Shell completions or aliases
- IDE integration

## Dependencies

- F-0001: Language support (Go must be available for `go install`)

## Open Questions

- None
