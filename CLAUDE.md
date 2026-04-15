# Cloud Workstation — Project Instructions

## Project Overview

Build a Cloud Workstation in GCP Project ID YOUR_PROJECT_ID with Google Antigravity installed (antigravity.google) following the blog at this link https://medium.com/google-cloud/running-antigravity-on-a-browser-tab-6298bb7e47c4. The Cloud Workstation machine should have a GPU and 64GB RAM as well as 500GB SSD drive. The 500GB SSD drive is a persistent disk with HOME folder mounted to it. All apps must be installed inside the peristent disk. The main docker image should be minimal so all changes, app installs persist inside the persistent disk. For OS, I prefer NixOS with Nix package manager. Follow the blog for what to install and ask questions as necessary

## Key References

- [README.md](README.md) — Project overview, tech stack
- [docs/BACKLOG.md](docs/BACKLOG.md) — Feature backlog with priorities, status, dependencies, and feedback (owned by TPM)
- [docs/PROGRESS.md](docs/PROGRESS.md) — Session-by-session development log (update every session)
- [docs/RELEASENOTES.md](docs/RELEASENOTES.md) — Version history (Keep a Changelog format, owned by PM/TPM)
- [docs/PIPELINE.md](docs/PIPELINE.md) — MermaidJS agent workflow diagram
- [docs/specs/](docs/specs/) — Product requirement specs (one per feature, owned by PM)
- [docs/specs/TEMPLATE.md](docs/specs/TEMPLATE.md) — Spec template for PM

## GCP Project

- **Project ID:** `YOUR_PROJECT_ID`
- **Project Number:** `YOUR_PROJECT_NUMBER`
- **Organization:** `your-org.example.com`
- **Region:** `us-west1` (primary — matches existing Cloud Run services)

### Service Accounts

| Account | Email | Role | Purpose |
|---------|-------|------|---------|
| **owner-sa** | `owner-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com` | Owner | Full project admin — used by Platform Engineer for all GCP operations |

### Credentials

- **`owner-sa-key.json`** — Owner SA key. Used for all `gcloud` CLI interactions. **Never use `GOOGLE_APPLICATION_CREDENTIALS`** — always reference the key file directly (e.g., `--key-file=owner-sa-key.json` or load explicitly in code).
- Protected by `.gitignore` pattern `*-sa-key.json`. **Never commit these.**

## Product Owner / CEO

- **Name:** Your Name
- **Role:** Product Owner (PO) and CEO — the human in the loop
- **GitHub:** your-github-username
- **Email:** your-email@example.com
- **Git config:** Always use `git -c user.name="Your Name" -c user.email="your-email@example.com"` for commits so authorship is consistent in history.

## Version Control

- **Commit frequently** — after each meaningful change (new feature, bug fix, refactor, config change). Small, focused commits over large monolithic ones.
- **Write verbose commit messages** — first line is a concise summary (imperative mood, under 72 chars), followed by a blank line and a detailed body explaining *what* changed and *why*. Include context that won't be obvious from the diff.
- **Never commit secrets** — `.gitignore` protects `*-sa-key.json` and `.env`. Verify with `git status` before committing.
- **Review before pushing** — use `git diff --staged` to review staged changes before committing.
- **Keep `main` stable** — use feature branches for non-trivial work, merge back to `main` when ready.
- **Tag milestones** — use annotated git tags for significant releases or milestones.

## Progress Journaling

- **Always update docs/PROGRESS.md** at the end of every session with:
  - Date and session number
  - What was accomplished (with specifics — files changed, features added, bugs fixed)
  - Key decisions made and rationale
  - Next steps / open items
- Commit the docs/PROGRESS.md update as part of the session's final commit

## Team Workflow

This project uses a multi-agent team structure.

### Feedback → Backlog → Execution Pipeline

**This is the mandatory workflow for all user feedback and requests:**

1. **PO (Your Name)** provides feedback, feature requests, or bug reports to the **PM**
2. **PM** translates PO feedback into a product spec in `docs/specs/F-NNNN-slug.md` with detailed requirements and acceptance criteria, then works with the **TPM** to create/update work items in docs/BACKLOG.md with priority, scope, and dependencies
3. **TPM** assigns individual work items to the appropriate **SWE agents** (scaling from 1–3 SWEs as needed) and coordinates parallel execution
4. **SWE agents** implement on feature branches, following the existing codebase conventions
5. **SWE agents** hand off completed work to **SWE-Test** (automated tests) and **SWE-QA** (E2E testing) for end-to-end verification
6. Once coding, functionality, and testing are complete, SWEs update docs/BACKLOG.md marking items as completed, tested, and verified, then inform the **TPM**
7. **TPM** updates docs/PROGRESS.md with session details, waits for all work items in the milestone to be completed, then informs the **PM**
8. **PM** updates docs/RELEASENOTES.md with the new version, creates a summary of all completed work, and reports back to the **PO**
9. **Tag the release** with `git tag -a vX.Y.Z` after PO approval and push tags

