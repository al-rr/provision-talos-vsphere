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

## Notes

- Ubuntu cloud-image OVA is acceptable for lab.
- For production, use pinned and validated artifacts (checksum/signature + hardening pipeline).
