# How-To: Add Workers To An Existing Talos Cluster

## Goal

Add new worker VMs to an already bootstrapped Talos cluster without recreating
control-plane nodes.

## When To Use

- The control plane is healthy and you need more worker capacity.
- You want to scale workers only (`talos-worker-*`).

## Inputs

- Environment overlay, for example `lab`.
- Target worker count.
- Current cluster access:
  - `talosconfig`
  - `kubeconfig`

## Preconditions

Run these checks before scaling:

```bash
kubectl get nodes -o wide
talosctl get members
```

Expected:

- control-plane nodes are healthy
- cluster API is reachable

## Steps

1. Provision worker VMs only.
2. Wait for Talos API on the new workers.
3. Validate node registration in Talos and Kubernetes.

### 1) Provision worker VMs only

Set control-plane count to zero and pass the desired worker count:

```bash
./overlays/base/scripts/talos/provision-cluster.sh \
  --env=lab \
  --cp-count=0 \
  --worker-count=<target-worker-count> \
  create
```

Notes:

- This command does not destroy existing control-plane VMs.
- Worker machine config is injected from the generated worker config files used
  by the provisioning flow.

### 2) Optional: re-apply worker config (only if needed)

Use this only when you need to enforce updated worker config after provisioning:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=apply \
  --worker-ips=<worker-ip-1>,<worker-ip-2>
```

## Verification

```bash
talosctl get members
kubectl get nodes -o wide
```

Expected:

- new worker IPs appear in Talos members
- new workers appear in Kubernetes nodes
- worker readiness becomes `Ready` after CNI is healthy

## Troubleshooting

- New worker not visible in `kubectl get nodes`:
  - verify CNI status first (`kubectl -n kube-system get pods -l k8s-app=cilium`)
  - verify worker IP and DNS/network reachability
- Talos API unreachable on worker:
  - check VM power/network on vSphere/ESXi
  - check worker static IP mapping in overlay vars and patches

## Rollback

To remove workers that were just added:

```bash
./overlays/base/scripts/talos/provision-cluster.sh \
  --env=lab \
  --cp-count=0 \
  --worker-count=<previous-worker-count> \
  destroy
```

Then recreate only the desired worker set with `create`.
