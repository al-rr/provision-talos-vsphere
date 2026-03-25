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

## Patch Generation Model

During `cluster-bootstrap.sh`, patch files are rendered from overlay variables.

- `bootstrap.patch.yaml` is generated from `TALOS_NAMESERVERS` and bootstrap DNS/hostDNS/time flags.
- `talos-cp-<n>.patch.yaml` and `talos-worker-<n>.patch.yaml` are generated from:
  - `TALOS_CONTROL_PLANE_IPS` / `TALOS_WORKER_IPS`
  - `TALOS_NODE_INTERFACE`
  - `TALOS_GATEWAY`
  - `TALOS_NETMASK_PREFIX`

Do not treat those generated files as long-term manual edit targets.
Keep desired values in overlay vars and rerun the workflow.

## Talos Lifecycle (Apply Before And After Bootstrap)

Core Talos sequence:

1. Generate configs
2. Apply config to nodes
3. Bootstrap one control-plane node (one-time operation)

Talosctl action name before and after bootstrap:

- The command is the same: `talosctl apply-config`.
- What changes is the intent:
  - pre-bootstrap: initial machine configuration convergence
  - post-bootstrap: re-convergence after patch changes

Important:

- `apply-config` is not a one-time action.
- It is used before bootstrap and can be used again after bootstrap whenever
  configuration changes are required.
- In other words, apply is a convergence action that may run multiple times.

### Patch Phase Matrix

Bootstrap-time patches (Day-1 apply before bootstrap):

- `bootstrap.patch.yaml`
- `cp-bootstrap.patch.yaml` (control-plane only)
- `worker-bootstrap.patch.yaml` (worker only)
- `talos-cp-<n>.patch.yaml`
- `talos-worker-<n>.patch.yaml`
- `cni.patch.yaml` (only when `TALOS_DISABLE_DEFAULT_CNI=true`)

Post-bootstrap patches (runtime/final-state intent):

- `cp.patch.yaml` (control-plane runtime settings)
- `worker.patch.yaml` (worker runtime settings)

Current behavior note:

- The bootstrap patch chain is applied by current scripts.
- Runtime patch application should be executed as a post-bootstrap apply step
  when those files are used as final-state overrides.

## What Each Script Actually Does

### `cluster.sh`

Unified entrypoint that orchestrates existing module scripts with explicit
actions:

- `generate`
- `provision`
- `apply-config`
- `bootstrap`
- `apply-cluster-config`
- `install-addons`
- `sync-access`

Recommended `cluster.sh` execution order:

1. `generate`
2. `provision`
3. `apply-config`
4. `bootstrap`
5. `sync-access`
6. `apply-cluster-config`
7. `install-addons` (optional extras)

It supports `--vars-file` so cluster generation/provisioning can target any
path (for example `overlays/lab/...` or `overlays/prod/...`) without changing
script internals.

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
2. Phase 1.5: Post-bootstrap baseline (`apply-cluster-config`)
3. Phase 2: Network Bring-up (optional extras)
4. Phase 3: GitOps handoff (Argo CD as source of truth)

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

## Phase 1.5: Post-Bootstrap Baseline

This phase installs the minimum required components after Talos bootstrap so the
cluster becomes operational for workloads.

Default:

- `cilium` (required when `TALOS_DISABLE_DEFAULT_CNI=true`)

Optional baseline extension:

- `longhorn` (if storage must be baseline in your project)

Command:

```bash
./overlays/base/scripts/talos/cluster.sh apply-cluster-config --env=lab
```

With explicit list:

```bash
./overlays/base/scripts/talos/cluster.sh apply-cluster-config --env=lab --addons='["cilium","longhorn"]'
```

Important:

- `apply-config` and `apply-cluster-config` are different steps:
  - `apply-config`: Talos machine config (`talosctl apply-config`)
  - `apply-cluster-config`: post-bootstrap Kubernetes baseline addons

## Phase 2: Network Bring-up (Optional Extras)

If Cilium was not installed in Phase 1.5, install it first:

```bash
./overlays/base/scripts/talos/cilium.sh --env=lab
```

Then install optional extras such as Argo CD:

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
