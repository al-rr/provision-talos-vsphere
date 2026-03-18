# GOVC Provisioning Guide

Scripts in this directory automate VM lifecycle in vSphere/ESXi.

## Files
- `install.sh`: installs `govc`.
- `provision_haproxy.sh`: create/destroy/plan VMs for HAProxy (or other guests).
- `vars.sh`: optional defaults specific to GOVC automation.

## Comando Importante

Este é o comando principal para provisionar os LBs no lab usando OVF/OVA:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=auto \
  create
```

Ordem do `auto`:
1. `--ova-path` ou `GOVC_VM_OVA_PATH`, se existir.
2. `--ovf-path` ou `GOVC_VM_OVF_PATH`, se existir.
3. `--template`/`GOVC_VM_TEMPLATE_NAME`/`TF_TEMPLATE_NAME`, para clone em vCenter.

Se nada for encontrado, o script falha por padrão. Use fallback vazio apenas quando quiser explicitamente:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=auto \
  --auto-fallback-empty \
  create
```

Para lab em ESXi standalone, normalmente o caminho mais previsível é apontar diretamente para o artefato exportado pelo Packer:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=ova \
  --ova-path=packer/vsphere-iso/ubuntu/24-04-lts/artifacts/ubuntu-24-04-lts-template/ubuntu-24-04-lts-template.ova \
  create
```

Se você exportar OVF em vez de OVA:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=ovf \
  --ovf-path=packer/vsphere-iso/ubuntu/24-04-lts/artifacts/ubuntu-24-04-lts-template \
  create
```

## `provision_haproxy.sh`

### Purpose
Provision VMs by:
- importing OVA/OVF artifacts,
- cloning from a source VM/template, or
- creating an empty VM,
with optional fallback to empty VM only when explicitly enabled.

### Actions
- `plan`: show what will happen.
- `create`: create VMs.
- `destroy`: remove VMs.

### Main options
- `--env=lab`
- `--count=<n>`
- `--prefix=<name>`
- `--start-index=<n>`
- `--mode=auto|ova|ovf|clone|empty`
- `--template=<name>`
- `--ova-path=<path>`
- `--ovf-path=<path>`
- `--cpu=<n>`
- `--memory-mb=<n>`
- `--disk-gb=<n>`
- `--network=<name>`
- `--datastore=<name>`
- `--power-on|--no-power-on`
- `--overwrite`
- `--auto-fallback-empty|--no-auto-fallback-empty`

### Mode behavior
- `auto` (default):
  - tries `OVA`, then `OVF`, then clone source
  - by default, if nothing is found or import/clone fails, script stops with error
  - use `--auto-fallback-empty` to allow fallback to empty VM create
- `ova`:
  - imports an OVA artifact from `--ova-path` or `GOVC_VM_OVA_PATH`
- `ovf`:
  - imports an OVF artifact from `--ovf-path` or `GOVC_VM_OVF_PATH`
- `clone`:
  - requires valid source and fails if clone fails
- `empty`:
  - skips clone and creates VM from scratch (`govc vm.create`)
  - power-on is suppressed by default to avoid EFI boot failures on empty machines

### Source candidates
You can provide multiple source candidates via:
- `GOVC_VM_SOURCE_CANDIDATES="ubuntu-24-04-lts-template,oraclelinux-9-x86-64-template"`

First existing source is selected.

### Artifact paths
- The `--ova-path` and `--ovf-path` options accept either a file or a directory.
- If a directory is provided, the script looks for the first matching `*.ova` or `*.ovf` inside it.
- This matches the Packer export layout that writes artifacts under `artifacts/<vm_name>/`.

## Examples

Plan:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=auto \
  plan
```

Create using auto mode:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=auto \
  create
```

Create using OVA directly:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=ova \
  --ova-path=packer/vsphere-iso/ubuntu/24-04-lts/artifacts/ubuntu-24-04-lts-template/ubuntu-24-04-lts-template.ova \
  create
```

Create using OVF directly:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=ovf \
  --ovf-path=packer/vsphere-iso/ubuntu/24-04-lts/artifacts/ubuntu-24-04-lts-template \
  create
```

Create using auto mode with fallback to empty VM:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=auto \
  --auto-fallback-empty \
  create
```

Force clone from a specific source:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=clone \
  --template=ubuntu-24-04-lts-template \
  create
```

Force empty VMs:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  --mode=empty \
  create
```

Destroy:

```bash
./overlays/base/scripts/govc/provision_haproxy.sh \
  --env=lab \
  --count=2 \
  --prefix=talos-lb \
  destroy
```

## Notes
- In standalone ESXi, clone/template operations may be partially limited depending on object and API support.
- In standalone ESXi, OVA/OVF import is usually the most reliable path.
- `auto` mode is recommended when you want one command to work in lab and vCenter.
