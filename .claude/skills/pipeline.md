# /pipeline — Spin up the full agent team

## Trigger

User invokes `/pipeline` with a feature description or milestone name.

## Instructions

1. **Create a team** — Use `TeamCreate` with a descriptive team name based on the feature (e.g., `feature-dark-mode`)
2. **Create tasks** — Use `TaskCreate` to create work items for the pipeline:
   - **Task 1:** PM — Define requirements and create spec in `docs/specs/`
   - **Task 2:** TPM — Create backlog items and coordinate SWE assignments
   - **Task 3+:** SWE — Implement the feature (one task per work item)
   - **Task N:** SWE-Test — Run tests and verify acceptance criteria
   - **Task N+1:** Reviewer — Code review
3. **Spawn agents** — Use the `Agent` tool with `team_name` parameter to launch each agent in its own tmux pane. Always use model `claude-opus-4-6` for all agents:
   - PM agent (reads `.claude/agents/pm.md`)
   - TPM agent (reads `.claude/agents/tpm.md`)
   - SWE-1 agent (reads `.claude/agents/swe-1.md`)
   - SWE-2 agent (reads `.claude/agents/swe-2.md`)
   - SWE-3 agent (reads `.claude/agents/swe-3.md`)
   - SWE-Test agent (if included)
4. **Assign tasks** — Use `TaskUpdate` with `owner` set to each agent's name
5. **Follow the mandatory pipeline:**
   - PO feedback → PM creates spec → TPM creates backlog → SWEs implement → SWE-Test verifies → Reviewer approves
   - docs/BACKLOG.md, docs/PROGRESS.md, and docs/RELEASENOTES.md MUST be updated
6. **Monitor and coordinate** — Use `SendMessage` to communicate with agents and track progress
7. **Shutdown gracefully** — Send `shutdown_request` to each agent when all work is complete
8. **Clean up** — Use `TeamDelete` after all agents have shut down

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Your Name (your-email@example.com)
- **Framework:** Claude Code Agent Teams
- **Model:** `claude-opus-4-6`
- **Agent definitions:** `.claude/agents/`
- **Pipeline diagram:** `docs/PIPELINE.md`
