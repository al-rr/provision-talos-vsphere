# Talos Script Module

## Purpose
This module centralizes Talos lifecycle scripts in one place.

It provides:
- `install.sh`: install/upgrade `talosctl` (idempotent, local or remote)
- `provision-single-node.sh`: wrapper for single-node Talos provisioning via `govc`
- `provision-cluster.sh`: wrapper for Talos cluster provisioning via `govc`
- `cluster-bootstrap.sh`: Day-1 cluster flow (`generate`, `apply`, `bootstrap`, `all`)
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

## Day-1 Cluster Flow

Use `cluster-bootstrap.sh` after VMs are provisioned and reachable on Talos API (`:50000`).

Generate only:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=generate
```

Apply configs only:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=apply
```

Bootstrap only:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=bootstrap
```

Full Day-1 sequence:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=all
```

Safe simulation:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=all --dry-run
```

Enable global patches explicitly (optional):

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --enable-global-patches
```

## Create A New Cluster From Scratch

Example to create a brand-new cluster named `talos`:

1. Provision VMs first (control planes/workers) with `provision-cluster.sh` or `govc`.
2. Run Day-1 flow with a dedicated output directory and explicit node IPs:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --cluster-name=talos \
  --endpoint=https://192.168.0.250:6443 \
  --generated-dir=overlays/lab/talos/talos/generated \
  --cp-ips=192.168.0.88,192.168.0.89,192.168.0.90 \
  --worker-ips=192.168.0.91,192.168.0.92,192.168.0.93
```

Optional dry-run before applying:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --dry-run \
  --cluster-name=talos \
  --endpoint=https://192.168.0.250:6443 \
  --generated-dir=overlays/lab/talos/talos/generated \
  --cp-ips=192.168.0.88,192.168.0.89,192.168.0.90 \
  --worker-ips=192.168.0.91,192.168.0.92,192.168.0.93
```

If you also want shared/global patches for this run, add:

```bash
--enable-global-patches
```

Global patch directories (optional):
- `overlays/<env>/talos/patches-available`: candidate patches
- `overlays/<env>/talos/patches-enabled`: active patches used when enabled
- Legacy fallback: `overlays/<env>/talos/patches` (if `patches-enabled` does not exist)

Suggested activation flow:

```bash
mkdir -p overlays/lab/talos/patches-enabled
cp overlays/lab/talos/patches-available/flannel.patch.yaml overlays/lab/talos/patches-enabled/
```

Then run with:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --enable-global-patches
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

### Multi-Cluster On Shared HAProxy Pair

If the same HAProxy pair serves more than one Talos cluster, use:
- one VIP per cluster in Keepalived (`KEEPALIVED_VIPS`)
- one frontend/backend pair per cluster in HAProxy

Use append mode so existing frontends/backends are preserved:

```bash
./overlays/base/scripts/talos/configure_load_balancer.sh \
  --env=lab \
  --append \
  --cluster-name=talos \
  --vip=192.168.0.30 \
  --cp-ips=192.168.0.61,192.168.0.62,192.168.0.63 \
  --lb-hosts=192.168.0.55,192.168.0.56 \
  --user=vagrant \
  --ssh-key=/path/to/key
```

Notes:
- `--append` updates the named frontend/backend if they already exist.
- Default generated names in append mode are:
  - frontend: `<cluster-name>_k8s_api`
  - backend: `<cluster-name>_k8s_api_backend`
- You can override names with `--frontend-name` and `--backend-name`.

## Post-Bootstrap Operations (Day-2)

After bootstrap, normal operations are usually:
- patching machine config (single node, many nodes, or all nodes),
- then validating services/nodes,
- and later doing controlled upgrades.

Use this talosconfig:

```bash
TALOSCONFIG=overlays/lab/talos/k8s-cluster-lab/talosconfig
```

Apply a config patch on a single node:

```bash
talosctl --talosconfig "${TALOSCONFIG}" \
  -n 192.168.0.91 \
  patch machineconfig --patch '{"machine":{"time":{"disabled":true}}}'
```

Apply the same patch to multiple nodes:

```bash
talosctl --talosconfig "${TALOSCONFIG}" \
  -n 192.168.0.91,192.168.0.92 \
  patch machineconfig --patch '{"machine":{"time":{"disabled":true}}}'
```

Apply a full machine config file to one node:

```bash
talosctl --talosconfig "${TALOSCONFIG}" \
  -n 192.168.0.91 \
  apply-config --insecure --file overlays/lab/talos/k8s-cluster-lab/worker.yaml
```

Service and cluster checks:

```bash
talosctl --talosconfig "${TALOSCONFIG}" -n 192.168.0.91,192.168.0.92 service kubelet
KUBECONFIG=/home/vagrant/.kube/config kubectl get nodes -o wide
```

### Upgrade Strategy

Recommended order:
1. workers first (one by one or small batches),
2. then control-plane nodes one at a time.

Example (single node):

```bash
talosctl --talosconfig "${TALOSCONFIG}" \
  -n 192.168.0.91 \
  upgrade --image factory.talos.dev/vmware-installer/903b2da78f99adef03cbbd4df6714563823f63218508800751560d3bc3557e40:v1.12.4
```

Then wait for `Ready` before moving to the next node.

## Scale-Out (Add More Workers)

To add one more worker (example: worker-3 with `192.168.0.93`):

1. Create `overlays/lab/talos/k8s-cluster-lab/patches/worker-3.patch.yaml`:

```yaml
machine:
  network:
    interfaces:
      - interface: eth0
        addresses:
          - 192.168.0.93/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.0.2
        dhcp: false
    nameservers:
      - 192.168.0.2
```

2. Re-run provisioning for workers only, increasing `--worker-count`:

```bash
source /tmp/govc-test-vars.sh
./overlays/base/scripts/govc/provision_talos.sh \
  --env=lab \
  --cluster-name=k8s-cluster-lab \
  --cp-count=0 \
  --worker-count=3 \
  --ova-path="https://factory.talos.dev/image/903b2da78f99adef03cbbd4df6714563823f63218508800751560d3bc3557e40/v1.12.4/vmware-amd64.ova" \
  create
```

3. Validate worker join:

```bash
talosctl --talosconfig overlays/lab/talos/k8s-cluster-lab/talosconfig -n 192.168.0.93 version
KUBECONFIG=/home/vagrant/.kube/config kubectl get nodes -o wide
```
