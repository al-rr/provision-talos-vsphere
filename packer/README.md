# Packer Module

This directory is the image-building module used by lab and platform workflows.

## Canonical Entrypoint

Use a single dispatcher:

```bash
./packer/build.sh
```

Supported targets:
- `vsphere-iso`: build directly on ESXi/vSphere.
- `vmware-iso`: local VMware-based builds.

## Prerequisites

1. `packer` or `packerio` in `PATH`.
2. `govc` in `PATH` for vSphere inventory checks.
3. Network access to ESXi/vSphere when using `vsphere-iso`.

## Environment Setup

Optional local overrides:

```bash
cp packer/env.local.example packer/env.local.sh
```

Load overlay vars into the shell:

```bash
OVERLAY_ENV=lab source ./packer/env.sh
```

This exports:
- `GOVC_*` for `govc`
- `PKR_VAR_*` for Packer

## Examples

Validate Ubuntu profile in vSphere mode:

```bash
./packer/build.sh --target=vsphere-iso --profile=ubuntu-24 --env=lab --action=validate
```

Build Oracle Linux profile in vSphere mode:

```bash
./packer/build.sh --target=vsphere-iso --profile=oraclelinux-9 --env=lab --action=build
```

Validate all local VMware profiles:

```bash
./packer/build.sh --target=vmware-iso --os=all --action=validate
```

Build only local Ubuntu profile:

```bash
./packer/build.sh --target=vmware-iso --os=ubuntu --action=build
```

## Security Notes

- Never commit secrets in `.env`, `.pkrvars.hcl`, or scripts.
- Keep `packer/env.local.sh` local only.
- Rotate temporary credentials used during image builds.
