# Cloud Build Tags & Descriptions

**Date:** 2026-04-01
**Status:** Backlog — implement in next milestone
**Priority:** P2

## Problem
When two Cloud Build jobs run for a setup (outer orchestrator + inner Docker build), they're hard to distinguish in the Cloud Console. The PO needs to see at a glance which build is doing what.

## Proposed Solution

### 1. Tag the outer build in ws.sh
Add `--tags` to the `gcloud builds submit` call in `ws.sh`:
```bash
gcloud builds submit \
    --config="${TMPDIR}/cloudbuild.yaml" \
    --tags="ws-setup,${PROJECT_ID}" \
    ...
```

### 2. Tag the inner Docker build in cloud-build-setup.sh
Add `--tag` (image tag) already exists, but add `--description` or custom tags:
```bash
gcloud builds submit \
    --tag="$IMAGE" \
    --substitutions="_BUILD_TYPE=docker-image" \
    ...
```

### 3. Add descriptions via cloudbuild.yaml
The outer build's cloudbuild.yaml can include:
```yaml
tags:
  - 'ws-setup'
  - '${_PROJECT_ID}'
options:
  logging: CLOUD_LOGGING_ONLY
```

### 4. Name the build steps clearly
In the cloudbuild.yaml, use descriptive `id` fields:
```yaml
steps:
  - name: 'gcr.io/cloud-builders/git'
    id: 'clone-repo'
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'run-full-setup'
```

## What the PO would see in Cloud Console
- **ws-setup / gement03** — the orchestrator build
- **docker-image / gement03** — the Docker image build

Both tagged with the project ID for easy filtering.
