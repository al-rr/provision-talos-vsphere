# Codex Context

Operational context for Codex CLI sessions in this workspace.

## Repository Roles

- `talos-vsphere-lab`:
  - Day-1 toolchain and cluster lifecycle automation.
  - Main entrypoints:
    - `overlays/base/scripts/talos/cluster.sh`
    - `overlays/base/scripts/talos/talos-gitops.sh`
- `talos-vsphere-gitops`:
  - Day-2 GitOps manifests (helm + argocd) per environment.
  - Current active layout: `environments/lab/...`
- `infra-gitops`:
  - Reusable automation modules shared across projects.

## Current Lifecycle Split

- Day-1 (`cluster.sh`):
  - `create-project`
  - `generate`
  - `provision`
  - `prepare-bootstrap`
  - `bootstrap`
  - `apply-config`
  - `sync-access`
  - `apply-post-bootstrap`
- Day-2 (`talos-gitops.sh`):
  - `install-platform-helm`
  - `install-addon`
  - `deploy-argocd-root-app`
  - `configure-talos-cluster-tools`

## Operational Rules

- Keep changes scoped by block and commit by block.
- Do not mix day-1 and day-2 changes in the same commit.
- `talos-gitops.sh` requires `--kube-context` for safety.
- `cilium` is system-excluded from broad day-2 helm installs.
- Push commands are executed from host machine (outside guest VM).

## Session Startup Checklist

1. Check `git status --short --branch` in all three repositories.
2. Read `.codex/current-work.md` and `.codex/decisions.md`.
3. Confirm one session goal and one technical block.
