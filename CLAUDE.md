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

This project uses a single sequential pipeline agent (Sonnet 4.6) for all implementation work.

### Feedback → Pipeline → Release

**This is the mandatory workflow for all user feedback and requests:**

1. **PO** provides feedback, feature requests, or bug reports to the orchestrator
2. **Orchestrator** spawns a single pipeline agent (`model: "sonnet"`) with full pipeline instructions
3. **Pipeline agent** executes all steps sequentially: spec → backlog → implement → test → QA → backlog update → progress → release notes → PR
4. **Orchestrator** relays the agent's summary (PR URL, version, what changed) to the PO
5. **PO approves** → orchestrator (or pipeline agent) merges PR, creates git tag, pushes

**Every piece of feedback goes through this pipeline — no skipping steps.**

**Always use the pipeline for all bug fixes and new features — never ask the PO for confirmation on whether to use the pipeline. Just do it.**

### Agent-Only Execution Rule (Non-Negotiable)

**All project work must be performed by a pipeline agent.** The orchestrator (main Claude context) never writes application code or project docs directly — it always delegates to a single pipeline agent. The only files the orchestrator may edit directly are `CLAUDE.md` (project instructions) and memory files.

### Single Sequential Pipeline Agent

**All pipeline work is executed by one agent using `model: "sonnet"` (Sonnet 4.6).** This agent plays all roles in sequence — PM, TPM, SWE, SWE-Test, SWE-QA — within a single run, eliminating inter-agent coordination overhead.

**How to spawn the pipeline agent:**

```
Agent(
  description: "Pipeline: <feature slug>",
  model: "sonnet",
  prompt: "<full pipeline instructions — see Mandatory Development Pipeline below>"
)
```

The agent runs in the background (no TeamCreate, no tmux panes). The orchestrator waits for the agent to complete and return a summary, then relays the result to the PO.

### Mandatory Development Pipeline (Non-Negotiable)

**All PO feedback and feature requests MUST follow this pipeline — no shortcuts, no exceptions.**

The pipeline agent executes all steps sequentially in a single run:

1. **Spec**: Create a product spec in `docs/specs/F-NNNN-slug.md` (copy from `docs/specs/TEMPLATE.md`) with requirements and acceptance criteria. Use the next available F-number from `docs/BACKLOG.md`.
2. **Backlog**: Add a work item to `docs/BACKLOG.md` referencing the spec, marked In Progress.
3. **Implement**: Create a feature branch `feature/<slug>`, make all code/config changes.
4. **Test**: Add or update tests in `workstation-image/boot/10-tests.sh` to cover the change.
5. **QA**: Read and verify the implementation is correct; confirm all affected files are updated.
6. **Backlog update**: Mark the backlog item as completed, tested, and verified.
7. **Progress**: Update `docs/PROGRESS.md` with session number, date, what was done, decisions, and next steps.
8. **Release notes**: Add a new patch/minor version entry to `docs/RELEASENOTES.md`.
9. **Commit & PR**: Commit all changes on the feature branch (verbose message, no Co-Authored-By trailers), push, open a PR against `main`.
10. **Report**: Return a concise summary to the orchestrator: what changed, PR URL, version number.

After PO approval the orchestrator (or pipeline agent if re-invoked) merges the PR, tags the release (`git tag -a vX.Y.Z`), and pushes the tag.

**Mandatory updates every milestone:** docs/BACKLOG.md, docs/PROGRESS.md, docs/RELEASENOTES.md. Git tags MUST be created for every release.

**No live-only fixes:** ALL changes — including quick fixes, config edits, and "just this one thing" — MUST be committed to the repo AND verified through the setup pipeline (`cloud-build-setup.sh`). A change that works on the live system but isn't in the setup script is NOT done.

**Push before teardown/setup:** Always `git push` before running `ws.sh setup` so Cloud Build pulls the latest code.

**Violating this pipeline is a process failure.** If time pressure tempts a shortcut, stop and confirm with the PO first.

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
- **PO / CEO** (Your Name) — Product Owner, the human in the loop. Provides feedback, feature requests, and bug reports. Approves direction, tests the app.
- **Pipeline Agent** (Sonnet 4.6) — Single agent that plays all implementation roles sequentially: PM (spec), TPM (backlog/progress/release notes), SWE (code), SWE-Test (tests), SWE-QA (verification). Spawned by the orchestrator with `model: "sonnet"`.
- **Platform Engineer (PE)** — GCP expert (DevOps + SRE). Owns all infrastructure: Cloud Run deployment, Dockerfile, IAM/service accounts, monitoring, billing, free tier quota tracking, troubleshooting via GCP logs, reliability engineering. Spawned as a pipeline agent with `model: "sonnet"` when GCP work is needed.

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
