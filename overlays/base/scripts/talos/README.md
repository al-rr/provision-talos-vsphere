# Talos Script Module

## Purpose

This directory contains the operational scripts used to install tooling, provision
Talos nodes, bootstrap Talos environments, and integrate Talos with the load
balancer used by the repository.

This README is the entrypoint for the module. Detailed execution steps are
documented in the guides linked below.

## Scripts In This Module

| Script                                     | Purpose                                                  | Notes                                                                         |
| ------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `install.sh`                               | Install or upgrade `talosctl`                            | Local or remote execution                                                     |
| `provision-single-node.sh`                 | Provision a non-HA Talos node                            | Thin wrapper over `overlays/base/scripts/talos/govc/provision-single-node.sh` |
| `provision-cluster.sh`                     | Provision a Talos cluster topology                       | Thin wrapper over `overlays/base/scripts/talos/govc/provision-cluster.sh`     |
| `cluster-bootstrap.sh`                     | Generate configs, apply configs, and bootstrap a cluster | Used after VMs are provisioned                                                |
| `configure_load_balancer.sh`               | Configure HAProxy backends for Talos control planes      | Reuses the HAProxy module                                                     |
| `provision_and_configure_load_balancer.sh` | Provision HAProxy nodes and configure Talos backends     | Orchestration wrapper                                                         |
| `vars.sh`                                  | Module defaults                                          | Loaded from `overlays/base/scripts/vars.sh`                                   |

## Execution Model

The Talos module is split into two layers:

- Talos operations:
  - `install.sh`
  - `cluster-bootstrap.sh`
  - `configure_load_balancer.sh`
- VMware provisioning wrappers backed by `govc`:
  - `provision-single-node.sh`
  - `provision-cluster.sh`

The provisioning wrappers are intentionally small. They call the implementation in:

- `overlays/base/scripts/talos/govc/provision-single-node.sh`
- `overlays/base/scripts/talos/govc/provision-cluster.sh`

This means a user can stay in the Talos module for day-to-day usage, while still
knowing that VM creation depends on `govc`.

## Required Tools

| Tool       | Required For                                                   | Notes                                                              |
| ---------- | -------------------------------------------------------------- | ------------------------------------------------------------------ |
| `talosctl` | Config generation, apply, bootstrap, health checks, kubeconfig | Version should match Talos cluster version                         |
| `govc`     | Provisioning Talos VMs on ESXi or vSphere                      | Required for `provision-single-node.sh` and `provision-cluster.sh` |
| `kubectl`  | Cluster validation after bootstrap                             | Usually installed on the controller                                |
| `helm`     | Post-install add-ons such as Cilium                            | Usually installed on the controller                                |

## Documentation Map

Use the document that matches your goal:

- [GETTING_STARTED.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/GETTING_STARTED.md)
  - Start here if you are new to the module.
- [CLUSTER_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/CLUSTER_GUIDE.md)
  - Use this for a Talos cluster with multiple control planes and workers.
- [SINGLE_NODE_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/SINGLE_NODE_GUIDE.md)
  - Use this for a non-HA Talos environment.
- [INFRASTRUCTURE_PLAN_EXAMPLE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md)
  - Use this to plan IPs, DNS, VIPs, VM names, and resource roles before execution.

For cluster-specific intent, continue using:

- [overlays/lab/talos/talos/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md)
- `overlays/lab/talos/talos/cluster-spec.yaml`

These files describe what a specific cluster should look like. This module
documents how to execute the workflow.

## Related Modules

- [DNS module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/dns/README.md)
- [HAProxy module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/README.md)
- [GOVC module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/govc/README.md)
- [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md)

## Recommended Reading Order

For a new Talos cluster:

1. Read [INFRASTRUCTURE_PLAN_EXAMPLE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md).
2. Read [GETTING_STARTED.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/GETTING_STARTED.md).
3. Follow [CLUSTER_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/CLUSTER_GUIDE.md).
4. Use [overlays/lab/talos/talos/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md) and `cluster-spec.yaml` for cluster-specific values.
