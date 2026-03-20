# Talos Infrastructure Plan Example

## Purpose

This document is a human-friendly planning template to complete before running
Talos provisioning or cluster creation scripts.

Its goal is to make sure the user decides the infrastructure layout first,
instead of discovering missing values while scripts are already running.

## When To Use This Document

Use this document before:

- provisioning Talos VMs
- provisioning DNS
- provisioning HAProxy or Keepalived
- generating Talos cluster configuration

## Example Resource Table

| Resource | Role | IP | DNS Needed | Load Balancer Relation | Source Image Or Template | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `talos-dns-1` | Dedicated DNS VM | `192.168.0.53` | No | Supports cluster by resolving names | Ubuntu template | Used when lab DNS is unreliable |
| `talos-lb-1` | HAProxy node 1 | `192.168.0.243` | Yes | Owns or serves the VIP with Keepalived | Ubuntu template | Fronts Kubernetes API |
| `talos-lb-2` | HAProxy node 2 | `192.168.0.249` | Yes | Backup or peer for the VIP | Ubuntu template | Fronts Kubernetes API |
| `talos-api` | Cluster API VIP | `192.168.0.250` | Yes | Endpoint exposed by HAProxy and Keepalived | N/A | Used by Talos and Kubernetes clients |
| `talos-cp-1` | Control plane | `192.168.0.88` | Yes | Backend target behind HAProxy | Talos OVA | Bootstrap node candidate |
| `talos-cp-2` | Control plane | `192.168.0.89` | Yes | Backend target behind HAProxy | Talos OVA | Joined during cluster creation |
| `talos-cp-3` | Control plane | `192.168.0.90` | Yes | Backend target behind HAProxy | Talos OVA | Joined during cluster creation |
| `talos-worker-1` | Worker | `192.168.0.91` | Yes | No direct LB role | Talos OVA | Joined after control plane is healthy |
| `talos-worker-2` | Worker | `192.168.0.92` | Yes | No direct LB role | Talos OVA | Joined after control plane is healthy |
| `talos-worker-3` | Worker | `192.168.0.93` | Yes | No direct LB role | Talos OVA | Optional scale-out node |

## Example Planning Checklist

Before running scripts, confirm the following:

| Item | Decision |
| --- | --- |
| Cluster name | `talos` |
| Cluster endpoint | `https://192.168.0.250:6443` |
| Control-plane IPs | `192.168.0.88,192.168.0.89,192.168.0.90` |
| Worker IPs | `192.168.0.91,192.168.0.92,192.168.0.93` |
| DNS server used by Talos nodes | `192.168.0.53` |
| Load balancer VIP | `192.168.0.250` |
| Talos image source | Talos OVA |
| Cluster CNI strategy | Disable default Talos CNI, install Cilium later |
| Controller host prepared | `talosctl`, `kubectl`, `helm` installed |

## Example Bootstrap Order

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

- [Talos module index](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/README.md)
- [Getting started](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/GETTING_STARTED.md)
- [Cluster guide](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/CLUSTER_GUIDE.md)
