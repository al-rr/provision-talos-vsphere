# Cross-Repository Handoff

This document is the durable execution context for a clean host and for automation agents. Treat the three repositories as sibling checkouts in one workspace; do not depend on a fixed absolute path.

## Repository Roles

- `talos-toolchain`: reusable day-1 and day-2 Talos command layer.
- `talos-vsphere-gitops`: GitOps source of truth for platform manifests.
- `talos-vsphere-lab`: integration repository for vSphere/ESXi topology, environment overlays, and validation scenarios.
- `infra-gitops`: owns Packer/image-build automation. Report its defects and improvements as issues in that repository; do not restore Packer code here.

## Clean Host Setup

Choose a workspace and clone the repositories as siblings:

```bash
export WORKSPACE_ROOT="$HOME/platform-workspace"
mkdir -p "$WORKSPACE_ROOT"
cd "$WORKSPACE_ROOT"
git clone git@github.com:al-rr/talos-toolchain.git
git clone git@github.com:ednillibanio/talos-vsphere-gitops.git
git clone git@github.com:al-rr/provision-talos-vsphere.git talos-vsphere-lab
export TALOS_TOOLCHAIN_DIR="$WORKSPACE_ROOT/talos-toolchain"
```

Install the tools required by the selected workflow (`bash`, `git`, `talosctl`, `kubectl`, `govc`, Terraform, and the lab controller dependencies). Use Git Bash on the Windows operator host when following the lab repository policy.

## Configuration and Execution Order

1. In the lab checkout, copy `vars.local.example.sh` to `vars.local.sh` for the selected project (`talos-dev` or `talos-smoke`) and supply host-specific credentials, topology, and endpoints. Never commit this file.
2. Review the tracked `vars.sh`, patches, and schematics; all project-relative paths derive from the project/workspace location.
3. Run the day-1 lifecycle with `cluster-toolchain.sh`, the canonical entrypoint that forwards to `talos-toolchain`'s `cluster.sh`: `generate`, `provision`, `prepare-bootstrap`, `apply-config`, `bootstrap`, and `sync-access`. The local `cluster.sh` in this repository is a deprecated forwarding shim kept only for callers not yet migrated. Generic Talos lifecycle behavior is owned by `talos-toolchain`.
4. Apply the post-bootstrap baseline only after cluster access works. It reads platform manifests from the sibling GitOps checkout.
5. Use Argo CD and the GitOps repository for day-2 application changes.

## Repository Boundary

This repository is the VMware/vSphere infrastructure adapter: `govc`/Terraform
provisioning, HAProxy, and environment topology. Generic, environment-agnostic
Talos lifecycle work belongs to `talos-toolchain`, which already provides a
local Docker/Colima Talos backend (`scripts/talos/local-cluster.sh`); that
backend is a separate local-first path and does not replace this repository's
VMware/vSphere adapter. Real vSphere/ESXi provisioning and VIP validation here
are deferred to the Windows/VMware milestone — do not treat the Terraform
paths for HAProxy or Talos as active until that milestone wires them in.

## Validation and Known Gaps

- Before infrastructure changes, run shell validation (`make lint-sh`) and use each command's dry-run mode where available.
- Generated configuration, kubeconfig, talosconfig, and secrets remain local under `generated/` and must not be staged.
- Generated Talos machine configuration and client-access files written directly
  into a cluster project directory are also local-only. See
  [Credential containment](credential-containment.md) before regenerating or
  rotating access material.
- HAProxy VM lifecycle is `govc + Ansible` (active); Terraform/Packer for
  HAProxy are draft/future-facing until VIP automation is closed.
- Talos VM lifecycle is `govc` (active, via `cluster.sh provision`); Terraform
  is the target provisioner and is not yet wired into the day-1 flow.
- The Keepalived Ansible role exists (`overlays/base/ansible/roles/keepalived/`)
  but is not yet included by the HAProxy playbook — VIP failover is not wired in.
- The supported HAProxy target is two nodes with a VIP. Re-check the current HA/VIP automation status in `agenda.md` before a production rollout.
- The local lab is an integration and validation environment, not the production source of truth. Keep environment values in the appropriate overlay and local override file.

## Continuation Checklist

- Read this document, `agenda.md`, and `docs/devops/platform-automation-architecture.md` first.
- Check all three repositories with `git status --short --branch` before work.
- Create focused PRs against each repository's `main`; merge only after the relevant local and required remote checks succeed.
- Record newly discovered image-build work in `infra-gitops` as an issue.
