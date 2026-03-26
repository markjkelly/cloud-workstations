# /roadmap — Add items to the backlog as future work

## Trigger

User invokes `/roadmap` with a feature idea or description.

## Instructions

1. **Read the backlog** — Read `docs/BACKLOG.md` and scan all sections (Current Milestone, Future Items, etc.) for the highest existing `F-NNNN` ID
2. **Compute the next ID** — The next item gets the next sequential number, zero-padded to 4 digits (e.g., if the highest is F-0051, the next is F-0052)
3. **Prompt the user** for:
   - **Feature name** — short title for the roadmap item (required)
   - **Priority** — P0 (critical), P1 (important), or P2 (nice to have). Default: P2
   - **Description / Notes** — brief notes about the feature (optional)
4. **Append a new row** to the "Future Items" table in `docs/BACKLOG.md` with:
   - The computed `F-NNNN` ID
   - Feature name as the title
   - Priority (P0/P1/P2)
   - Status: `TODO`
   - Dependencies: `—` (none by default)
   - Notes: the description provided by the user (or `—` if none)
5. **Commit the change** — Stage and commit `docs/BACKLOG.md` with the message:
   ```
   Add F-NNNN to backlog: <feature name>
   ```
6. **Report back** — Confirm the assigned ID and summarize what was added

## Project Context

- **Project:** Cloud Workstation
- **Owner:** Your Name (your-email@example.com)
- **Backlog:** `docs/BACKLOG.md`
