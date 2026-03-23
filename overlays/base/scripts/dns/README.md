# DNS Module

## Purpose

This module owns DNS VM lifecycle for VMware (`govc`) and DNS service defaults used by `dnsmasq` setup flows.

This module does not own dnsmasq implementation logic. Service lifecycle is handled
by the reusable module in `infra-gitops/scripts/dnsmasq`.
`install.sh` and `setup.sh` are thin wrappers for operator convenience.

## Scripts

- `provision.sh`: compatibility entrypoint (delegates to `dns/govc/provision.sh`)
- `govc/provision.sh`: DNS VM provisioning on ESXi/vSphere (`create|destroy|plan`)
- `install.sh`: compatibility wrapper for `../infra-gitops/scripts/dnsmasq/install.sh`
- `setup.sh`: compatibility wrapper for `../infra-gitops/scripts/dnsmasq/setup.sh`
- `run-full.sh`: orchestration wrapper (`provision -> install -> setup`)
- `vars.sh`: DNS module defaults (`DNS_VM_*`, `DNS_*`)

## Scope Boundary

- Here (`talos-vsphere-lab/overlays/base/scripts/dns`): VM provisioning for DNS role.
- In `infra-gitops/scripts/dnsmasq`: package install, setup, host records management, and service restart.

## Provisioning Source

For lab, prefer a known-good template already validated in your environment.

You can also use OVA/OVF by setting one of:

- `DNS_VM_OVA_PATH`
- `DNS_VM_OVF_PATH`

For Ubuntu cloud-image OVA, set bootstrap identity explicitly in overlay vars:

- `DNS_VM_GUEST_USERNAME=<desired-user>`
- `DNS_VM_GUEST_PASSWORD=<password>`
- `DNS_CLOUDINIT_PUBLIC_KEY=<your-public-key>`
- `DNS_SSH_USER=<same-user>`
- `DNS_VM_STATIC_INTERFACE=auto` (recommended default)

When these values are present, provisioning injects cloud-init `user-data` with:
- user creation
- password login enabled
- `chpasswd.expire: false` (no forced password change on first login)

Notes:
- `ubuntu` is common for Ubuntu cloud images, but not required.
- You can use your project user (for example `BUILD_USERNAME`) by setting `DNS_VM_GUEST_USERNAME` (or by letting it inherit from `BUILD_USERNAME` when not explicitly set).
- Keep interface as `auto` when targeting mixed platforms (Vagrant/ESXi/vSphere), because NIC names can change (`ens160`, `ens192`, etc).

Example with lab profile:

```bash
./overlays/base/scripts/dns/govc/provision.sh \
  --env=lab \
  --vars-file=overlays/lab/scripts/vars.sh \
  create
```

Install dnsmasq on DNS host:

```bash
./overlays/base/scripts/dns/install.sh \
  --env=lab
```

Apply dnsmasq configuration:

```bash
./overlays/base/scripts/dns/setup.sh \
  --env=lab
```

Record formats supported by wrapper:

- Preferred: `DNS_A_RECORDS_LIST` bash array in `overlays/<env>/scripts/vars.sh`
- Compatible: `DNS_A_RECORDS` CSV string (`host=ip,host2=ip2`)

Lab note:
- `DNS_A_RECORDS_LIST` can be composed from shared Talos variables (for example
  `TALOS_CONTROL_PLANE_IPS` and `TALOS_WORKER_IPS`) so DNS records stay aligned
  with cluster topology.

Optional hosts file (if you prefer file-based records instead of `DNS_A_RECORDS`):

```bash
./overlays/base/scripts/dns/setup.sh \
  --env=lab \
  --hosts-file=overlays/lab/scripts/dnsmasq.hosts
```

Full bootstrap flow:

```bash
./overlays/base/scripts/dns/run-full.sh --env=lab
```

Show values only (no execution):

```bash
./overlays/base/scripts/dns/govc/provision.sh --env=lab --show-values
./overlays/base/scripts/dns/install.sh --env=lab --show-values
./overlays/base/scripts/dns/setup.sh --env=lab --show-values
```

Wrapper resolution model:

1. `--vars-file=<path>` (when explicitly provided)
2. `overlays/<env>/scripts/vars.sh` (with `--env`, default `lab`)

Remote target auto-resolution (when CLI flags are not explicitly provided):

1. `--host` from `DNS_VM_STATIC_IP`
2. `--user` from `DNS_SSH_USER`, then `ANSIBLE_USERNAME`, then `BUILD_USERNAME`
3. `--port` from `DNS_SSH_PORT` (default `22`)
4. `--ssh-key` from `DNS_SSH_KEY`, then `ANSIBLE_PRIVATE_KEY_FILE`

If no host is resolved, the wrapper exits with an error instead of silently
falling back to local execution.

## Validation Status (Lab)

Validated flow:

1. `./overlays/base/scripts/dns/govc/provision.sh --env=lab create`
2. `./overlays/base/scripts/dns/install.sh --env=lab`
3. `./overlays/base/scripts/dns/setup.sh --env=lab`

Validated result on DNS VM:

- `/etc/dnsmasq.hosts` includes:
  - `talos-api`
  - `talos-lb-1`, `talos-lb-2`
  - `talos-cp-1..N`
  - `talos-worker-1..N`

## Variable Precedence

`govc/provision.sh` resolves values in this order:

1. CLI flags (`--count`, `--prefix`, etc.)
2. `DNS_VM_*` variables
3. `GOVC_VM_*` variables
4. hardcoded defaults

Guest credential defaults for in-guest static network enforcement:

- `DNS_VM_GUEST_*` (module-specific override)
- `BUILD_*` (environment/source-of-truth)
- `GOVC_VM_GUEST_*` (tool-specific fallback)

Cloud-init bootstrap user-data defaults (for cloud-image flows):

- username: `DNS_VM_GUEST_USERNAME` (fallback to `BUILD_USERNAME`)
- password: `DNS_CLOUDINIT_PASSWORD` (fallback to `DNS_VM_GUEST_PASSWORD` / `BUILD_PASSWORD`)
- SSH key: `DNS_CLOUDINIT_PUBLIC_KEY` (fallback to `BUILD_KEY` / `ANSIBLE_KEY`)

Network interface defaults:

- `DNS_VM_STATIC_INTERFACE` defaults to `auto`.
- In `auto`, provisioning uses cloud-init/netplan matching (`name: "e*"`) and in-guest fallback detection.
- You can still override with a fixed interface name when required.
- During in-guest static enforcement, provisioning disables cloud-init network management and removes `/etc/netplan/50-cloud-init.yaml` before applying `/etc/netplan/99-govc-static.yaml`, preventing duplicate default-route declarations.

Clone source note:

- `DNS_VM_TEMPLATE_NAME` accepts either a VMware template name or a regular VM name to clone from.
- On ESXi environments where template cloning is not supported for a given object, keep `DNS_VM_OVA_PATH` configured for OVA fallback.

## Notes

- Ubuntu cloud-image OVA is acceptable for lab.
- For production, use pinned and validated artifacts (checksum/signature + hardening pipeline).
