# Talos Cluster Guide

## Purpose

This guide describes the recommended flow to create a Talos cluster in this
repository using the Talos module scripts.

It is written for the multi-node cluster case:

- multiple control-plane nodes
- one or more worker nodes
- a stable cluster API endpoint
- optional dedicated DNS

## What Must Exist Before You Start

You should have the following prepared before executing cluster scripts:

| Item | Why It Matters | Example In This Repository |
| --- | --- | --- |
| Cluster plan | Prevents IP and role confusion | [INFRASTRUCTURE_PLAN_EXAMPLE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md) |
| `talosctl` | Required for cluster configuration and bootstrap | `overlays/base/scripts/talos/install.sh` |
| `govc` | Required to provision Talos VMs on ESXi or vSphere | `overlays/base/scripts/govc/README.md` |
| Load balancer or stable endpoint | Talos cluster API should not depend on a single control-plane IP | HAProxy + Keepalived modules |
| DNS, if needed | Avoids unstable name resolution during install and runtime | DNS module |

## Cluster Planning Inputs

Before cluster creation, define these values:

- cluster name
- cluster endpoint
- control-plane IP list
- worker IP list
- load balancer VIP, if used
- DNS server IP, if dedicated DNS is used
- Talos OVA or image source
- cluster patches
- post-bootstrap CNI values, such as Cilium values

Recommended source of truth for cluster-specific intent:

- [overlays/lab/talos/talos/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md)
- `overlays/lab/talos/talos/cluster-spec.yaml`

## Recommended Execution Order

## Phase-Oriented Flow

Use this sequence for reproducible runs:

1. Cluster Ready
2. Network Bring-up
3. GitOps Handoff (after Cilium is stable)

### Cluster Ready phase

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab
```

Important behavior when `TALOS_DISABLE_DEFAULT_CNI=true` (`cni: none`):

- Kubernetes API is expected to be reachable after bootstrap.
- Nodes are expected to stay `NotReady` until a CNI is installed (for example Cilium).
- This is normal and does not block moving to the Network Bring-up phase.

Control-plane-only test:

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab --worker-count=0
```

### Network Bring-up phase

Cilium:

```bash
./overlays/base/scripts/talos/cilium.sh --env=lab
```

Argo CD:

```bash
./overlays/base/scripts/talos/argocd.sh --env=lab
```

Render + API validation only (no install/upgrade):

```bash
./overlays/base/scripts/talos/cilium.sh --env=lab --render-only
```

### GitOps handoff phase

After Cilium is stable:

1. Install Argo CD.
2. Move addon ownership to Argo CD Applications.
3. Continue day-2 operations by PR/merge only.

### 1. Prepare controller tools

Follow:

- [overlays/lab/controller/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md)

At minimum, prepare:

- `talosctl`
- `kubectl`
- `helm`

### 2. Prepare DNS if your lab needs it

If the lab network does not provide stable DNS, provision a dedicated DNS VM first.

Follow:

- `infra-gitops/scripts/dnsmasq/README.md`

### 3. Prepare the load balancer if your cluster uses a VIP

If the cluster endpoint is a VIP, provision and configure the load balancer first.

Follow:

- [HAProxy module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/README.md)

If you want one Talos-oriented orchestration entrypoint for the load balancer:

```bash
./overlays/base/scripts/talos/provision_and_configure_load_balancer.sh --env=lab
```

### 4. Provision Talos VMs

Cluster VM provisioning entrypoint:

```bash
./overlays/base/scripts/talos/provision-cluster.sh --env=lab create
```

Control-plane-only provisioning (workers later):

```bash
./overlays/base/scripts/talos/provision-cluster.sh --env=lab --worker-count=0 create
```

Important note:

- This script is a wrapper over `overlays/base/scripts/talos/govc/provision-cluster.sh`.
- It depends on `govc` and the overlay variables used by the ESXi or vSphere environment.
- Destroy now removes discovered VMs by prefix (`talos-cp-*` and `talos-worker-*`) to avoid stale nodes when counts change between runs.

