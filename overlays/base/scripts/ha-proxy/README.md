# HAProxy Script Module

## Purpose
This module manages HAProxy lifecycle on Linux hosts using Bash only (local or SSH remote execution).

It provides:
- package installation (`install.sh`)
- configuration rendering and apply (`setup.sh`)
- host hardening for HAProxy ports and sysctl (`hardening.sh`)
- full HA orchestration (`run-full.sh`)

The lifecycle scripts (`install.sh`, `setup.sh`, `hardening.sh`) are compatibility
wrappers and delegate execution to `infra-gitops/scripts/ha-proxy/`.

## Why Hardening Is Required

In this project, `hardening.sh` is required for stable HAProxy operation, not
just optional security tuning.

It applies:
- firewall allow rules for HAProxy ports (`HAPROXY_ALLOWED_PORTS`)
- sysctl network baseline (`rp_filter`, redirects/source-route, syncookies)
- `net.ipv4.ip_nonlocal_bind=1` when `HAPROXY_ENABLE_NONLOCAL_BIND=true`

The nonlocal bind setting is necessary for floating VIP scenarios. Without it,
HAProxy can fail to start on a node that does not currently own the VIP, with
errors like `cannot bind socket (Cannot assign requested address)`.

## Supported Platforms
- Debian/Ubuntu (`apt`)
- RHEL/Oracle Linux/Rocky/Alma (`dnf`/`yum`)

Remote execution requires:
- SSH access to target
- `sudo` on target if not root

## Module Contents
- `install.sh`: installs HAProxy and required dependencies.
- `setup.sh`: renders `haproxy.cfg`, applies it, validates, reloads service.
- `hardening.sh`: applies sysctl profile and firewall rules.
- `run-full.sh`: provisions two nodes with `govc`, then installs/configures HAProxy, applies hardening, and configures Keepalived.
  Keepalived module source is `infra-gitops/scripts/keepalived`.
- `govc/provision.sh`: VMware-specific provisioning entrypoint for HAProxy VMs.
- `vars.sh`: module defaults.
- `templates/haproxy.cfg.tpl`: config template.

## Variables And Defaults
Defaults are in [vars.sh](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/vars.sh) and loaded via `overlays/base/scripts/vars.sh`.

Important variables:
- `HAPROXY_SERVICE_NAME="haproxy"`
- `HAPROXY_CONFIG_PATH="/etc/haproxy/haproxy.cfg"`
- `HAPROXY_TEMPLATE_PATH="overlays/base/scripts/ha-proxy/templates/haproxy.cfg.tpl"`
- `HAPROXY_FRONTENDS_BLOCK` and `HAPROXY_BACKENDS_BLOCK`
- `HAPROXY_STATS_USER="admin"`
- `HAPROXY_STATS_PASS="changeme"`
- `HAPROXY_ALLOWED_PORTS="6443,8404"`
- `HAPROXY_SYSCTL_PROFILE="secure"`
- `HAPROXY_ENABLE_NONLOCAL_BIND="true"` (sets `net.ipv4.ip_nonlocal_bind=1`)
- `HAPROXY_VM_TEMPLATE_NAME`, `HAPROXY_VM_OVA_PATH`, `HAPROXY_VM_OVF_PATH`
- `HAPROXY_VM_NAMESERVERS` (defaults to `NETWORK_NAMESERVERS`, typically `192.168.0.53` in lab)

Override these in `overlays/<env>/scripts/vars.sh` when needed.

## Script Inventory
- `install.sh` flags:
  - `--env`, `--vars-file`, `--host`, `--user`, `--port`, `--ssh-key`, `--show-values`, `--dry-run`
- `setup.sh` flags:
  - `--env`, `--vars-file`, `--template`, `--output`, `--host`, `--user`, `--port`, `--ssh-key`, `--show-values`, `--reload`, `--no-reload`, `--dry-run`
- `hardening.sh` flags:
  - `--env`, `--vars-file`, `--ports`, `--host`, `--user`, `--port`, `--ssh-key`, `--show-values`, `--dry-run`
- `run-full.sh` flags:
  - `--env`, `--vars-file`, `--count`, `--prefix`, `--mode`, `--overwrite`
  - `--skip-provision`, `--skip-haproxy`, `--skip-hardening`, `--skip-keepalived`, `--show-values`
  - `--user`, `--port`, `--ssh-key`, `--ssh-key-dir`, `--infra-gitops-root`, `--dry-run`

## Full Flow
`run-full.sh` is the reusable entrypoint for the complete HAProxy HA workflow:

