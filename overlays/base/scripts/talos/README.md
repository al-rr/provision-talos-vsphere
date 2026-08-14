# Talos Script Module

## Purpose

This directory contains the operational scripts used to install tooling, provision
Talos nodes, bootstrap Talos environments, and integrate Talos with the load
balancer used by the repository.

This README is the entrypoint for the module. Detailed execution steps are
documented in the guides linked below.

`install.sh` is a compatibility wrapper and delegates to
`infra-gitops/scripts/talos/install.sh`.

## Canonical Talos Lifecycle: cluster-toolchain.sh / talos-gitops-toolchain.sh

Generic Talos day-1/day-2 lifecycle behavior is owned by `talos-toolchain`,
not by this repository. This module's canonical entrypoints forward to the
external `talos-toolchain` checkout:

- `cluster-toolchain.sh` -> `<toolchain>/scripts/talos/cluster.sh`
- `talos-gitops-toolchain.sh` -> `<toolchain>/scripts/talos/talos-gitops.sh`

`cluster.sh` and `talos-gitops.sh` in this directory are deprecated
compatibility shims that print a warning and forward every argument to the
wrappers above unchanged. They exist only so a caller that has not migrated
yet keeps working; new usage should call `cluster-toolchain.sh` /
`talos-gitops-toolchain.sh` directly. They will be removed once no
documented workflow in this repository references them.

Default toolchain location:

- `cluster-toolchain.sh`: sibling checkout (`../talos-toolchain` relative to
  this repository root), matching the standard `talos-projects` workspace
  layout.
- `talos-gitops-toolchain.sh`: `/home/vagrant/talos-toolchain` (lab
  controller path).

Override with:

- env var `TALOS_TOOLCHAIN_DIR`
- or `--toolchain-dir=<path>`

Examples:

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh create-project --project-dir=overlays/lab/talos/talos-dev
./overlays/base/scripts/talos/talos-gitops-toolchain.sh install-platform-helm --kube-context=admin@talos-dev --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

## Scripts In This Module

| Script                                     | Purpose                                                  | Notes                                                                         |
| ------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `cluster-toolchain.sh`                     | Canonical day-1 entrypoint: delegates to `talos-toolchain`'s `cluster.sh` | Actions: `create-project`, `generate`, `provision`, `prepare-bootstrap`, `apply-config`, `bootstrap`, `apply-post-bootstrap`, `sync-access`, `refresh-schematics` |
| `talos-gitops-toolchain.sh`                | Canonical day-2 entrypoint: delegates to `talos-toolchain`'s `talos-gitops.sh` | Installs platform helms, deploys Argo CD root app, configures cluster tools   |
| `cluster.sh`                               | Deprecated shim for `cluster-toolchain.sh`               | Forwards all arguments unchanged; prints a deprecation warning; kept for the rollback window |
| `talos-gitops.sh`                          | Deprecated shim for `talos-gitops-toolchain.sh`          | Forwards all arguments unchanged; prints a deprecation warning; kept for the rollback window |
| `install.sh`                               | Install or upgrade `talosctl`                            | Local or remote execution                                                     |
| `provision-single-node.sh`                 | Provision a non-HA Talos node                            | Thin wrapper over `overlays/base/scripts/talos/govc/provision-single-node.sh` |
| `provision-cluster.sh`                     | Provision a Talos cluster topology                       | Thin wrapper over `overlays/base/scripts/talos/govc/provision-cluster.sh`     |
| `cluster-bootstrap.sh`                     | Generate configs, apply configs, and bootstrap a cluster | Superseded by `cluster-toolchain.sh` for the standard flow; retained only because `docs/HOWTO_ADD_WORKERS.md` still calls it directly for a targeted `--worker-ips=<ips>` re-apply that `cluster-toolchain.sh apply-config` does not expose |
| `phase-cluster-ready.sh`                  | Phase 1 orchestration: provision + bootstrap + validation | Retained: still the implementation behind `cluster-bootstrap.sh` above, not a standalone toolchain duplicate to remove |
| `phase-network-bringup.sh`                | Phase 2 orchestration: render, validate, and install addon via Helm | Retained: still the implementation behind `cilium.sh`, `argocd.sh`, `longhorn.sh`, `cert-manager.sh`, `prometheus-stack.sh` below, none of which have a `talos-toolchain` equivalent (only bulk `apply-post-bootstrap --addons=[...]` exists there) |
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
  - `cluster-toolchain.sh` (canonical; `cluster.sh` is a deprecated shim for it)
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

