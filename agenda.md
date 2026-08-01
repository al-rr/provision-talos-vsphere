# Project Agenda

## Purpose

- Build a production-ready Talos Linux cluster for vSphere or standalone ESXi.
- Validate the architecture locally first, then promote the same operating
  model to production.
- Keep the repository explicit about what is active, what is draft, and what is
  planned next.
- Keep the cross-repository continuation guide current in
  `docs/en/cross-repo-handoff.md` and `docs/pt-br/cross-repo-handoff.md`.

## Overlay Model

- `overlays/base` is the only canonical source of reusable automation.
- `overlays/lab` and `overlays/prod` contain environment-specific overrides and
  entry assets.
- The canonical variable precedence is:
  1. `overlays/base/scripts/vars.sh`
  2. `overlays/<env>/scripts/vars.sh`
- Root `.env` support is legacy-only and must not be treated as the active
  configuration contract.

## Phase 0 - Repository Hygiene

- Keep shared tooling under `overlays/base/...`.
- Remove or rewrite docs that describe root-level `packer/`, `ansible/`, or
  root-first env loading as canonical.
- Mark generated outputs as generated and keep them out of version control.
- Normalize mixed-language notes to English when touched.

## Phase 1 - HAProxy On Standalone ESXi

- Treat HAProxy VM lifecycle as `govc + Ansible`.
- Validate the local ESXi-first workflow with two load balancer VMs and a
  planned VIP.
- Keep the Kubernetes endpoint documented as `https://<endpoint>:6443`.
- Document Talos API reachability requirements separately from the Kubernetes
  endpoint.
- Keep current Packer and Terraform assets for HAProxy as secondary or future
  paths until they explicitly support the local-first flow.

## Phase 2 - HA Load Balancer Completion

- Add Keepalived or equivalent VIP management to the Ansible automation.
- Remove the gap between the selected `2x HAProxy + VIP` topology and the
  current HAProxy-only role.
- Define health checks, failover expectations, and validation commands for the
  VIP.
- Promote the HAProxy overlay from functional draft to supported path only
  after VIP automation exists.

## Phase 3 - Talos Provisioning In Terraform

- Make Terraform the target provisioner for Talos VMs.
- Keep `talosctl` outside Terraform state for secrets and machine configuration
  generation.
- Inject generated Talos machine configs into VMs through guest metadata.
- Support both standalone ESXi and vCenter by treating `cluster`, `host`, and
  `resource_pool` as conditional inputs.
- Keep production overlays separate from the lab bootstrap scripts.

## Phase 4 - HAProxy Image Lifecycle

- Promote HAProxy guest creation from ad-hoc provisioning to a reusable image
  or template with Packer.
- Reuse the same base variable model already used by the rest of the
  repository.
- Keep Ansible focused on in-guest HAProxy and VIP configuration rather than
  first-boot image assembly.

## Phase 5 - Production Readiness

- Define acceptance checks for local validation, promotion, and production
  rollout.
- Document rollback expectations and draft-handling rules.
- Review hardening gaps across Terraform, Ansible, and Talos configuration
  inputs.
- Ensure README and policy documents are sufficient for a clean rebuild from
  scratch.

## Blocking Gaps

- The repository still contains draft scripts and examples that are not
  production entrypoints.
- Current HAProxy automation does not yet implement the VIP layer.
- Current HAProxy Terraform remains a draft path and must not replace the
  standalone ESXi-first workflow by default.
- Talos production rollout still depends on environment-specific generated
  machine configs outside Terraform state.

## Definition Of Done

- Active documentation points to real files and current execution paths.
- Policy documents exist and are linked from the repository root.
- Generated outputs are ignored by Git and no longer treated as source of
  truth.
- Base automation and environment overlays are documented without ambiguity.
- The next engineer can identify the supported path, the draft path, and the
  next milestone without reverse-engineering the repo.
