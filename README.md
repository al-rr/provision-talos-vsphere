# provision-talos-vsphere

This repository provisions a Talos Linux cluster for vSphere or standalone ESXi
with an overlay-first automation model. `overlays/base` is the canonical
automation layer. `overlays/lab` and `overlays/prod` carry environment-specific
overrides and bootstrap assets.

## Purpose

- This repository is the VMware/vSphere infrastructure adapter: it provisions
  the VMs and load-balancer layer that Talos and GitOps run on. Real
  provisioning and VIP validation are deferred to the Windows/VMware
  milestone. `talos-toolchain` already provides a local Docker/Colima Talos
  backend (`scripts/talos/local-cluster.sh`); it is a separate local-first
  path and does not replace this repository's VMware/vSphere adapter.
- Validate the operating model on standalone ESXi first.
- Keep the production path aligned with the same base automation.
- Use `govc + Ansible` for the current HAProxy path; Terraform/Packer for
  HAProxy are draft/future-facing until VIP automation is closed.
- Use `govc` (via `cluster.sh provision`) for the current Talos VM lifecycle;
  Terraform is the target provisioner and is not yet wired into the day-1
  flow. Keep `talosctl` outside Terraform state for secrets and generated
  machine configuration either way.
- Generic Talos day-1/day-2 lifecycle is owned by `talos-toolchain`. The
  canonical provisioner entrypoints are `cluster-toolchain.sh` and
  `talos-gitops-toolchain.sh`, which forward to `talos-toolchain`'s
  `cluster.sh` and `talos-gitops.sh`; the local same-name scripts under
  `overlays/base/scripts/talos/` (`cluster.sh`, `talos-gitops.sh`) are
  deprecated forwarding shims kept only for callers not yet migrated.

## Source Of Truth

- Repository roadmap: [`agenda.md`](agenda.md)
- Repository rules: [`docs/policies/`](docs/policies/)
- Repo-specific architecture and operator context:
  [`docs/devops/platform-automation-architecture.md`](docs/devops/platform-automation-architecture.md)
- Cross-repository handoff for a clean host and automation agents:
  [`docs/en/cross-repo-handoff.md`](docs/en/cross-repo-handoff.md)
- Shared defaults: [`overlays/base/scripts/vars.sh`](overlays/base/scripts/vars.sh)
- Shared helpers: [`overlays/base/scripts/functions.sh`](overlays/base/scripts/functions.sh)

## Repository Layout

- `overlays/base/conf/`: shared config inputs and reusable templates.
- `overlays/base/scripts/`: canonical shell entrypoints and helper libraries.
- `overlays/base/ansible/`: shared HAProxy Ansible automation.
- external `infra-gitops/packer`: optional image build module for vSphere/ESXi.
- `overlays/base/terraform/`: shared Terraform for HAProxy and Talos.
- `overlays/base/govc/`: shared GOVC helpers, including HAProxy VM provisioning.
- `overlays/lab/`: lab controller bootstrap assets, lab vars, and validation support.
- `overlays/prod/`: production overrides such as topology values and Talos patches.

## Variable Model

Load variables in this order:

1. `overlays/base/scripts/vars.sh`
2. `overlays/<env>/scripts/vars.sh`

Root `.env` files are legacy compatibility only. They are not the active
configuration contract.

## Execution Context

- Use Git Bash as the default operator terminal.
- Run `govc` from the Windows host.
- Run Ansible from the Vagrant-based lab controller.
- Use [`overlays/lab/Vagrantfile`](overlays/lab/Vagrantfile) to bootstrap the
  lab controller environment.

## Canonical Entry Points

### HAProxy

```bash
./overlays/base/scripts/haproxy-ansible.sh --env=prod --syntax-check
./overlays/base/scripts/haproxy-ansible.sh --env=prod
./overlays/base/scripts/haproxy-terraform.sh --env=prod
./overlays/base/scripts/haproxy-terraform.sh --env=prod --apply
```

If you need to generate a custom base image first, use the dedicated Packer
instructions and then provision via `govc`/Terraform.

Use the Terraform path for HAProxy as a draft or future-facing path until the
VIP automation gap is closed.

### Talos

Current active path (govc, invoked through the day-1 `cluster.sh` lifecycle):

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh provision --project-dir=<project-dir>
```

Target/future path (Terraform, not yet wired into the day-1 flow):

```bash
./overlays/base/scripts/talos-terraform.sh --env=prod
./overlays/base/scripts/talos-terraform.sh --env=prod --apply
```

## Architecture Notes

- HAProxy target topology is `2x HAProxy + VIP`. The Keepalived Ansible role
  exists (`overlays/base/ansible/roles/keepalived/`) but is not yet included
  by the HAProxy playbook — VIP failover is not wired in.
- The Kubernetes endpoint is `https://<endpoint>:6443`.
- `talosctl` version must be compatible with the Talos cluster version (same major/minor; preferably same exact tag).
- Talos API administrative reachability on `:50000` must be documented
  separately from the Kubernetes endpoint.
- Talos secrets and generated machine configuration stay outside Terraform
  state and are managed with `talosctl`.
- Packer is optional and decoupled: provisioning flows should not depend on
  running image builds inline.
- Lab assets are for local validation and controller bootstrap. They are not
  the production source of truth.

## Validation

```bash
make lint-sh
cd overlays/base/terraform/haproxy-lb && terraform validate
cd overlays/base/terraform/talos && terraform validate
```

## Upstream References

- Talos production notes:
  <https://docs.siderolabs.com/talos/v1.12/getting-started/prodnotes>
- talosctl endpoints and nodes:
  <https://docs.siderolabs.com/talos/v1.12/learn-more/talosctl>
- Talos network connectivity:
  <https://docs.siderolabs.com/talos/v1.12/learn-more/talos-network-connectivity>