**Every piece of feedback goes through this pipeline — no skipping steps.**

**Always use the pipeline for all bug fixes and new features — never ask the PO for confirmation on whether to use the pipeline. Just do it.**

### Agent-Only Execution Rule (Non-Negotiable)

**All project work must be performed by a designated Agent role.** No work is done directly — it is always delegated to the appropriate agent (PM, TPM, SWE-1 through SWE-3, SWE-Test, SWE-QA, Platform Engineer, Reviewer). If a task requires a role or specialization that does not exist in the current team roster, **stop and check with the PO (Your Name)** before proceeding. The PO will decide whether to create a new agent role or reassign the work.

### Interactive Agent Teams via Tmux (Non-Negotiable)

**All agent work MUST use interactive Agent Teams (TeamCreate), NOT subprocess agents.**

Agents must be spawned as interactive teammates in separate tmux panes so the PO can observe and interact with each agent in real time. The correct workflow is:

1. **Create a team** with `TeamCreate` (e.g., `team_name: "feature-xyz"`)
2. **Create tasks** with `TaskCreate` — one per work item, with clear descriptions
3. **Spawn teammates** using the `Agent` tool with `team_name` parameter — this launches each agent in its own tmux pane
4. **Assign tasks** via `TaskUpdate` with `owner` set to the agent name
5. **Coordinate** via `SendMessage` — agents report progress and results back to the team lead
6. **Shutdown gracefully** — send `shutdown_request` to each agent when work is complete
7. **Clean up** with `TeamDelete` after all agents have shut down

**Never use background subprocess agents (Agent tool without `team_name`).** The PO must always be able to see agent activity in tmux panes. Parallel work should be visible, not hidden.



### Mandatory Development Pipeline (Non-Negotiable)

**All PO feedback and feature requests MUST follow this pipeline — no shortcuts, no exceptions:**

1. **PO → PM**: PO provides feedback, feature requests, or bug reports to the PM Agent
2. **PM → Spec**: PM creates a product spec in `docs/specs/F-NNNN-slug.md` (copy from `docs/specs/TEMPLATE.md`) with detailed requirements and acceptance criteria
3. **PM → TPM**: PM works with TPM to create work items in docs/BACKLOG.md with priority, scope, and dependencies (linking to the spec)
4. **TPM → SWE**: TPM assigns individual work items to SWE agents (1–3 SWEs, scaled based on workload). Each SWE picks up their assigned item and implements on a feature branch
5. **SWE → Testing**: After implementation, SWEs hand off to SWE-Test (runs all automated tests — existing tests must pass, new tests added for new functionality) and SWE-QA (E2E testing)
6. **SWE → Backlog Update**: Once coding, functionality, and testing are complete, SWEs update docs/BACKLOG.md marking items as completed, tested, and verified
7. **SWE → TPM**: SWEs inform TPM that their work items are done
8. **TPM → Progress**: TPM updates docs/PROGRESS.md with session details (what was done, decisions, next steps)
9. **TPM → PM**: TPM waits for all work items in the milestone to be completed, then informs PM
10. **PM → Release Notes**: PM updates docs/RELEASENOTES.md with the new version entry (Added, Changed, Fixed sections)
11. **PM → PO**: PM creates a summary of all completed work and reports back to the PO
12. **Tag**: After PO approval, tag the release with `git tag -a vX.Y.Z -m "description"` and push tags
13. **Mandatory updates**: docs/BACKLOG.md, docs/PROGRESS.md, and docs/RELEASENOTES.md MUST be updated every milestone. Git tags MUST be created for every release
14. **No direct code changes**: The orchestrator (main Claude context) MUST NEVER write or edit application code directly. Only SWE agents write code. Only PM/TPM agents update backlog/progress/release docs
15. **No live-only fixes**: ALL changes — including quick fixes, config edits, and "just this one thing" — MUST be committed to the repo AND verified through the setup pipeline (`cloud-build-setup.sh`). A change that works on the live system but isn't in the setup script is NOT done. The definition of done is: teardown + re-setup produces a working workstation with the change applied.
16. **Push before teardown/setup**: Always `git push` to the remote before running `ws.sh setup` so Cloud Build pulls the latest code.

**Violating this pipeline is a process failure.** If time pressure tempts a shortcut, stop and confirm with the PO first.

**Zero tolerance for direct edits.** The orchestrator must NEVER use Edit, Write, or Bash to modify application code, configs, scripts, or any project files directly. Every change goes through an SWE agent via the pipeline. The only files the orchestrator may edit directly are CLAUDE.md (project instructions) and memory files.

### Persistence Across Reboots & Rebuilds (Non-Negotiable)

**Every config change must survive three scenarios: reboot, teardown+setup, and fresh project setup.**

