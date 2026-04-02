# Packer vSphere-ISO Module

## Purpose

Build guest images directly on vSphere/ESXi using the `vsphere-iso` builder.

## Entrypoint

- `build.sh`: orchestrator for profile/action with module vars and temporary overrides.

## Supported Profiles

- `oraclelinux-9`
- `ubuntu-24`

## Usage

Initialize plugins/modules for selected profile:

```bash
./packer/vsphere-iso/build.sh \
  --profile=ubuntu-24 \
  --action=init
```

Validate profile:

```bash
./packer/vsphere-iso/build.sh \
  --profile=ubuntu-24 \
  --vsphere-username=root \
  --vsphere-password='CHANGE_ME' \
  --build-username=vagrant \
  --build-password=vagrant \
  --action=validate
```

Build image:

```bash
./packer/vsphere-iso/build.sh \
  --profile=ubuntu-24 \
  --vsphere-username=root \
  --vsphere-password='CHANGE_ME' \
  --build-username=vagrant \
  --build-password=vagrant \
  --action=build
```

Enable Ubuntu lab OVF override:

```bash
./packer/vsphere-iso/build.sh \
  --profile=ubuntu-24 \
  --action=build \
  --vars-file=./packer/vsphere-iso/ubuntu/24-04-lts/ubuntu.lab.ovf.pkrvars.hcl
```

Use env-file with `vsphere_*` keys:

```bash
./packer/vsphere-iso/build.sh \
  --profile=oraclelinux-9 \
  --vsphere-env-file=./packer/vsphere-iso/examples/vsphere.env.example \
  --build-username=vagrant \
  --build-password=vagrant \
  --action=validate
```

## Variable Contract

Loading order:

1. `packer/vars.sh`
2. `packer/vars.local.sh` (optional)
3. runtime CLI overrides (`--vars-file`, `--vsphere-*`, `--build-*`)

Profile files (`*.auto.pkrvars.hcl`) keep mostly stable template defaults.
Dynamic environment values should come from exported `PKR_VAR_*` (via
`packer/export-pkr-vars.sh`) or explicit runtime overrides.

Runtime-required values:

- `VSPHERE_ENDPOINT`
- `VSPHERE_USERNAME`
- `VSPHERE_PASSWORD`
- `BUILD_USERNAME`
- `BUILD_PASSWORD`

Recommended loading flow:

```bash
source ./packer/export-pkr-vars.sh
./packer/build.sh --os=ubuntu --version=24 --action=validate
```

## Notes

- `packerio` is preferred when available; fallback is `packer`.
- For `build`, the script always runs `init` and `validate` first.
- `build.sh` creates `manifests/` and `artifacts/` directories automatically.
- `BUILD_KEY` / `PKR_VAR_build_key` is injected into guest SSH authorized keys.
- If `BUILD_KEY` is empty, `build.sh` auto-loads `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`.

## ESXi Standalone Limitation

In standalone ESXi (without vCenter), native template conversion can fail with:

`The operation is not supported on the object`

When this happens:
- keep template conversion disabled (`COMMON_TEMPLATE_CONVERSION=false`)
- prefer OVF export/import flow when needed
- or keep the powered-off VM as a golden source for cloning
