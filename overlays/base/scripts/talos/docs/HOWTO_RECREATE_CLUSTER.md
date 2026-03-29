# How-To: Recreate Talos Cluster From Scratch

## Goal

Recreate the cluster from a clean state using the repository automation, without
manual one-off commands.

## When To Use

- Cluster state is inconsistent (stale members, wrong IP bindings, old certs).
- You need a reproducible Day-1 rerun for validation.

## Inputs

- Environment name (example: `lab`).
- Cluster intent already updated in:
  - `overlays/<env>/scripts/vars.sh`
  - `overlays/<env>/talos/<cluster>/cluster-spec.yaml`

## Preconditions

Validate before running:

```bash
kubectl config current-context
talosctl version --client
```

Optional (visibility only):

```bash
govc vm.info talos-cp-1
```

## Recommended Fast Path

Use Phase 1 clean recreate orchestration:

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab --clean-recreate
```

What this does:

1. destroys existing Talos VMs (`talos-cp-*`, `talos-worker-*`)
2. clears generated artifacts for the target cluster
3. re-generates Talos configs
4. re-provisions VMs
5. applies configs and bootstraps
6. publishes/syncs kubeconfig and talosconfig
7. runs validation checks

## Control-Plane-Only Recreate

For staged bring-up (CP first, workers later):

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh \
  --env=lab \
  --clean-recreate \
  --worker-count=0
```

Then add workers later using:

- [HOWTO_ADD_WORKERS.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/HOWTO_ADD_WORKERS.md)

## Validation

```bash
kubectl get nodes -o wide
talosctl get members
```

Expected:

- control-plane members match current environment intent
- workers are present only if worker provisioning was requested

If `TALOS_DISABLE_DEFAULT_CNI=true`, expect `NotReady` nodes until CNI install.

## Next Step (Phase 2)

Apply day-1 post-bootstrap baseline after Phase 1 success:

```bash
./overlays/base/scripts/talos/cluster.sh apply-post-bootstrap --project-dir=overlays/lab/talos/talos
```

Optional day-2 platform sync from GitOps source:

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

## Troubleshooting

- Nodes not matching intended IPs:
  - verify `overlays/<env>/scripts/vars.sh`
  - verify node patch files under `overlays/<env>/talos/<cluster>/patches`
- Access errors after recreate:
  - rerun access sync via unified command:

```bash
./overlays/base/scripts/talos/cluster.sh sync-access --project-dir=overlays/lab/talos/talos
```

## Rollback

This operation is destructive by design. Rollback means rerunning recreate with
previous known-good environment values and patches.
