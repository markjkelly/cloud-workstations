# F-0091: Align Setup Script with Deployed GCP Organization Configuration

**Type:** Enhancement
**Priority:** P0
**Status:** Done
**Requested by:** PO
**Date:** 2026-04-15

## Problem

The setup script in this repo (`scripts/cloud-build-setup.sh`) was
tailored to the original generic configuration (us-west1, default VPC,
n1-standard-16 + T4 GPU, 500GB pd-ssd). The actual deployment for this
user lives in a separate private infrastructure repo and uses a
different region, cluster, machine type, disk, VPC, service account,
and scheduler.

Running `ws.sh setup` from this repo against the GCP Organization
project produced a parallel, incompatible workstation instead of
matching the already-deployed one. Teardown + re-setup could not
reproduce the live workstation, violating the CLAUDE.md "teardown +
re-setup produces a working workstation with the change applied" rule.

## Requirements

1. `cloud-build-setup.sh` must target the GCP Organization deployment exactly:
   - Region: **us-central1**
   - Cluster: **main-cluster**
   - Config: **sway-config**
   - Workstation: **sway-workstation**
   - Image: **dev-workstation:latest**
   - Machine: **n2-standard-8** (no GPU)
   - Disk: **200GB pd-balanced**
   - Idle timeout: **2h**
   - VPC: custom **workstations-vpc** (10.0.0.0/24)
   - Service account: dedicated **sway-workstation-sa**
   - Scheduler: daily stop at **8PM Central**
2. The README, `docs/SETUP.md`, and `docs/STARTUP_SCRIPTS.md` must
   reflect the new machine spec and note that the GPU-specific boot
   script (`02-nvidia.sh`) is a no-op on this profile.
3. T4 GPU quota must be removed as a prerequisite from the README setup
   instructions.
4. A teardown + re-setup against the GCP Organization project must
   produce a workstation that matches the live deployment byte-for-byte
   on the above dimensions.

## Acceptance Criteria

- [x] `scripts/cloud-build-setup.sh` deploys to the matching
      configuration listed above
- [x] `README.md` documents `n2-standard-8` / 200GB pd-balanced / no GPU
- [x] `docs/SETUP.md` has a top-of-file note clarifying the current
      deployment spec
- [x] `docs/STARTUP_SCRIPTS.md` notes `02-nvidia.sh` is a no-op on this
      profile
- [x] Fresh teardown + setup produces a working workstation matching the
      live deployment

## Out of Scope

- Migrating the private infrastructure repo itself — this spec only
  covers aligning this repo's setup script with what is already
  deployed there
- Reintroducing GPU support — separate future spec if needed

## Dependencies

- F-0034 one-click setup
- F-0088 Cloud Build pipeline (produces `dev-workstation:latest`)

## Open Questions

- None
