# Talos Script Module

## Purpose

This directory contains the operational scripts used to install tooling, provision
Talos nodes, bootstrap Talos environments, and integrate Talos with the load
balancer used by the repository.

This README is the entrypoint for the module. Detailed execution steps are
documented in the guides linked below.

`install.sh` is a compatibility wrapper and delegates to
`infra-gitops/scripts/talos/install.sh`.

## Scripts In This Module

| Script                                     | Purpose                                                  | Notes                                                                         |
| ------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `cluster.sh`                               | Unified cluster lifecycle entrypoint                     | Actions: `generate`, `provision`, `apply-config`, `bootstrap`, `apply-cluster-config`, `install-addons`, `sync-access` |
| `install.sh`                               | Install or upgrade `talosctl`                            | Local or remote execution                                                     |
| `provision-single-node.sh`                 | Provision a non-HA Talos node                            | Thin wrapper over `overlays/base/scripts/talos/govc/provision-single-node.sh` |
| `provision-cluster.sh`                     | Provision a Talos cluster topology                       | Thin wrapper over `overlays/base/scripts/talos/govc/provision-cluster.sh`     |
| `cluster-bootstrap.sh`                     | Generate configs, apply configs, and bootstrap a cluster | Used after VMs are provisioned; auto-reconciles Talos LB and validates VIP kube-api |
| `phase-cluster-ready.sh`                  | Phase 1 orchestration: provision + bootstrap + validation | Includes kubeconfig artifact generation and CNI/proxy runtime checks           |
| `phase-network-bringup.sh`                | Phase 2 orchestration: render, validate, and install addon via Helm | Reusable for `--addon=cilium` and `--addon=argocd`                            |
| `cilium.sh`                               | Reusable Cilium lifecycle entrypoint                      | Wrapper over `phase-network-bringup.sh --addon=cilium`                         |
| `argocd.sh`                               | Reusable Argo CD lifecycle entrypoint                     | Wrapper over `phase-network-bringup.sh --addon=argocd`                         |
| `longhorn.sh`                             | Reusable Longhorn lifecycle entrypoint                    | Wrapper over `phase-network-bringup.sh --addon=longhorn`                       |
| `cert-manager.sh`                         | Reusable cert-manager lifecycle entrypoint                | Wrapper over `phase-network-bringup.sh --addon=cert-manager`                   |
| `prometheus-stack.sh`                     | Reusable kube-prometheus-stack lifecycle entrypoint       | Wrapper over `phase-network-bringup.sh --addon=prometheus-stack`               |
| `sync-kubectl.sh`                         | Sync local kubectl kubeconfig/context                     | Updates `~/.kube/config` from generated cluster kubeconfig                      |
| `sync-talosctl.sh`                        | Sync local talosctl config                                | Updates `~/.talos/config` with current endpoint and control-plane nodes         |
| `configure_load_balancer.sh`               | Configure HAProxy backends for Talos control planes      | Reuses the HAProxy module                                                     |
| `provision_and_configure_load_balancer.sh` | Provision HAProxy nodes and configure Talos backends     | Orchestration wrapper                                                         |
| `vars.sh`                                  | Module defaults                                          | Loaded from `overlays/base/scripts/vars.sh`                                   |

## Execution Model

The Talos module is split into two layers:

- Talos operations:
  - `cluster.sh`
  - `install.sh`
  - `cluster-bootstrap.sh`
  - `phase-cluster-ready.sh`
  - `phase-network-bringup.sh`
  - `cilium.sh`
  - `argocd.sh`
  - `sync-kubectl.sh`
  - `sync-talosctl.sh`
  - `configure_load_balancer.sh`
- VMware provisioning wrappers backed by `govc`:
  - `provision-single-node.sh`
  - `provision-cluster.sh`

The provisioning wrappers are intentionally small. They call the implementation in:

- `overlays/base/scripts/talos/govc/provision-single-node.sh`
- `overlays/base/scripts/talos/govc/provision-cluster.sh`

This means a user can stay in the Talos module for day-to-day usage, while still
knowing that VM creation depends on `govc`.
The cluster provisioning implementation (`talos/govc/provision-cluster.sh`)
also syncs owner-scoped DNS records (`owner=talos`) after create/destroy.
At the end of `phase-cluster-ready.sh`, local access is synchronized automatically
for `kubectl` and `talosctl` (disable with `--skip-sync-access`).