1. Provision the two VMs with `govc`
2. Install HAProxy on both nodes
3. Apply HAProxy configuration on both nodes
4. Apply host hardening on both nodes
5. Install Keepalived on both nodes
6. Apply Keepalived configuration with `MASTER` on node 1 and `BACKUP` on node 2

The script reuses the existing scripts instead of duplicating logic.
It currently supports exactly two nodes, which matches the keepalived HA pair design.
When `HAPROXY_VIP` is set, `run-full.sh` derives `KEEPALIVED_VIPS` automatically as `${HAPROXY_VIP}/${NETWORK_NETMASK_PREFIX}`.
Keepalived template path is resolved from `--infra-gitops-root` and passed explicitly to avoid relative-path issues.
When guest static networking is enforced, provisioning disables cloud-init network config and removes `/etc/netplan/50-cloud-init.yaml` before `netplan apply` to prevent duplicate default-route conflicts.

For SSH authentication it can:
- use `--ssh-key` for both nodes
- discover per-node keys via `--ssh-key-dir`
- auto-discover Vagrant private keys in `overlays/lab/.vagrant/machines` for `lab`

VM IP resolution prefers `govc vm.ip -v4` and falls back to overlay IPs when needed.
After create/destroy actions, `govc/provision.sh` also syncs DNS owner records
(`owner=ha-proxy`) through `overlays/base/scripts/dns/register-hosts.sh` and
`overlays/base/scripts/dns/unregister-hosts.sh`.

## Usage Examples
Install on both lab nodes:

```bash
./overlays/base/scripts/ha-proxy/install.sh --env=lab --host=172.17.20.181 --user=vagrant --ssh-key=/tmp/talos-lb-1.key
./overlays/base/scripts/ha-proxy/install.sh --env=lab --host=172.17.20.182 --user=vagrant --ssh-key=/tmp/talos-lb-2.key
```

Apply config on both nodes:

```bash
./overlays/base/scripts/ha-proxy/setup.sh --env=lab --host=172.17.20.181 --user=vagrant --ssh-key=/tmp/talos-lb-1.key
./overlays/base/scripts/ha-proxy/setup.sh --env=lab --host=172.17.20.182 --user=vagrant --ssh-key=/tmp/talos-lb-2.key
```

Apply hardening:

```bash
./overlays/base/scripts/ha-proxy/hardening.sh --env=lab --host=172.17.20.181 --user=vagrant --ssh-key=/tmp/talos-lb-1.key
./overlays/base/scripts/ha-proxy/hardening.sh --env=lab --host=172.17.20.182 --user=vagrant --ssh-key=/tmp/talos-lb-2.key
```

Validate stats endpoint:

```bash
curl -u admin:changeme http://172.17.20.90:8404/stats
curl -u admin:changeme http://192.168.0.250:8404/stats
```

Run the full HA workflow in lab:

```bash
./overlays/base/scripts/ha-proxy/run-full.sh \
  --env=lab \
  --vars-file=/tmp/govc-test-vars.sh \
  --count=2 \
  --prefix=talos-lb \
  --mode=auto \
  --overwrite
```

Run only configuration steps for already provisioned hosts:

```bash
./overlays/base/scripts/ha-proxy/run-full.sh \
  --env=lab \
  --skip-provision \
  --count=2 \
  --prefix=talos-lb
```

Show values only (no execution):

```bash
./overlays/base/scripts/ha-proxy/govc/provision.sh --env=lab --show-values create
./overlays/base/scripts/ha-proxy/install.sh --env=lab --show-values
./overlays/base/scripts/ha-proxy/setup.sh --env=lab --show-values
./overlays/base/scripts/ha-proxy/hardening.sh --env=lab --show-values
./overlays/base/scripts/ha-proxy/run-full.sh --env=lab --show-values
```

## Testing Notes
- Syntax:
  - `bash -n overlays/base/scripts/ha-proxy/*.sh`
  - `bash -n overlays/base/scripts/ha-proxy/run-full.sh`
- Repository lint:
  - `./overlays/base/scripts/lint-shell.sh --env=lab`
- Runtime checks:
  - `systemctl is-active haproxy`
  - `ss -lntp | grep -E ':(6443|8404)\b'`

## Related Files
- [base vars loader](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/vars.sh)
- [ha-proxy module](/home/vagrant/infra-gitops/scripts/ha-proxy/README.md)
- [keepalived module](/home/vagrant/infra-gitops/scripts/keepalived/README.md)
- [HAProxy VMware provisioning script](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/govc/provision.sh)
