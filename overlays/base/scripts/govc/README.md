# GOVC Tool Module

## Purpose

This directory stores shared GOVC defaults used by other modules.
The reusable `govc` installer module lives in `infra-gitops/scripts/govc/`.

This module is not the owner of Talos, HAProxy, or DNS provisioning flows.
When a provisioning workflow belongs to a specific module, the entrypoint should
live inside that module, for example:

- `overlays/base/scripts/talos/govc/`
- `overlays/base/scripts/ha-proxy/govc/`

## Files

| File | Purpose |
| --- | --- |
| `vars.sh` | Shared default variables for `govc` automation |

## What Belongs Here

Keep only GOVC-specific shared defaults in this module:

- generic `govc` automation defaults (`vars.sh`)

Do not keep workload-owned provisioning entrypoints here. Those should stay with
the owning module so the module remains cohesive.

## Install GOVC (Reusable Module)

```bash
cd /home/vagrant/infra-gitops
./scripts/govc/install.sh
```

Optional version pin:

```bash
./scripts/govc/install.sh --version=v0.52.0
```

## Variable Profiles

Variable sources used by VMware-backed modules:

- `overlays/base/scripts/govc/vars.sh` (generic defaults)
- `overlays/<env>/scripts/vars.sh` (environment source of truth)

Identity model used by automation:

- `BUILD_*`: account/key context used during image build/bootstrap
- `ANSIBLE_*`: remote automation identity (SSH user/key for post-build operations)
- `GOVC_VM_GUEST_*`: govc in-guest execution identity; defaults from `BUILD_*` unless explicitly overridden

Typical usage:

```bash
./overlays/base/scripts/ha-proxy/govc/provision.sh \
  --env=lab \
  --vars-file=overlays/lab/scripts/vars.sh \
  create
```

```bash
./overlays/base/scripts/dns/provision.sh \
  --env=lab \
  --vars-file=overlays/lab/scripts/vars.sh \
  create
```

## Module-Specific VMware Provisioning

Use the provisioning entrypoint that belongs to the workload module:

- [Talos VMware provisioning](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/govc/README.md)
- [HAProxy VMware provisioning](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/govc/README.md)
- `infra-gitops/scripts/dnsmasq/README.md`
