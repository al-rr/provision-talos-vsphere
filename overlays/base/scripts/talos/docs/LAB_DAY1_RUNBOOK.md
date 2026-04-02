# Lab Day-1 Runbook (Canonical)

## Purpose

This is the canonical execution order for a new lab cluster in this repository.

It answers:

- which infrastructure components must exist first
- which scripts to run, and in which order
- where DNS and load balancer fit into Talos bootstrap

## Scope

This runbook is for `talos-vsphere-lab` lab flow on VMware/ESXi.

- DNS module here is lab-oriented.
- HAProxy/Keepalived here is the integration wrapper layer.
- Talos lifecycle is executed via `cluster-toolchain.sh` (day-1).

## Prerequisites

1. Controller has required CLIs: `govc`, `talosctl`, `kubectl`, `helm`.
2. vSphere variables are defined in your project (`vars.sh` + `vars.local.sh`).
3. You already know:

- cluster name
- control-plane IPs
- worker IPs
- API endpoint
- LB VIP (if using LB)

## Required Infrastructure Before Talos

### 1. DNS (lab)

Use DNS module when lab DNS is not already available/reliable.

```bash
./overlays/base/scripts/dns/run-full.sh --env=lab
```

If DNS is already operational in your lab, skip this step.

### 2. Load Balancer + VIP (HAProxy + Keepalived)

Use the LB wrapper action for full lab orchestration:

```bash
./overlays/base/scripts/ha-proxy/haproxy-lb.sh configure-vip --env=lab --overwrite
```

This executes the full LB workflow (provision/configure/hardening/keepalived)
through `run-full.sh` in the lab integration layer.

You can validate the LB module state:

```bash
./overlays/base/scripts/ha-proxy/haproxy-lb.sh validate --env=lab
./overlays/base/scripts/ha-proxy/haproxy-lb.sh status --env=lab
```

## Talos Day-1 (Project Lifecycle)

Use one project directory, for example `overlays/lab/talos/talos-dev`.

### 1. Create project

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh create-project --project-dir=overlays/lab/talos/talos-dev
```

### 2. Fill local overrides

Edit:

- `overlays/lab/talos/talos-dev/vars.local.sh`

Set environment-specific values (credentials, IPs, endpoint, VIP references).

### 3. Generate configs

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh generate --project-dir=overlays/lab/talos/talos-dev
```

### 4. Provision VMs

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh provision --project-dir=overlays/lab/talos/talos-dev
```

### 5. Prepare bootstrap

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh prepare-bootstrap --project-dir=overlays/lab/talos/talos-dev
```

Notes:

- In ISO scenarios, this phase handles DHCP discovery inventory.
- HAProxy backend reconciliation for control-plane endpoints runs in this phase.

### 6. Bootstrap cluster

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh bootstrap --project-dir=overlays/lab/talos/talos-dev
```

### 7. Apply config (post-bootstrap convergence when needed)

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh apply-config --project-dir=overlays/lab/talos/talos-dev
```

### 8. Sync local access

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh sync-access --project-dir=overlays/lab/talos/talos-dev
```

### 9. Apply baseline post-bootstrap addons (day-1.5)

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh apply-post-bootstrap --project-dir=overlays/lab/talos/talos-dev
```

## Validation Checkpoints

After `bootstrap` and `sync-access`:

```bash
kubectl get nodes -o wide
```

After `apply-post-bootstrap`:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -w
kubectl get nodes -w
```

## Day-2 Handoff

After day-1 is stable, continue with:

- `talos-gitops-toolchain.sh` for platform helm/apps and Argo CD handoff.

Related:

- [ARGOCD_GITOPS_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/ARGOCD_GITOPS_GUIDE.md)
