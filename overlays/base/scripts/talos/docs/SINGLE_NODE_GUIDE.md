# Talos Single-Node Guide

## Purpose

This guide describes how to use the Talos module for a non-HA Talos deployment.

This mode is useful when you want:

- a smaller lab environment
- a simpler validation flow
- no control-plane load balancer
- a reduced infrastructure footprint

## How This Differs From A Cluster

Compared with the cluster flow:

- only one Talos node is provisioned
- a load balancer VIP is usually not required
- multiple control planes are not used
- worker nodes are not required
- operational complexity is lower

## Minimum Requirements

| Item | Why It Matters |
| --- | --- |
| `talosctl` | Required to interact with the node |
| `govc` | Required if provisioning the node on ESXi or vSphere |
| Single-node plan | You still need a hostname, IP, and image source |

## Recommended Execution Order

### 1. Prepare the controller tools

Follow:

- [overlays/lab/controller/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md)

### 2. Prepare the environment plan

Even for a single-node deployment, define:

- VM name
- node IP
- gateway
- DNS server
- image source

Use:

- [INFRASTRUCTURE_PLAN_EXAMPLE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md)

### 3. Provision the Talos node

Provisioning entrypoint:

```bash
./overlays/base/scripts/talos/provision-single-node.sh --env=lab create
```

Important note:

- This script is a wrapper over `overlays/base/scripts/talos/govc/provision-single-node.sh`.
- It depends on `govc`.

### 4. Continue with Talos configuration

If the single-node environment needs further Talos configuration or validation,
use `talosctl` directly with the generated Talos configuration and kubeconfig
workflow documented in the controller guide.

## When To Prefer Single-Node

Single-node is a good fit when:

- you want to validate scripts quickly
- you do not need HA behavior
- you are testing base Talos behavior before a cluster build

If you need:

- multiple control planes
- worker scaling
- a stable API endpoint through a VIP
- production-like topology

then use:

- [CLUSTER_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/CLUSTER_GUIDE.md)

## Related Documents

- [Talos module index](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/README.md)
- [Getting started](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/GETTING_STARTED.md)
