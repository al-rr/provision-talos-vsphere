# Talos Module Getting Started

## Purpose

This guide is the starting point for users who are new to the Talos automation in
this repository.

It explains:

- what the Talos module is responsible for
- which external tools are required
- which infrastructure should exist before cluster creation
- which guide to follow next

## What This Module Does

The Talos module covers four main areas:

- installing `talosctl`
- provisioning Talos VMs through `govc` wrappers
- generating and applying Talos machine configuration
- integrating Talos control planes with the load balancer

The module does not try to be the source of truth for one specific cluster design.
Cluster intent belongs in the cluster workspace, such as:

- [overlays/lab/talos/talos/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md)
- `overlays/lab/talos/talos/cluster-spec.yaml`

## Minimum Prerequisites

| Tool | Why You Need It | Where To Read More |
| --- | --- | --- |
| `talosctl` | Generate configs, apply configs, bootstrap, inspect nodes | [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md) |
| `govc` | Provision VMs on ESXi or vSphere | [GOVC module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/govc/README.md) |
| `kubectl` | Validate the cluster after bootstrap | [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md) |
| `helm` | Install post-bootstrap components such as Cilium | [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md) |

**Important compatibility note:**

- `talosctl` should stay on the same major and minor version as the Talos nodes.
- In practice, using the same version tag is the safest option.

## Infrastructure You Should Plan First

Before running cluster scripts, define the environment in writing.

At minimum, decide:

- cluster name
- control-plane IPs
- worker IPs
- cluster API endpoint
- whether the endpoint is fronted by a load balancer VIP
- whether a dedicated DNS VM is required
- OVA/template source used for the VMs (pre-existing or built separately)

Provisioning note:

- Day-1 cluster provisioning should run with `govc`/Terraform against an
  already available OVA/template source.
- If you need a custom image, run the Packer workflow separately first.

Use this planning document first:

- [INFRASTRUCTURE_PLAN_EXAMPLE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md)

## Recommended Order

For a new Talos cluster, the recommended order is:

1. Prepare the infrastructure plan.
2. Prepare the controller tools (`talosctl`, `kubectl`, `helm`).
3. Provision DNS if the lab has no reliable DNS.
4. Provision or validate the load balancer if the cluster uses a VIP.
5. Provision Talos VMs.
6. Generate Talos configuration.
7. Apply Talos configuration.
8. Bootstrap the cluster.
9. Configure kubeconfig and validate the cluster.
10. Proceed with post-bootstrap components such as Cilium.

For exact commands in canonical order, follow:

- [LAB_DAY1_RUNBOOK.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/LAB_DAY1_RUNBOOK.md)

## Where To Go Next

Choose the guide that matches your deployment:

- [CLUSTER_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/CLUSTER_GUIDE.md)
  - For a Talos cluster with multiple control planes and workers.
- [SINGLE_NODE_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/SINGLE_NODE_GUIDE.md)
  - For a non-HA Talos environment.

Supporting modules:

- `infra-gitops/scripts/dnsmasq/README.md`
- [HAProxy](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/README.md)
- [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md)

Operational how-tos:

- [HOWTO_ADD_WORKERS.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/HOWTO_ADD_WORKERS.md)
- [HOWTO_RECREATE_CLUSTER.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/HOWTO_RECREATE_CLUSTER.md)
