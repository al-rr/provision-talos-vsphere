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

Important note:

- This script is a wrapper over `overlays/base/scripts/talos/govc/provision-cluster.sh`.
- It depends on `govc` and the overlay variables used by the ESXi or vSphere environment.

### 5. Generate Talos configuration

Generate only:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=generate
```

Use explicit arguments when creating a brand-new cluster:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=generate \
  --cluster-name=talos \
  --endpoint=https://192.168.0.250:6443 \
  --generated-dir=overlays/lab/talos/talos/generated \
  --cp-ips=192.168.0.88,192.168.0.89,192.168.0.90 \
  --worker-ips=192.168.0.91,192.168.0.92,192.168.0.93
```

### 6. Apply Talos configuration

Apply only:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=apply
```

Or with explicit values:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=apply \
  --cluster-name=talos \
  --endpoint=https://192.168.0.250:6443 \
  --generated-dir=overlays/lab/talos/talos/generated \
  --cp-ips=192.168.0.88,192.168.0.89,192.168.0.90 \
  --worker-ips=192.168.0.91,192.168.0.92,192.168.0.93
```

### 7. Bootstrap the cluster

Bootstrap only:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=bootstrap
```

Or run the full sequence in one command:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=all
```

### 8. Configure controller access

After bootstrap, configure:

- `~/.talos/config`
- `~/.kube/config`

Follow:

- [overlays/lab/controller/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md)

### 9. Perform post-bootstrap actions

Examples:

- install Cilium
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
