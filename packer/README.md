# Packer Module

This directory is the image-building module used by lab and platform workflows.

## Canonical Builder

Current canonical builder in this repository:

- `packer/vsphere-iso`

`vmware-iso` was removed from this repository to keep the module focused on the
active vSphere/ESXi flow.

## Canonical Entrypoint

Use a single dispatcher:

```bash
./packer/build.sh
```

Default builder is `vsphere-iso`. You can still set it explicitly with
`--builder=vsphere-iso`.

## Prerequisites

1. `packer` or `packerio` in `PATH`.
2. `govc` in `PATH` for vSphere inventory checks.
3. Network access to ESXi/vSphere.

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

Validate Ubuntu 24:

```bash
./packer/build.sh --builder=vsphere-iso --os=ubuntu --version=24 --action=validate
```

Build Oracle Linux 9 (default builder):

```bash
./packer/build.sh --os=oraclelinux --version=9 --action=build
```

## Support Matrix (Current)

- Implemented:
  - `ubuntu/24`
  - `oraclelinux/9`
- Planned:
  - `oraclelinux/8`

## Security Notes

- Never commit secrets in `.env`, `.pkrvars.hcl`, or scripts.
- Keep `packer/env.local.sh` local only.
- Rotate temporary credentials used during image builds.
