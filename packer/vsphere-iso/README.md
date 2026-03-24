# Packer vSphere-ISO Module

## Purpose
Build guest images directly on vSphere/ESXi using the `vsphere-iso` builder.

## Entrypoint
- `build.sh`: orchestrator for profile/action with overlay vars and temporary credential overrides.

## Supported Profiles
- `oraclelinux-9`
- `ubuntu-24`

## Lab OVF Export

When `--env=lab` and `--profile=ubuntu-24` are used, `build.sh` automatically loads:

- `packer/vsphere-iso/ubuntu/24-04-lts/ubuntu.lab.ovf.pkrvars.hcl`

That profile keeps `common_template_conversion=false` and enables OVF export for reuse in standalone ESXi with `govc`.

## Usage

Validate profile:

```bash
./packer/vsphere-iso/build.sh \
  --profile=ubuntu-24 \
  --env=lab \
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
  --env=lab \
  --vsphere-username=root \
  --vsphere-password='CHANGE_ME' \
  --build-username=vagrant \
  --build-password=vagrant \
  --action=build
```

The resulting OVF artifact is written under:

```bash
packer/vsphere-iso/ubuntu/24-04-lts/artifacts/ubuntu-24-04-lts-template/
```

Use the `.ovf` file in that directory with `govc import.ovf`.

Example:

```bash
govc import.ovf \
  -ds DATASTORE_02 \
  -net "VM Network" \
  -name ubuntu-24-04-lts-template \
  packer/vsphere-iso/ubuntu/24-04-lts/artifacts/ubuntu-24-04-lts-template/*.ovf
```

Use env-file with `vsphere_*` keys:

```bash
./packer/vsphere-iso/build.sh \
  --profile=oraclelinux-9 \
  --env=lab \
  --vsphere-env-file=./packer/vsphere-iso/examples/vsphere.env.example \
  --build-username=vagrant \
  --build-password=vagrant \
  --action=validate
```

Add extra var file:

```bash
./packer/vsphere-iso/build.sh \
  --profile=oraclelinux-9 \
  --env=lab \
  --action=build \
  --vars-file=/tmp/custom.pkrvars.hcl
```

## Notes
- The script loads `overlays/base/scripts/vars.sh` + `overlays/<env>/scripts/vars.sh`.
- Optional `--vsphere-env-file` accepts `vsphere_*` keys and overrides overlay values.
- `packerio` is preferred when available; fallback is `packer`.
- For `build`, the script always runs `init` and `validate` first.
- `build.sh` creates `manifests/` and `artifacts/` directories automatically.
- `BUILD_KEY`/`PKR_VAR_build_key` is injected into guest SSH authorized keys during image creation.
- If `BUILD_KEY` is empty, `build.sh` auto-loads the first available key from `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`.

## ESXi Standalone Limitation
If your environment is standalone ESXi (without vCenter), `convert_to_template` can fail with:

`The operation is not supported on the object`

In this case, keep `common_template_conversion=false` and use the resulting powered-off VM as a golden source for `govc vm.clone`.
For the Ubuntu lab profile, OVF export is enabled automatically so you can reuse the build artifact with `govc import.ovf` even when clone/template workflows are limited.
