# Talos Cluster Guide

## Purpose

This is the operational runbook to create and evolve a Talos cluster in this
repository.

This guide is intentionally explicit about execution order and script scope.

If you want a single canonical command flow for lab day-1, use:

- [LAB_DAY1_RUNBOOK.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/LAB_DAY1_RUNBOOK.md)

## Execution Entry Points (Transition)

Current recommendation during toolchain migration:

- Day-1: use `cluster-toolchain.sh`
- Day-2: use `talos-gitops-toolchain.sh`

Those wrappers delegate to external `talos-toolchain` scripts and keep this
repository as the integration layer.

Examples:

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh create-project --project-dir=overlays/lab/talos/talos-dev
./overlays/base/scripts/talos/cluster-toolchain.sh generate --project-dir=overlays/lab/talos/talos-dev
./overlays/base/scripts/talos/talos-gitops-toolchain.sh install-platform-helm --kube-context=admin@talos-dev --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

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

ISO-specific pre-bootstrap behavior:

- In ISO mode, nodes initially boot with DHCP addresses.
- The provisioning step writes those temporary addresses to:
  - `generated/bootstrap-ips.txt`
- The apply phase automatically prefers that inventory for `talosctl apply-config`.
- After apply, nodes converge to the static addresses from `TALOS_CONTROL_PLANE_IPS` and `TALOS_WORKER_IPS`.

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

- `create-project`
- `generate`
- `provision`
- `prepare-bootstrap`
- `apply-config`
- `bootstrap`
- `apply-post-bootstrap`
- `sync-access`

Recommended `cluster.sh` execution order:

0. `create-project`
1. `generate`
2. `provision`
3. `prepare-bootstrap`
4. `bootstrap`
5. `apply-config` (post-bootstrap convergence, when needed)
6. `sync-access`
7. `apply-post-bootstrap`

`cluster.sh` is project-dir first:

- Use `--project-dir=<path-to-cluster-project>` in normal operation.
- `--vars-file` remains available for manual/advanced flows.
- `--env` is removed from `cluster.sh`.

Day-1 action mapping contract in project vars:

- `TALOS_DAY1_GENERATE_CMD`
- `TALOS_DAY1_PROVISION_CMD`
- `TALOS_DAY1_PREPARE_BOOTSTRAP_CMD`
- `TALOS_DAY1_APPLY_CONFIG_CMD`
- `TALOS_DAY1_BOOTSTRAP_CMD`
- `TALOS_DAY1_SYNC_ACCESS_CMD`

`cluster.sh` executes these mappings directly for Talos lifecycle actions
(`generate`, `provision`, `prepare-bootstrap`, `apply-config`, `bootstrap`,
`sync-access`). If a mapping is missing, execution fails explicitly.

`apply-post-bootstrap` remains a separate action and is not part of the mapped
Talos lifecycle command set.

Example:

```bash
./overlays/base/scripts/talos/cluster.sh create-project --project-dir=overlays/lab/talos/talos-dev
./overlays/base/scripts/talos/cluster.sh generate --project-dir=overlays/lab/talos/talos-dev
```

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
2. Optional post-bootstrap config convergence (`apply-config`)
3. Phase 1.5: Post-bootstrap baseline (`apply-post-bootstrap`)
4. Phase 2: Network Bring-up (optional extras)
5. Phase 3: GitOps handoff (Argo CD as source of truth)

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
./overlays/base/scripts/talos/cluster.sh apply-post-bootstrap --project-dir=overlays/lab/talos/talos
```

With explicit list:

```bash
./overlays/base/scripts/talos/cluster.sh apply-post-bootstrap --project-dir=overlays/lab/talos/talos --addons='["cilium","longhorn"]'
```

Important:

- `prepare-bootstrap`, `apply-config`, and `apply-post-bootstrap` are different steps:
  - `prepare-bootstrap`: pre-bootstrap apply (`--apply-stage=pre`), used to prepare nodes before etcd bootstrap. This stage can use `talosctl apply-config --insecure` on first contact and then fallback to talosconfig if TLS is already enforced.
  - HAProxy backend reconciliation for Talos control-plane endpoints runs in `prepare-bootstrap` only.
  - `apply-config`: Talos machine config convergence after prep (`talosctl apply-config` with talosconfig/TLS only, no insecure fallback).
  - `apply-post-bootstrap`: post-bootstrap Kubernetes baseline addons
  - The first pod/node snapshot after Helm install is immediate and can still show `Pending`/`NotReady` for a short period.

Recommended follow-up right after `apply-post-bootstrap`:

```bash
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n kube-system get pods -l k8s-app=cilium -w
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl get nodes -w
```

## Phase 2: Network Bring-up (Optional Extras)

For optional extras in this repository, use `talos-gitops.sh` in day-2 flow
instead of applying ad-hoc wrappers from day-1.

## Phase 3: GitOps Handoff

After network is stable:

1. Install/validate Argo CD
2. Apply root app / app-of-apps
3. Move day-2 addon changes to Git-only workflow (PR/merge)

Tip:

- If you configured global symlinks, use `talos-gitops` directly (same pattern as `talos-cluster`).
- In day-2 platform installs, system exclusions (for example `cilium`) are always enforced.
  Use `--addons` and `--exclude-addons` to define the run scope for non-system addons.

## OVA vs ISO: How To Choose

Provisioning supports both modes.

Selection rule used by `talos/govc/provision-cluster.sh`:

- If `TALOS_OVA_PATH` (or `--ova-path`) is set: **OVA mode is used**
- Otherwise: **ISO mode is used** (`TALOS_ISO_DATASTORE_PATH` / `--iso-path`)

Practical recommendation:

- Use OVA for current lab flow (faster/consistent with this repo)
- Use ISO when you explicitly need ISO lifecycle behavior

Decoupling rule:

- OVA/template generation is optional and external to day-1 lifecycle actions.
- Day-1 should only consume an already available image source.
- If a custom image is required, run Packer separately and then reuse the
  resulting artifact URL/path in provisioning variables.

## Control-Plane And Worker Images

This project intentionally supports different Talos installer images per role:

- `TALOS_CONTROL_PLANE_INSTALLER_IMAGE`
- `TALOS_WORKER_INSTALLER_IMAGE`

Why:

- Control-plane nodes prioritize cluster control-plane/etcd stability.
- Worker nodes may need storage/workload-specific evolution (for example
  Longhorn now and vSphere CSI later).
- Keeping image selection per role avoids coupling worker storage concerns to
  control-plane nodes.

Compatibility:

- If role-specific values are not set, automation falls back to
  `TALOS_INSTALLER_IMAGE`.

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
