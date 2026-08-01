# Infrastructure Tooling Policy

## Tool Ownership Matrix
- HAProxy VM lifecycle: `govc` and/or `Terraform` (active provisioners).
- HAProxy service configuration: `Ansible`.
- Talos VM lifecycle: `Terraform`.
- Talos secrets and machine configuration: `talosctl`.
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
- Treat Terraform as the target provisioner for Talos nodes.
- Keep generated Talos configs outside Terraform state.
- Prefer a template or OVA-based VM creation path that works for both standalone
  ESXi and vCenter.
- Treat image build as a separate concern:
  - if the operator needs a custom image, follow the dedicated Packer module
    instructions
  - otherwise consume an already available OVA/template and provision with
    `govc` or Terraform.
- Keep lab scripts available as reference material only, not as the production source of truth.
