# Infrastructure Tooling Policy

## Tool Ownership Matrix
- HAProxy VM lifecycle: `govc` + Ansible is the active path; Terraform is a
  draft/future-facing path until VIP automation is closed.
- HAProxy service configuration: `Ansible`.
- Talos VM lifecycle: `govc` is the active path (via
  `overlays/base/scripts/talos/cluster-toolchain.sh provision`, which calls
  `provision-cluster.sh`); Terraform is the target provisioner and is not yet
  wired into the day-1 flow.
- Talos secrets and machine configuration: `talosctl`.
- Generic Talos day-1/day-2 lifecycle (secrets, machine config, bootstrap,
  GitOps handoff) is owned by `talos-toolchain`. The active path is
  `cluster-toolchain.sh` / `talos-gitops-toolchain.sh`, which forward to the
  `talos-toolchain` checkout. The local `cluster.sh`/`talos-gitops.sh`
  scripts under `overlays/base/scripts/talos/` are deprecated compatibility
  shims for that path, kept only for the rollback window — use
  `cluster-toolchain.sh`/`talos-gitops-toolchain.sh` for all new work.
- Packer image generation is optional and decoupled from day-1 cluster
  provisioning flows.
- Shared tooling lives under `overlays/base/...`; environment overrides live under `overlays/<env>/...`.
- Default operator terminal is Git Bash.
- `govc` runs on the Windows host.
- Ansible runs from the Vagrant-based lab environment, not from the default Windows host flow.

## Environment Targeting
- Local validation must work on standalone ESXi.
- Production may use vCenter, but local-first assumptions must remain documented.
- Any Terraform workflow that requires cluster-only constructs must be labeled accordingly.

## HAProxy Architecture
- Target topology is `2x HAProxy + VIP`.
- The canonical Kubernetes endpoint is `https://<endpoint>:6443`.
- Talos API access requirements on `:50000` must be documented separately from the Kubernetes endpoint.
- Do not advertise the HAProxy overlay as fully production-ready until VIP automation exists.

## Talos Architecture
- Current active path: `govc`-based VM provisioning driven by
  `cluster-toolchain.sh`.
- Treat Terraform as the target provisioner for Talos nodes; it is not yet
  invoked by the day-1 lifecycle and must not be described as active.
- Keep generated Talos configs outside Terraform state.
- Prefer a template or OVA-based VM creation path that works for both standalone
  ESXi and vCenter.
- Treat image build as a separate concern:
  - if the operator needs a custom image, follow the dedicated Packer module
    instructions
  - otherwise consume an already available OVA/template and provision with
    `govc` (active) or Terraform (target, once wired in).
- Keep lab scripts available as reference material only, not as the production source of truth.

## Keepalived / VIP Status
- The Keepalived Ansible role exists at
  `overlays/base/ansible/roles/keepalived/` but is not included by the
  HAProxy playbook (`overlays/base/ansible/requirements.yml` only pulls the
  `haproxy` role). Do not describe VIP failover as wired in until the role is
  referenced from the HAProxy automation.
