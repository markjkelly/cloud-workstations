# Build Speed Optimization — Research Notes

**Date:** 2026-04-01
**Current build time:** ~40 minutes
**Goal:** Reduce to <10 minutes for config-only changes, <25 minutes for full rebuilds

## Current Breakdown (~40 min)

| Phase | Time | What |
|-------|------|------|
| Docker image build | ~17 min | apt packages, GNOME desktop, Antigravity |
| Cluster creation | ~10 min | GCP infrastructure (hard limit) |
| Config + workstation | ~5 min | GCP provisioning |
| First boot (Nix + apps) | ~8 min | home-manager, npm tools, languages |

## High Impact

### 1. Don't delete Artifact Registry on teardown (saves ~17 min)
Skip AR deletion in `ws.sh teardown`. Next setup detects existing image and skips Docker build. Image is ~280MB, pennies/month storage cost. Simplest change — one line.

### 2. Shared image in a central project
Build Docker image once in gement01, reference from gement02/03. Teardown of other projects doesn't touch the image. Only rebuild when Dockerfile changes.

### 3. Skip cluster if exists (saves ~10 min)
For re-setups without full teardown, check if cluster already exists and reuse it. Only create if missing.

### 4. Faster Cloud Build machine (saves ~8 min)
Use `machineType: E2_HIGHCPU_32` in build config. Docker builds go 2-3x faster.

### 5. Pre-populate Nix in Docker image (saves ~5 min)
Install Nix and run `home-manager switch` during Docker build so Nix store is baked into the image. First boot only restores bind mount, no downloads.

## Medium Impact

### 6. Incremental update command (`ws.sh update`)
New command that only pushes configs + runs boot scripts on an existing workstation. No teardown/rebuild. For config-only changes: ~2 min instead of 40.

### 7. Nix binary cache (Cachix)
Push built Nix derivations to a cache so subsequent builds don't recompile. Helps when Nix packages update.

### 8. Parallel boot scripts (saves ~2-3 min)
Run independent boot scripts concurrently (fonts + shell + prompt can run in parallel).

## Low Effort / Nice to Have

### 9. GCS-hosted boot assets
Pre-upload fonts and large assets to GCS instead of cloning from git during build.

### 10. Cloud Build trigger
Set up a trigger on git push so builds happen automatically.

## Recommendation

Start with **#1 (keep AR on teardown)** + **#6 (ws.sh update command)**:
- Config/code changes -> `ws.sh update` (2 min)
- Full rebuild needed -> reuses cached image if Dockerfile unchanged (23 min)
- Dockerfile changes -> full rebuild (40 min, same as today)

## Considerations for Multi-Project Setup

The PO uses 3 projects (gement01/02/03) with identical workstations. Teardown deletes AR, destroying the cached image. Options:
- **Option A:** Don't delete AR on teardown (recommended — simplest)
- **Option B:** Shared image in central project (gement01 hosts, others pull)
- **Option C:** Public registry (Docker Hub / GHCR) — decoupled from project lifecycle
