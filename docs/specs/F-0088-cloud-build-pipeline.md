# F-0088: Cloud Build Pipeline for Workstation Image

**Type:** Feature
**Priority:** P1
**Status:** Done
**Requested by:** PO
**Date:** 2026-04-13

## Problem

Building and pushing the workstation Docker image by hand (`docker build` +
`docker push` to Artifact Registry) is slow on low-bandwidth links and
requires a local Docker daemon with GCP auth configured. This blocks
contributors who just want to iterate on the image from a Cloud
Workstation or a laptop without Docker.

It also means the image build is not reproducible in CI — there is no
single command that takes a commit on `main` and produces a published
image.

## Requirements

1. The system must build `workstation-image/` via Cloud Build and push the
   resulting image to Artifact Registry.
2. The Artifact Registry project must be configurable via a substitution
   (`_AR_PROJECT`) so the AR project can differ from the build project.
3. The build must be triggerable by `ws.sh setup` so the setup flow picks
   up the latest code from `main` without a local Docker daemon.
4. The Cloud Build service account must have the IAM roles required to
   push to Artifact Registry and write Cloud Logging entries.

## Acceptance Criteria

- [x] `cloudbuild/ws-image.yaml` exists and builds the image successfully
- [x] `_AR_PROJECT` substitution works when AR and build projects differ
- [x] `ws.sh setup` invokes the pipeline and waits for success
- [x] Fresh project setup (teardown → setup) produces a working image
      without any manual Docker commands

## Out of Scope

- Multi-arch (arm64) builds — current target is amd64 only
- Image signing / attestation
- Caching beyond Cloud Build's default layer cache

## Dependencies

- F-0034 one-click setup (`ws.sh`)

## Open Questions

- None
