# Talos Infrastructure Plan Example

## Purpose

This document is a **deployment template plan** to complete before running
**Talos Linux** provisioning or cluster creation scripts.

Its goal is to make sure the user decides the **infrastructure layout first**,
instead of discovering missing values while scripts are already running.

## When To Use This Document

Use this document before:

- provisioning Talos VMs
- provisioning DNS
- provisioning HAProxy or Keepalived
- generating Talos cluster configuration

## Example Resource Table

| Resource         | Role             | IP              | DNS Needed | Load Balancer Relation                         | Source Image Or Template | Notes                                 |
| ---------------- | ---------------- | --------------- | ---------- | ---------------------------------------------- | ------------------------ | ------------------------------------- |
| `talos-dns-1`    | Dedicated DNS VM | `192.168.0.53`  | No         | Supports cluster by resolving names            | Ubuntu template          | Used when lab DNS is unreliable       |
| `talos-lb-1`     | HAProxy node 1   | `192.168.0.31`  | Yes        | Owns or serves the **VIP with Keepalived**     | Ubuntu OVA               | Fronts Kubernetes API                 |
| `talos-lb-2`     | HAProxy node 2   | `192.168.0.32`  | Yes        | Backup or peer for the VIP                     | Ubuntu OVA               | Fronts Kubernetes API                 |
| `talos-api`      | Cluster API VIP  | `192.168.0.30`  | Yes        | **Endpoint exposed by HAProxy and Keepalived** | N/A                      | Used by Talos and Kubernetes clients  |
| `talos-cp-1`     | Control plane    | `192.168.0.61`  | Yes        | Backend target behind HAProxy                  | Talos OVA                | Bootstrap node candidate              |
| `talos-cp-2`     | Control plane    | `192.168.0.62`  | Yes        | Backend target behind HAProxy                  | Talos OVA                | Joined during cluster creation        |
| `talos-cp-3`     | Control plane    | `192.168.0.63`  | Yes        | Backend target behind HAProxy                  | Talos OVA                | Joined during cluster creation        |
| `talos-worker-1` | Worker           | `192.168.0.71`  | Yes        | No direct LB role                              | Talos OVA                | Joined after control plane is healthy |
| `talos-worker-2` | Worker           | `192.168.0.72`  | Yes        | No direct LB role                              | Talos OVA                | Joined after control plane is healthy |
| `talos-worker-3` | Worker           | `192.168.0.73`  | Yes        | No direct LB role                              | Talos OVA                | Optional scale-out worker             |

## Example Planning Checklist

Before running scripts, confirm the following:

| Item                           | Decision                                                   |
| ------------------------------ | ---------------------------------------------------------- |
| Cluster name                   | `talos`                                                    |
| Cluster endpoint               | `https://192.168.0.30:6443`                                |
| Control-plane IPs              | `192.168.0.61,192.168.0.62,192.168.0.63`                   |
| Worker IPs                     | `192.168.0.71,192.168.0.72,192.168.0.73`                   |
| DNS server used by Talos nodes | `192.168.0.53`                                             |
| Load balancer VIP              | `192.168.0.30`                                             |
| Talos image source             | Talos OVA                                                  |
| Cluster CNI strategy           | Disable default Talos CNI, install Cilium later            |
| Controller host prepared       | `packer`, `govc`,  `talosctl`, `kubectl`, `helm` installed |

## Bootstrap Order - Checklist

Use the following order as a reference:

1. Finalize the resource table and network plan.
2. Prepare the controller tools.
3. Provision DNS if the lab does not provide reliable DNS.
4. Provision and configure the load balancer.
5. Provision Talos control planes and workers.
6. Generate Talos configuration.
7. Apply Talos configuration.
8. Bootstrap the cluster.
9. Configure kubeconfig and validate nodes.
10. Install post-bootstrap components such as Cilium.

## Related Documents

- [Talos module index](../talos/README.md)
- [Getting started](GETTING_STARTED.md)
- [Cluster guide](CLUSTER_GUIDE.md)
