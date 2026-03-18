# Keepalived Script Module

## Purpose
This module configures VRRP high availability for HAProxy nodes using Keepalived, via Bash scripts (local or SSH remote).

It provides:
- keepalived installation (`install.sh`)
- keepalived configuration/render/apply (`setup.sh`)

## Supported Platforms
- Debian/Ubuntu (`apt`)
- RHEL/Oracle Linux/Rocky/Alma (`dnf`/`yum`)

Remote execution requires:
- SSH access to target
- `sudo` on target if not root

## Module Contents
- `install.sh`: installs Keepalived and enables service.
- `setup.sh`: renders `keepalived.conf`, applies config, validates, restarts service.
- `vars.sh`: module defaults.
- `templates/keepalived.conf.tpl`: config template.

## Variables And Defaults
Defaults are in [vars.sh](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/keepalived/vars.sh) and loaded via `overlays/base/scripts/vars.sh`.

Important variables:
- `KEEPALIVED_SERVICE_NAME="keepalived"`
- `KEEPALIVED_CONFIG_PATH="/etc/keepalived/keepalived.conf"`
- `KEEPALIVED_TEMPLATE_PATH="overlays/base/scripts/keepalived/templates/keepalived.conf.tpl"`
- `KEEPALIVED_INTERFACE="auto"` (detects default route interface; can be overridden)
- `KEEPALIVED_ROUTER_ID="51"`
- `KEEPALIVED_STATE="BACKUP"` (override per node)
- `KEEPALIVED_PRIORITY="100"` (override per node)
- `KEEPALIVED_AUTH_PASS="vrrp1234"`
- `KEEPALIVED_VIPS="192.168.0.250/24"` (for lab; override per environment)
- `KEEPALIVED_UNICAST_SRC_IP=""` (required in unicast mode)
- `KEEPALIVED_UNICAST_PEERS` should match your node IPs in each environment
- `KEEPALIVED_TRACK_HAPROXY="true"`

Override these in `overlays/<env>/scripts/vars.sh` when needed.

## Script Inventory
- `install.sh` flags:
  - `--env`, `--host`, `--user`, `--port`, `--ssh-key`, `--dry-run`
- `setup.sh` flags:
  - `--env`, `--template`, `--output`, `--interface`, `--state`, `--priority`, `--src-ip`, `--peers`, `--vips`, `--host`, `--user`, `--port`, `--ssh-key`, `--dry-run`

## Usage Examples
Install on both lab nodes:

```bash
./overlays/base/scripts/keepalived/install.sh --env=lab --host=172.17.20.181 --user=vagrant --ssh-key=/tmp/talos-lb-1.key
./overlays/base/scripts/keepalived/install.sh --env=lab --host=172.17.20.182 --user=vagrant --ssh-key=/tmp/talos-lb-2.key
```

Configure node 1 as MASTER:

```bash
./overlays/base/scripts/keepalived/setup.sh \
  --env=lab \
  --host=172.17.20.181 \
  --user=vagrant \
  --ssh-key=/tmp/talos-lb-1.key \
  --interface=eth1 \
  --state=MASTER \
  --priority=120 \
  --src-ip=172.17.20.181
```

Configure node 2 as BACKUP:

```bash
./overlays/base/scripts/keepalived/setup.sh \
  --env=lab \
  --host=172.17.20.182 \
  --user=vagrant \
  --ssh-key=/tmp/talos-lb-2.key \
  --interface=ens224 \
  --state=BACKUP \
  --priority=100 \
  --src-ip=172.17.20.182
```

## Testing Notes
- Syntax:
  - `bash -n overlays/base/scripts/keepalived/*.sh`
- Repository lint:
  - `./overlays/base/scripts/lint-shell.sh --env=lab`
- Runtime checks:
  - `systemctl is-active keepalived`
  - `ip -o -4 addr show <interface>` and confirm VIP appears on MASTER

## Related Files
- [base vars loader](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/vars.sh)
- [haproxy module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/README.md)
- [keepalived ansible template reference](/home/vagrant/talos-vsphere-lab/overlays/base/ansible/roles/keepalived/templates/keepalived.conf.j2)