## Unified Entry Point

Use `cluster.sh` as the environment-agnostic orchestrator when you want one
stable CLI contract:

```bash
./overlays/base/scripts/talos/cluster.sh <action> [options]
```

Supported actions:

- `generate`
- `provision`
- `apply-config`
- `bootstrap`
- `apply-cluster-config`
- `install-addons`
- `sync-access`

Recommended execution order:

1. `generate`
2. `provision`
3. `apply-config`
4. `bootstrap`
5. `sync-access`
6. `apply-cluster-config`
7. `install-addons` (optional extras after baseline)

Why `apply-cluster-config` exists:

- `apply-config` is Talos machine configuration convergence (pre and post bootstrap).
- `apply-cluster-config` is Kubernetes baseline convergence (post bootstrap), for required components such as CNI and storage.
- This separation keeps strong cohesion:
  - Talos lifecycle in `cluster-bootstrap.sh`
  - Cluster baseline addons in `phase-network-bringup.sh` wrappers
  - Optional day-2 addons as separate steps

Important:

- `cluster.sh` reuses existing scripts. It does not replace module internals.
- You can pass `--vars-file=<path>` to target any overlay/project path without
  hard-coding `lab` or `prod`.

## Required Tools

These tools should be installed on the controller or workstation used to manage,
install, configure, and orchestrate Talos provisioning.

| Tool       | Required For                                                   | Notes                                                                           |
| ---------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `talosctl` | Config generation, apply, bootstrap, health checks, kubeconfig | Version should match Talos cluster version. Usually installed on the controller |
| `govc`     | Provisioning Talos VMs on ESXi or vSphere                      | Required for `provision-single-node.sh` and `provision-cluster.sh`              |
| `kubectl`  | Cluster validation after bootstrap                             | Usually installed on the controller                                             |
| `helm`     | Post-install add-ons such as Cilium                            | Usually installed on the controller                                             |

## Documentation Map

Use the document that matches your goal:

- [GETTING_STARTED.md](docs/GETTING_STARTED.md)
  - Start here if you are new to the module.
- [CLUSTER_GUIDE.md](docs/CLUSTER_GUIDE.md)
  - Use this for a Talos cluster with multiple control planes and workers.
- [LONGHORN_GUIDE.md](docs/LONGHORN_GUIDE.md)
  - Use this for Longhorn prerequisites, install, and values update flow.
- [HOWTO_ADD_WORKERS.md](docs/HOWTO_ADD_WORKERS.md)
  - Use this to scale worker nodes only on an existing cluster.
- [HOWTO_RECREATE_CLUSTER.md](docs/HOWTO_RECREATE_CLUSTER.md)
  - Use this to run a clean, reproducible cluster recreate flow.
- [ARGOCD_GITOPS_GUIDE.md](docs/ARGOCD_GITOPS_GUIDE.md)
  - Use this to move addon lifecycle ownership to Argo CD.
- [SINGLE_NODE_GUIDE.md](docs/SINGLE_NODE_GUIDE.md)
  - Use this for a non-HA Talos environment.
- [INFRASTRUCTURE_PLAN_EXAMPLE.md](docs/INFRASTRUCTURE_PLAN_EXAMPLE.md)
  - Use this to plan IPs, DNS, VIPs, VM names, and resource roles before execution.

For cluster-specific intent, continue using:

- [overlays/lab/talos/talos/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md)
- `overlays/lab/talos/talos/cluster-spec.yaml`

These files describe what a specific cluster should look like. This module
documents how to execute the workflow.

## Related Modules

- `infra-gitops/scripts/dnsmasq/README.md`
- `infra-gitops/scripts/talos/README.md`
- [HAProxy module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/README.md)
- [GOVC module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/govc/README.md)
- [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md)

## Recommended Reading Order

For a new Talos cluster:

1. Read [INFRASTRUCTURE_PLAN_EXAMPLE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md).
2. Read [GETTING_STARTED.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/GETTING_STARTED.md).
3. Follow [CLUSTER_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/CLUSTER_GUIDE.md).
4. Use [overlays/lab/talos/talos/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md) and `cluster-spec.yaml` for cluster-specific values.