The workstation has TWO config systems that can conflict:
1. **Nix Home Manager** (`~/.config/home-manager/home.nix` + `sway-config`) — runs on every boot via `07-apps.sh` → `home-manager switch`. Creates symlinks to Nix store, **overwriting manual changes**.
2. **Boot scripts** (`~/boot/*.sh`) — run on every boot via `setup.sh`. Deploy configs, install tools.

**Rules for making changes persist:**

1. **Single source of truth**: The repo at `workstation-image/` is the ONLY source of truth for all configs (sway, wofi, swaybar, snippets, boot scripts)
2. **Three places must be updated for every config change**:
   - The **repo config** (e.g., `workstation-image/configs/sway/config`)
   - The **home-manager source** (e.g., `~/.config/home-manager/sway-config`) — must match the repo config exactly, or Home Manager will overwrite with stale version on next boot
   - The **setup script** (`scripts/cloud-build-setup.sh`) — must deploy the config for fresh project setups
3. **Home Manager sway-config MUST match repo sway config**: After any change to `workstation-image/configs/sway/config`, the same change must be applied to `~/.config/home-manager/sway-config` on ALL active workstations
4. **Boot scripts on disk MUST match repo**: After any change to `workstation-image/boot/*.sh`, copy the updated scripts to `~/boot/` on ALL active workstations
5. **Test persistence**: After making changes, verify they survive by running `home-manager switch` and `swaymsg reload` — if the change disappears, it's not persistent
6. **Never edit live-only**: Editing `~/.config/sway/config` directly is useless — it's a symlink to the Nix store managed by Home Manager. Always edit the source at `~/.config/home-manager/sway-config`

### Mandatory Test Coverage (Non-Negotiable)

**Every feature, keybinding, config, and tool MUST have a corresponding test in the boot test script (`workstation-image/boot/10-tests.sh`).**

When adding or changing ANY of the following, you MUST also add or update a test:
- **Keybindings**: Verify the binding exists in the sway config (grep check)
- **App installs**: Verify the binary is on PATH (`which` check)
- **Config files**: Verify the file exists and contains expected content
- **Boot scripts**: Verify the script runs without errors
- **Upgrade scripts**: Verify tools are at expected versions after upgrade

The test script runs on every boot and saves results to:
- `~/logs/boot-test-results.txt` — full PASS/FAIL details
- `~/logs/boot-test-summary.txt` — one-line summary for quick checking

**The definition of done for any feature includes: test added to `10-tests.sh` and passing.**

When adding or modifying any startup/boot script, you MUST also update `docs/STARTUP_SCRIPTS.md` to reflect the change (new script, changed purpose, new logs, etc.).

### Roles
- **PO / CEO** (Your Name) — Product Owner, the human in the loop. Provides feedback, feature requests, and bug reports. Approves direction, tests the app
- **PM** — Receives all PO feedback. Translates it into detailed product requirements with acceptance criteria. Works with TPM to create backlog items. Creates completion summaries and reports back to PO
- **TPM** — Coordinates between agents. Allocates individual work items to SWEs. Tracks blockers and dependencies. Waits for all milestone items to complete before reporting to PM. Maintains docs/PROGRESS.md and docs/BACKLOG.md
- **SWE-1** — General Engineer 1
- **SWE-2** — General Engineer 2
- **SWE-3** — General Engineer 3
- **SWE-Test** — Test coverage and quality assurance. Runs all automated tests after SWE implementation. Ensures existing tests pass and new tests are added for new functionality
- **SWE-QA** — QA and browser testing. Headless Chromium screenshots via puppeteer-core, visual verification, Lighthouse audits, E2E smoke tests. Validates end-to-end functionality
- **Platform Engineer (PE)** — GCP expert (DevOps + SRE). Owns all infrastructure: Cloud Run deployment, Dockerfile, IAM/service accounts, monitoring, billing, free tier quota tracking, troubleshooting via GCP logs, reliability engineering
- **Reviewer** — Code review, quality/security/performance checks

### Backlog Tracking (Non-Negotiable)

**Every piece of work gets a backlog entry in `docs/BACKLOG.md` — no exceptions.**
Regardless of team size, all features, bug fixes, and enhancements must be tracked
in the backlog before implementation begins and updated when completed.

### Other Conventions
- **Branching:** Feature branches (`feature/<name>`) off `main`
- **Platform Engineer (PE) owns all GCP interactions:** Cloud Run deployment, Dockerfile, IAM/service accounts, logging, monitoring, billing, free tier quota tracking, reliability, troubleshooting

## GCP Free Tier (Non-Negotiable)

- **This app must stay within the GCP free tier. Zero additional billing.**
- Single user app — no need for high availability or scale
- Cloud Run config: **256Mi memory, 0.5 vCPU, maxScale=1, minInstances=0, request-based CPU**
- Region: **us-west1** (matches existing services)
- Clean up old Artifact Registry images to stay within 0.5 GB free storage
