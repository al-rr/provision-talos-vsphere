# GOVC Tool Module

## Purpose

This directory is reserved for the `govc` tool itself and for shared VMware
connection profiles used by other modules.

This module is not the owner of Talos, HAProxy, or DNS provisioning flows.
When a provisioning workflow belongs to a specific module, the entrypoint should
live inside that module, for example:

- `overlays/base/scripts/talos/govc/`
- `overlays/base/scripts/ha-proxy/govc/`

## Files

| File | Purpose |
| --- | --- |
| `install.sh` | Install `govc` in an idempotent way |
| `vars.sh` | Shared default variables for `govc` automation |
| `vars-esxi-prod.sh` | ESXi-focused variable profile used by VMware-backed modules |

## What Belongs Here

Keep only `govc`-specific assets in this module:

- `govc` installation
- VMware connection defaults
- shared `govc` variable profiles

Do not keep workload-owned provisioning entrypoints here. Those should stay with
the owning module so the module remains cohesive.

## Install GOVC

```bash
./overlays/base/scripts/govc/install.sh
```

Optional version pin:

```bash
./overlays/base/scripts/govc/install.sh --version=v0.52.0
```

## Variable Profiles

These files are commonly used by VMware-backed modules:

- `overlays/base/scripts/govc/vars.sh`
- `overlays/base/scripts/govc/vars-esxi-prod.sh`

Typical usage:

```bash
./overlays/base/scripts/ha-proxy/govc/provision.sh \
  --env=lab \
  --vars-file=overlays/base/scripts/govc/vars-esxi-prod.sh \
  create
```

```bash
./overlays/base/scripts/dns/provision.sh \
  --env=lab \
  --vars-file=overlays/base/scripts/govc/vars-esxi-prod.sh \
  create
```

## Module-Specific VMware Provisioning

Use the provisioning entrypoint that belongs to the workload module:

- [Talos VMware provisioning](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/govc/README.md)
- [HAProxy VMware provisioning](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/govc/README.md)
- [DNS module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/dns/README.md)
