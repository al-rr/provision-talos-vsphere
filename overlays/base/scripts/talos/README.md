# Talos Script Module

## Purpose
This module centralizes Talos lifecycle scripts in one place.

It provides:
- `install.sh`: install/upgrade `talosctl` (idempotent, local or remote)
- `provision-single-node.sh`: wrapper for single-node Talos provisioning via `govc`
- `provision-cluster.sh`: wrapper for Talos cluster provisioning via `govc`
- `configure_load_balancer.sh`: configure HAProxy backend servers for Talos control planes
- `vars.sh`: module defaults (`TALOSCTL_VERSION`, `TALOSCTL_INSTALL_DIR`)

## Important Prerequisite

`talosctl` **must be compatible with the Talos cluster version**.

Recommended practice:
- keep `talosctl` on the same major/minor as cluster nodes
- preferably use the same version tag (for example `v1.12.4`)

If versions are not compatible, operations like bootstrap, config apply, and health checks can fail.

## Usage

Install `talosctl` on controller:

```bash
./overlays/base/scripts/talos/install.sh --env=lab
```

Install `talosctl` on a remote host:

```bash
./overlays/base/scripts/talos/install.sh \
  --env=lab \
  --host=192.168.0.10 \
  --user=vagrant \
  --ssh-key=/home/vagrant/.ssh/id_ed25519
```

Run single-node provisioning:

```bash
./overlays/base/scripts/talos/provision-single-node.sh --env=lab create
```

Run cluster provisioning:

```bash
./overlays/base/scripts/talos/provision-cluster.sh --env=lab create
```

## Controller Access

Controller-specific setup (`talosctl`, `kubectl`, `~/.talos/config`, and `~/.kube/config`)
is documented in `overlays/lab/controller/README.md`.

## Boot Source Policy

- Default path is **OVA** (production-ready flow), controlled by `TALOS_OVA_PATH`.
- ISO is only fallback/testing (`TALOS_ISO_DATASTORE_PATH`) when OVA is not set.

## Clean Recreate Flow (Cluster)

```bash
./overlays/base/scripts/talos/provision-cluster.sh --env=lab destroy
./overlays/base/scripts/talos/provision-cluster.sh --env=lab create
talosctl --talosconfig overlays/lab/talos/k8s-cluster-lab/talosconfig \
  --nodes 192.168.0.88 --endpoints 192.168.0.88 bootstrap
```

## Configure HAProxy Backend For Talos

The script reads:
- Talos control-plane IPs from `TALOS_CONTROL_PLANE_IPS` (overlay vars),
- HAProxy targets from `HAPROXY_NODE_1_IP` and `HAPROXY_NODE_2_IP`.
- optional GOVC profile vars from `--vars-file` (recommended for ESXi production-ready simulation).

Environment model:
- Vagrant lab: validate script behavior and idempotency.
- ESXi/GOVC lab: validate production-ready flow and topology.

Apply backend config to both HAProxy nodes:

```bash
./overlays/base/scripts/talos/configure_load_balancer.sh \
  --env=lab \
  --vars-file=overlays/prod/scripts/vars.sh \
  --user=vagrant \
  --ssh-key=/path/to/key
```

Optional:
- `--cp-ips=192.168.0.88,192.168.0.89,192.168.0.90`
- `--lb-hosts=172.17.20.181,172.17.20.182`
