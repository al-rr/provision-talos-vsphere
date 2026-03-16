# provision-talos-vsphere

This repository provisions a Talos Linux cluster for vSphere or standalone ESXi
with an overlay-first layout modeled after Kubernetes Kustomize conventions.
`overlays/base` is the canonical automation layer. `overlays/lab` and
`overlays/prod` only carry environment-specific overrides and entry assets.

## Purpose

- Validate the full operating model on local ESXi first.
- Keep the production path aligned with the same base automation.
- Treat HAProxy as `govc + Ansible` now and move Talos VM lifecycle to
  `Terraform`.

## Source Of Truth

- Roadmap: [`agenda.md`](agenda.md)
- Policies: [`docs/policies/`](docs/policies/)
- Shared defaults: [`overlays/base/scripts/vars.sh`](overlays/base/scripts/vars.sh)
- Shared helpers: [`overlays/base/scripts/functions.sh`](overlays/base/scripts/functions.sh)

## Repository Layout

- `overlays/base/conf/`: shared config inputs and reusable templates.
- `overlays/base/scripts/`: canonical shell entrypoints and helper libraries.
- `overlays/base/ansible/`: shared HAProxy Ansible automation.
- `overlays/base/packer/`: shared HAProxy image build inputs.
- `overlays/base/terraform/`: shared Terraform modules for HAProxy and Talos.
- `overlays/base/govc/`: shared GOVC helpers for VM lifecycle tasks, including `provision_haproxy.sh`.
- `overlays/lab/`: lab-only overrides such as `Vagrantfile` and `scripts/vars.sh`.
- `overlays/prod/`: production overrides such as topology vars and Talos patches.

## Variable Model

The canonical load order is:

1. `overlays/base/scripts/vars.sh`
2. `overlays/<env>/scripts/vars.sh`

Use `vars.sh` as the primary configuration interface. Root `.env` files are
legacy-only and must not be treated as the active source of truth.

For production overrides, edit
[`overlays/prod/scripts/vars.sh`](overlays/prod/scripts/vars.sh). For lab
overrides, edit [`overlays/lab/scripts/vars.sh`](overlays/lab/scripts/vars.sh).

## Execution Context

- Default terminal: Git Bash
- `govc` runs on the Windows host
- Ansible runs from the Vagrant-based lab environment
- Lab bootstrap VM: [`overlays/lab/Vagrantfile`](overlays/lab/Vagrantfile)

## Canonical Entry Points

### HAProxy

- Packer validate/build:

```bash
./overlays/base/scripts/haproxy-packer-build.sh --env=prod --validate-only
```

- Terraform plan/apply draft path:

```bash
./overlays/base/scripts/haproxy-terraform.sh --env=prod
./overlays/base/scripts/haproxy-terraform.sh --env=prod --apply
```

- Ansible syntax check and execution:

```bash
./overlays/base/scripts/haproxy-ansible.sh --env=prod --syntax-check
./overlays/base/scripts/haproxy-ansible.sh --env=prod
```

Run the Ansible entrypoint from the Vagrant guest where Ansible is installed.
Do not treat the Windows host as the default Ansible runtime.

### Talos

```bash
./overlays/base/scripts/talos-terraform.sh --env=prod
./overlays/base/scripts/talos-terraform.sh --env=prod --apply
```

Lab validation assets remain under `overlays/lab/`, including
[`overlays/lab/Vagrantfile`](overlays/lab/Vagrantfile).

## Architecture Notes

- HAProxy target topology: `2x HAProxy + VIP`
- Kubernetes endpoint: `https://<endpoint>:6443`
- Talos API administrative reachability: `:50000` when the workflow requires it
- Talos secrets and machine configs remain outside Terraform state and are
  generated with `talosctl`

Keep the Kubernetes endpoint and Talos API connectivity documented separately.

## Validation

- Shell checks:

```bash
make lint-sh
```

- Terraform validation runs from the canonical base tree:

```bash
cd overlays/base/terraform/haproxy-lb && terraform validate
cd overlays/base/terraform/talos && terraform validate
```

## Upstream References

- Talos Production Clusters: <https://docs.siderolabs.com/talos/v1.12/getting-started/prodnotes>
- talosctl endpoints and nodes: <https://docs.siderolabs.com/talos/v1.12/learn-more/talosctl>
- Talos network connectivity and API ports: <https://docs.siderolabs.com/talos/v1.12/learn-more/talos-network-connectivity>