Use `cluster-toolchain.sh` as the project-oriented orchestrator with one
stable CLI contract — the same contract `talos-toolchain/scripts/talos/cluster.sh`
defines, since this wrapper forwards to it directly:

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh <action> [options]
```

Supported actions:

- `create-project`
- `generate`
- `provision`
- `prepare-bootstrap`
- `apply-config`
- `bootstrap`
- `apply-post-bootstrap`
- `sync-access`
- `refresh-schematics`

There is no local command-hook indirection (no per-project `TALOS_DAY1_*`
mapped-command variables): `cluster-toolchain.sh` forwards every action
straight to `talos-toolchain`'s own implementation of each action. That
older indirection existed only in the now-deprecated local `cluster.sh` shim
and was a deliberate roadmap decision not to port back into
`talos-toolchain`.

Recommended execution order:

0. `create-project`
1. `generate`
2. `provision`
3. `prepare-bootstrap`
4. `bootstrap`
5. `apply-config` (post-bootstrap convergence, when needed)
6. `sync-access`
7. `apply-post-bootstrap`

ISO mode note:

- ISO boot starts with DHCP addresses.
- `provision` captures bootstrap addresses in `generated/bootstrap-ips.txt`.
- `prepare-bootstrap` automatically discovers and consumes that inventory before nodes switch to static IPs.

Factory image note:

- `generate` auto-refreshes schematics when `TALOS_CONTROL_PLANE_INSTALLER_IMAGE` or `TALOS_WORKER_INSTALLER_IMAGE` is missing/invalid.
- `refresh-schematics` is still available when you explicitly want to rotate/update image IDs before generate.

Installer image strategy (control-plane vs worker):

- `TALOS_CONTROL_PLANE_INSTALLER_IMAGE` is for control-plane nodes.
- `TALOS_WORKER_INSTALLER_IMAGE` is for worker nodes.
- This repository keeps them separated by design, so worker nodes can carry
  workload/storage-specific requirements (for example Longhorn/CSI evolution)
  without coupling those choices to control-plane/etcd nodes.
- If one value is not explicitly set, scripts fall back to `TALOS_INSTALLER_IMAGE`
  for compatibility.

Why `apply-post-bootstrap` exists:

- `apply-config` is Talos machine configuration convergence (pre and post bootstrap).
- `prepare-bootstrap` may use `talosctl apply-config --insecure` for initial node contact.
- `apply-config` after prep uses talosconfig/TLS only (no insecure fallback).
- HAProxy backend reconciliation runs in `prepare-bootstrap` (`--apply-stage=pre`) and is not repeated in `bootstrap`.
- `apply-post-bootstrap` is Kubernetes baseline convergence (post bootstrap), for required components such as CNI and storage.
- `apply-post-bootstrap` prints follow-up `kubectl` watch commands because immediate validation snapshots can still show transient `Pending/NotReady`.
- It can automatically sync day-1 helm manifests into `<project-dir>/helm` from the source declared in project vars.
- This separation keeps strong cohesion:
  - Talos lifecycle delegated to `talos-toolchain` via `cluster-toolchain.sh`
  - Cluster baseline addons in `phase-network-bringup.sh` wrappers (local, no
    toolchain equivalent for standalone per-addon apply)
  - Day-2 GitOps operations delegated to `talos-toolchain` via
    `talos-gitops-toolchain.sh`
- In day-2, `talos-gitops-toolchain.sh install-platform-helm` excludes
  `cilium` by default. This protects the day-1 CNI baseline from accidental
  broad reapply; use `--addons` and `--exclude-addons` to control exactly
  what should run. Use `talos-gitops-toolchain.sh install-addon --addon=<name>`
  for one-addon iterative tests without applying the whole platform set.
  System exclusions are always enforced and merged with user exclusions.
- In day-2, `talos-gitops-toolchain.sh` requires `--kube-context=<name>` to
  ensure commands run against the intended cluster context.

Important:

- `cluster-toolchain.sh` reuses `talos-toolchain`'s implementation; it does
  not replace or duplicate module internals.
- Preferred mode is `--project-dir=<path>`.
- `--vars-file=<path>` remains available for advanced/manual flows.
- `--env` is removed from the underlying `cluster.sh` contract; use
  `--project-dir` instead.
- `apply-post-bootstrap` is still a first-class day-1 action, dispatched
  through `cluster-toolchain.sh` like every other action above.

## Optional Global Command

If you want to run the CLIs from any directory, create symlinks in
`/usr/local/bin`.

Create/update symlink:

```bash
sudo ln -sf /home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/cluster-toolchain.sh /usr/local/bin/talos-cluster
sudo ln -sf /home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/talos-gitops-toolchain.sh /usr/local/bin/talos-gitops
sudo chmod +x /home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/cluster-toolchain.sh
sudo chmod +x /home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/talos-gitops-toolchain.sh
```

Validate:

```bash
talos-cluster --help
talos-gitops --help
```

Remove symlink:

```bash
sudo rm -f /usr/local/bin/talos-cluster
sudo rm -f /usr/local/bin/talos-gitops
```

Without `sudo` (user-local path):

```bash
mkdir -p ~/.local/bin
ln -sf /home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/cluster-toolchain.sh ~/.local/bin/talos-cluster
ln -sf /home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/talos-gitops-toolchain.sh ~/.local/bin/talos-gitops
# ensure ~/.local/bin is in PATH
```

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
- [LAB_DAY1_RUNBOOK.md](docs/LAB_DAY1_RUNBOOK.md)
  - Canonical lab day-1 execution order (DNS -> LB -> Talos lifecycle).
- [CLUSTER_GUIDE.md](docs/CLUSTER_GUIDE.md)
  - Use this for a Talos cluster with multiple control planes and workers.
- [LONGHORN_GUIDE.md](docs/LONGHORN_GUIDE.md)
  - Use this for Longhorn prerequisites, install, and values update flow.
- [CERT_MANAGER_GUIDE.md](docs/CERT_MANAGER_GUIDE.md)
  - Use this for cert-manager install/upgrade and validation flow.
- [PROMETHEUS_STACK_GUIDE.md](docs/PROMETHEUS_STACK_GUIDE.md)
  - Use this for kube-prometheus-stack install/upgrade, validation, and UI access.
- [HOWTO_ADD_WORKERS.md](docs/HOWTO_ADD_WORKERS.md)
  - Use this to scale worker nodes only on an existing cluster.
- [HOWTO_RECREATE_CLUSTER.md](docs/HOWTO_RECREATE_CLUSTER.md)
  - Use this to run a clean, reproducible cluster recreate flow.
- [ARGOCD_GITOPS_GUIDE.md](docs/ARGOCD_GITOPS_GUIDE.md)
  - Use this to move addon lifecycle ownership to Argo CD.
  - Includes UI access instructions via `kubectl port-forward` (Argo CD,
    Longhorn, Grafana, Prometheus, Alertmanager).
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
