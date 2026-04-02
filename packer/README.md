# Packer Module

This directory is the image-building module used by lab and platform workflows.

## Canonical Structure

Canonical path model is distro/version based:

- `packer/packer/oraclelinux/8`
- `packer/packer/ubuntu/24`

Current runtime templates are still under backend-specific folders:

- `packer/vsphere-iso`
- `packer/vmware-iso`

This keeps compatibility while converging to a reusable module contract.

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

Validate Ubuntu 24 in vSphere mode:

```bash
./packer/build.sh --target=vsphere-iso --os=ubuntu --version=24 --action=validate
```

Build Oracle Linux 9 in vSphere mode:

```bash
./packer/build.sh --target=vsphere-iso --os=oraclelinux --version=9 --action=build
```

Validate all local VMware profiles:

```bash
./packer/build.sh --target=vmware-iso --os=all --action=validate
```

Build local Ubuntu 24 profile:

```bash
./packer/build.sh --target=vmware-iso --os=ubuntu --version=24 --action=build
```

## Support Matrix (Current)

- Implemented:
  - `ubuntu/24`
  - `oraclelinux/9`
- Scaffold only:
  - `oraclelinux/8`

## Security Notes

- Never commit secrets in `.env`, `.pkrvars.hcl`, or scripts.
- Keep `packer/env.local.sh` local only.
- Rotate temporary credentials used during image builds.