### 5. Generate Talos configuration

Generate only:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=generate
```

Use explicit arguments when creating a brand-new cluster:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=<env> \
  --mode=generate \
  --cluster-name=<cluster-name> \
  --endpoint=https://<vip-or-endpoint>:6443 \
  --generated-dir=overlays/<env>/talos/<cluster-name>/generated \
  --cp-ips=<cp1-ip>,<cp2-ip>,<cp3-ip> \
  --worker-ips=<worker1-ip>,<worker2-ip>,<worker3-ip>
```

Optional CNI mode controls:

- Keep Talos default CNI/kube-proxy (default): no extra flag.
- Disable Talos default CNI/kube-proxy (for Cilium): `--disable-default-cni`
- Re-enable explicitly: `--enable-default-cni`
- Overlay variable: `TALOS_DISABLE_DEFAULT_CNI=true|false`

Use [INFRASTRUCTURE_PLAN_EXAMPLE.md](INFRASTRUCTURE_PLAN_EXAMPLE.md) for a concrete sample,
and keep your real environment values in your overlay workspace (for example
`overlays/lab/talos/talos/cluster-spec.yaml`).

### 6. Apply Talos configuration

Apply only:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=apply
```

Or with explicit values:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=<env> \
  --mode=apply \
  --cluster-name=<cluster-name> \
  --endpoint=https://<vip-or-endpoint>:6443 \
  --generated-dir=overlays/<env>/talos/<cluster-name>/generated \
  --cp-ips=<cp1-ip>,<cp2-ip>,<cp3-ip> \
  --worker-ips=<worker1-ip>,<worker2-ip>,<worker3-ip>
```

Control-plane-only apply:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=apply \
  --worker-ips='[]'
```

Important note:

- `cluster-bootstrap.sh` now reconciles the Talos HAProxy frontend/backend automatically for this cluster.
- It updates only the cluster-specific frontend/backend block (idempotent) and keeps unrelated HAProxy entries untouched.
- Use `--skip-lb-config` only when you explicitly want to manage HAProxy manually.
- CNI disable patch (`cni.patch.yaml`) is applied only when `TALOS_DISABLE_DEFAULT_CNI=true` or `--disable-default-cni` is used.
- After bootstrap, it validates kube-api readiness through the cluster endpoint VIP.
- Tune validation with `--validate-timeout-seconds=<seconds>` and `--validate-interval-seconds=<seconds>`.
- Use `--skip-post-validate` only when you intentionally want to skip this final health gate.

### 7. Bootstrap the cluster

Bootstrap only:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=bootstrap
```

Control-plane-only bootstrap:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=bootstrap \
  --worker-ips='[]'
```

Or run the full sequence in one command:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=all
```

Control-plane-only full flow:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --worker-ips='[]'
```

Important note:

- The bootstrap command is one-time by design. If the cluster is already initialized, the script treats `AlreadyExists` as expected and continues.

### 8. Configure controller access

After bootstrap, configure:

- `~/.talos/config`
- `~/.kube/config`

Follow:

- [overlays/lab/controller/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md)

### 9. Perform post-bootstrap actions

Examples:

- install Cilium
- update Cilium values and re-run `./overlays/base/scripts/talos/cilium.sh --env=lab`
- install or update Argo CD with `./overlays/base/scripts/talos/argocd.sh --env=lab`
- patch machine configuration
- update control-plane or worker settings
- validate node readiness and networking

## Notes About Global Patches

When global patches are used, the repository expects:

- `overlays/<env>/talos/patches-available`
- `overlays/<env>/talos/patches-enabled`

Optional activation example:

```bash
mkdir -p overlays/lab/talos/patches-enabled
cp overlays/lab/talos/patches-available/flannel.patch.yaml overlays/lab/talos/patches-enabled/
```

Then enable them during cluster creation:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --enable-global-patches
```

## Related Documents

- [Talos module index](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/README.md)
- [Infrastructure plan example](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md)
- [Talos cluster workspace](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md)
