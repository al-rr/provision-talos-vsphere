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

Create local overrides:

```bash
cp packer/vars.local.example.sh packer/vars.local.sh
```

Export module vars and PKR_VAR_*:

```bash
source ./packer/export-pkr-vars.sh
```

This exports:
- `GOVC_*` for `govc`
- `PKR_VAR_*` for Packer

## What `init` Does

`init` runs `packer init` for the selected template directory only.

Use it when:
- you changed plugins or plugin constraints
- this is the first run in a fresh checkout
- you want to validate plugin setup before `validate` or `build`

Example:

```bash
./packer/build.sh --os=ubuntu --version=24 --action=init
```

## Variable Contract

The module values are loaded in this order:

1. `packer/vars.sh`
2. `packer/vars.local.sh` (optional)
3. runtime CLI overrides (`--vars-file`, `--vsphere-*`, `--build-*`)

The template values are split into two groups:

1. Profile-local defaults (`*.auto.pkrvars.hcl`)
- OS-specific and mostly stable values (iso file name/path, disk defaults, boot command defaults).
- Example files:
  - `packer/vsphere-iso/ubuntu/24-04-lts/ubuntu.auto.pkrvars.hcl`
  - `packer/vsphere-iso/oraclelinux/ol9/oraclelinux.auto.pkrvars.hcl`

2. Environment/runtime values (`PKR_VAR_*` from `export-pkr-vars.sh`)
- vSphere endpoint and credentials
- datacenter/cluster/host/datastore/network/folder/resource pool
- build account/key and common toggles (`common_*`)

Required runtime variables are validated by `packer/vsphere-iso/build.sh`:
- `VSPHERE_ENDPOINT`
- `VSPHERE_USERNAME`
- `VSPHERE_PASSWORD`
- `BUILD_USERNAME`
- `BUILD_PASSWORD` or `BUILD_PASSWORD_ENCRYPTED`

Ansible vars expected by upstream templates are exported automatically:
- `ansible_username` defaults to `BUILD_USERNAME` (override with `ANSIBLE_USERNAME`)
- `ansible_key` defaults to `BUILD_KEY` (override with `ANSIBLE_KEY`)

Override options without changing local vars:
- `--vars-file=/path/custom.pkrvars.hcl`
- `--vsphere-env-file=/path/vsphere.env` (when running `vsphere-iso/build.sh` directly)
- direct CLI overrides such as `--vsphere-username`, `--vsphere-password` (direct `vsphere-iso/build.sh`)

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

## Notes

- `packerio` is preferred when available; fallback is `packer`.
- For `build`, the flow executes `init` and `validate` before `packer build`.
- Build artifacts and manifests are created under profile directories inside
  `packer/vsphere-iso/...`.
- `BUILD_KEY` can be auto-loaded from `~/.ssh/id_ed25519.pub` or
  `~/.ssh/id_rsa.pub` when empty.

## ESXi Standalone Limitation

In standalone ESXi (without vCenter), native template conversion can fail with:

`The operation is not supported on the object`

When this happens:
- keep template conversion disabled (`COMMON_TEMPLATE_CONVERSION=false`)
- prefer OVF export/import flow when needed
- or keep the powered-off VM as a golden source for cloning

## Security Notes

- Never commit secrets in `.env`, `.pkrvars.hcl`, or scripts.
- Keep `packer/vars.local.sh` local only.
- Rotate temporary credentials used during image builds.
