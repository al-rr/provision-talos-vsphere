# Platform Automation Architecture

This document is the concise repository-specific context for contributors and
automation agents. It describes the active operating model for
`provision-talos-vsphere` and deliberately avoids generic framework guidance
that is not backed by real files in this repository.

## Repository Model

- `overlays/base` is the canonical automation layer.
- `overlays/lab` contains lab controller bootstrap assets and local validation
  support.
- `overlays/prod` contains production-specific overrides such as topology values
  and Talos patches.
- Root `.env` files are legacy compatibility only and are not the active
  configuration contract.

The repository is divided like this:

```text
overlays/
  base/
    ansible/
    conf/
    govc/
    scripts/
    terraform/
  lab/
    ansible/
    archive/
    scripts/
    talos/
    README.md
    Vagrantfile
  prod/
    haproxy-lb/
    scripts/
    talos/
```

Use that split to decide ownership:

- `overlays/base` defines reusable shared automation and canonical entrypoints.
- `overlays/lab` defines local validation assets and lab-controller support.
- `overlays/prod` defines production-specific values, topology, and patches.

This repository also has an important transitional role:

- it is currently the integrated working space where reusable modules are tested
  against real scenarios
- over time, reusable scripts and module logic are expected to move into
  `infra-gitops`
- this repository should increasingly retain scenario-specific deployment
  intent, environment values, overlays, topology, patches, and validation data

The canonical variable load order is:

1. `overlays/base/scripts/vars.sh`
2. `overlays/<env>/scripts/vars.sh`

## Source Of Truth

Use the documents in this order when repository behavior is unclear:

1. `agenda.md` for roadmap, active status, and draft-vs-supported positioning
2. `docs/policies/*.md` for repository rules
3. `README.md` for the operator-facing overview
4. this document for concise repo-specific architecture and execution context

## Tool Ownership

- HAProxy VM lifecycle: `govc` + Ansible active; Terraform draft/future-facing
- HAProxy service configuration: `Ansible`
- Talos VM lifecycle: `govc` active (via `cluster.sh provision`); Terraform is
  the target provisioner, not yet wired into the day-1 flow
- Talos secrets and generated machine configuration: `talosctl`
- Generic Talos day-1/day-2 lifecycle: owned by `talos-toolchain`. The
  active path is `cluster-toolchain.sh` / `talos-gitops-toolchain.sh`, which
  forward to the `talos-toolchain` checkout. `cluster.sh` and
  `talos-gitops.sh` under `overlays/base/scripts/talos/` are deprecated
  compatibility shims for that path, kept only for the rollback window.
  `phase-network-bringup.sh`/`phase-cluster-ready.sh` and the standalone
  addon entrypoints built on them (`cilium.sh`, `argocd.sh`, `longhorn.sh`,
  `cert-manager.sh`, `prometheus-stack.sh`) are not toolchain duplicates —
  they provide standalone per-addon lifecycle that `talos-toolchain` does not
- Image build workflow: optional and external (`infra-gitops/packer`)
- Keepalived: role exists under `overlays/base/ansible/roles/keepalived/` but
  is not referenced by the HAProxy playbook yet

The current target topology for the load balancer layer is `2x HAProxy + VIP`.
Do not describe the HAProxy path as fully complete until VIP automation exists.

## Execution Context

- Use Git Bash as the default operator terminal.
- Run `govc` from the Windows host.
- Run Ansible from the Vagrant-based lab controller, not from the default
  Windows host flow.
- Use `overlays/lab/Vagrantfile` to bootstrap the lab controller environment.
- Keep lab assets available for local validation, but do not treat them as the
  production source of truth.

## Canonical Entrypoints

Maintained operator entrypoints live under `overlays/base/scripts/`:

- `haproxy-ansible.sh`
- `haproxy-packer-build.sh`
- `haproxy-terraform.sh`
- `talos-terraform.sh`
- `lint-shell.sh`

`haproxy-packer-build.sh` is a compatibility wrapper that delegates image build
to the external canonical module at `infra-gitops/packer`.

Helper loaders such as `load-ansible-vars.sh`, `load-govc-vars.sh`,
`load-packer-vars.sh`, and `load-terraform-vars.sh` are internal support
scripts, not standalone operator workflows.

## Supported Paths

### HAProxy

- Preferred active path: `govc + Ansible`
- Draft or future-facing path: HAProxy Terraform and Packer automation
- Kubernetes endpoint: `https://<endpoint>:6443`
- Talos API access on `:50000` must be documented separately from the
  Kubernetes endpoint

### Talos

- Current active path: `govc`, driven by
  `overlays/base/scripts/talos/cluster-toolchain.sh` (`provision` action
  calls `provision-cluster.sh`)
- Target provisioner: `Terraform`, not yet invoked by the day-1 flow — do not
  describe it as active
- Keep generated machine configuration outside Terraform state
- Support standalone ESXi first and keep vCenter compatibility explicit when a
  workflow depends on cluster-only constructs
- Generic Talos day-1/day-2 lifecycle behavior belongs to `talos-toolchain`;
  `cluster-toolchain.sh`/`talos-gitops-toolchain.sh` are the active
  delegation path; the local `cluster.sh`/`talos-gitops.sh` copies are
  deprecated shims, not independent implementations

## Relationship To infra-gitops

This repository borrows organizational ideas from shared automation projects
such as `infra-gitops`, but copied generic standards are not maintained here as
source of truth. Only repository-local files and policies define the active
contract for this project.

The intended steady-state split is:

- `infra-gitops` owns reusable scripts, reusable module documentation, and
  shared automation behavior
- this repository owns the deployed-project view: architecture, cluster plans,
  environment overlays, variable values, node counts, patch sets, and lab or
  ESXi validation scenarios

When documenting work, choose the document type accordingly:

- module guide: explains how a reusable module works
- deployment plan: explains how a specific environment or cluster is designed
