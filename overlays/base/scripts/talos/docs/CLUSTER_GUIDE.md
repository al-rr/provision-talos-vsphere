# Talos Cluster Guide

## Purpose

This is the operational runbook to create and evolve a Talos cluster in this
repository.

This guide is intentionally explicit about execution order and script scope.

## Scope And Source Of Truth

Use this guide together with:

- [Talos module README](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/README.md)
- [Lab cluster blueprint](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md)
- `overlays/lab/talos/talos/cluster-spec.yaml`

`cluster-spec.yaml` is the cluster intent source of truth (IPs, counts,
endpoint, CNI strategy). This guide is the execution runbook.

## What Each Script Actually Does

### `phase-cluster-ready.sh`

`phase-cluster-ready.sh` is **Phase 1 orchestration**. It is not partial.
By default, it runs:

1. VM provisioning (control planes + workers from env vars)
2. Talos bootstrap flow (`cluster-bootstrap.sh --mode=all`)
3. kubeconfig artifact generation
4. local access sync (`kubectl` + `talosctl`)
5. validation

Default command:

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab
```

Control-plane-only command:

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab --worker-count=0
```

### `phase-network-bringup.sh`

Phase 2 orchestration for addons via Helm wrappers (`cilium`, `argocd`,
`longhorn`, etc.).

### `cluster-bootstrap.sh`

Low-level Talos Day-1 script (`generate`, `apply`, `bootstrap`, `all`). Use it
for controlled reruns and recovery flows.

### `provision-cluster.sh`

Low-level VM provisioning wrapper over `govc`. Use it for selective VM actions
such as create only workers.

## Recommended Execution Order (Strict)

Execute in this order for reproducible runs:

1. Phase 1: Cluster Ready
2. Phase 2: Network Bring-up
3. Phase 3: GitOps handoff (Argo CD as source of truth)

## Phase 1: Cluster Ready

### Standard run

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab
```

### Control-plane-only run

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab --worker-count=0
```

### Important behavior when `TALOS_DISABLE_DEFAULT_CNI=true`

If Talos default CNI is disabled (`cni: none`), this is expected:

- Kubernetes API becomes reachable
- Nodes remain `NotReady` until Cilium (or another CNI) is installed

This does not block moving to Phase 2.

## Phase 2: Network Bring-up

Run Cilium first:

```bash
./overlays/base/scripts/talos/cilium.sh --env=lab
```

Then Argo CD (if desired in Phase 2):

```bash
./overlays/base/scripts/talos/argocd.sh --env=lab
```

Render-only validation example:

```bash
./overlays/base/scripts/talos/cilium.sh --env=lab --render-only
```

## Phase 3: GitOps Handoff

After network is stable:

1. Install/validate Argo CD
2. Apply root app / app-of-apps
3. Move day-2 addon changes to Git-only workflow (PR/merge)

## OVA vs ISO: How To Choose

Provisioning supports both modes.

Selection rule used by `talos/govc/provision-cluster.sh`:

- If `TALOS_OVA_PATH` (or `--ova-path`) is set: **OVA mode is used**
- Otherwise: **ISO mode is used** (`TALOS_ISO_DATASTORE_PATH` / `--iso-path`)

Practical recommendation:

- Use OVA for current lab flow (faster/consistent with this repo)
- Use ISO when you explicitly need ISO lifecycle behavior

## How To Create Only Workers

`phase-cluster-ready.sh` is for full Phase 1 orchestration. For workers-only,
use low-level provisioning.

### Worker-only VM create (existing cluster)

```bash
./overlays/base/scripts/talos/provision-cluster.sh \
  --env=lab \
  --cp-count=0 \
  --worker-count=<n> \
  create
```

Notes:

- This is intended for an already bootstrapped cluster.
- Worker machine config must already match the target cluster/secrets
  (typically from `overlays/<env>/talos/<cluster>/generated/worker.yaml`).
- Do not run cluster bootstrap again for worker scale-out.

## Recovery / Controlled Reruns

### Clean recreate (destroy + reset generated + recreate)

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab --clean-recreate
```

### Generate/apply/bootstrap split (advanced)

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=generate
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=apply
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=bootstrap
```

## Validation Checklist

After Phase 1:

- `kubectl get nodes -o wide`
- `talosctl get members`
- `talosctl get machineconfig -o yaml` (verify expected network/CNI settings)

After Phase 2 (Cilium):

- `kubectl -n kube-system get pods -l k8s-app=cilium`
- `kubectl get nodes`

## Related Documents

- [GETTING_STARTED.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/GETTING_STARTED.md)
- [LONGHORN_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/LONGHORN_GUIDE.md)
- [ARGOCD_GITOPS_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/ARGOCD_GITOPS_GUIDE.md)
- [HOWTO_ADD_WORKERS.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/HOWTO_ADD_WORKERS.md)
- [HOWTO_RECREATE_CLUSTER.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/HOWTO_RECREATE_CLUSTER.md)
- [INFRASTRUCTURE_PLAN_EXAMPLE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md)
