# Packer VMware-ISO Module

## Purpose
This module provides a single entrypoint to build base images for:
- Ubuntu 24 (`ubuntu-24`)
- Oracle Linux 9 (`oraclelinux-9`)
- Any custom profile (`custom`) by passing directory/template/vars

It consolidates the previous draft flows into one generic command.

## Entrypoints
- `build.sh`: orchestrator for ubuntu/oraclelinux/all
- `build-image.sh`: generic runner (init/validate/build)
- `build-oraclelinux.sh`: compatibility wrapper for Oracle Linux profile
- `build-ubuntu.sh`: compatibility wrapper for Ubuntu profile

## Usage
Validate all profiles with a single command:

```bash
./packer/vmware-iso/build.sh --os=all --action=validate
```

Build only Oracle Linux:

```bash
./packer/vmware-iso/build.sh --os=oraclelinux --action=build
```

Validate Oracle Linux template:

```bash
./packer/vmware-iso/build-image.sh --profile=oraclelinux-9 --action=validate
```

Build Ubuntu template:

```bash
./packer/vmware-iso/build-image.sh --profile=ubuntu-24 --action=build
```

Build using extra var file:

```bash
./packer/vmware-iso/build-image.sh \
  --profile=oraclelinux-9 \
  --action=build \
  --vars-file=/path/to/custom.pkrvars.hcl
```

Build using a custom template directory:

```bash
./packer/vmware-iso/build-image.sh \
  --profile=custom \
  --work-dir=./packer/vsphere-iso/oraclelinux/ol9 \
  --template=oraclelinux9.pkr.hcl \
  --default-var-file=oraclelinux.auto.pkrvars.hcl \
  --action=build
```

Dry-run:

```bash
./packer/vmware-iso/build-image.sh --profile=ubuntu-24 --action=build --dry-run
```

## Notes
- The runner prefers `packerio` binary when available, then falls back to `packer`.
- The command always runs `packer init` first.
- For `build`, it runs `validate` before `build`.
- Commands are executed from inside the profile directory to avoid relative-path issues (for example `http_directory = "data"`).
- `build.sh` executes Oracle Linux first and Ubuntu second when `--os=all`.
