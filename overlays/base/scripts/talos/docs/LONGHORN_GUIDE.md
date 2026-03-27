# Longhorn Guide

## Purpose

Document how Longhorn is prepared and installed in this Talos lab cluster, and
how to update values safely after initial deployment.

## Prerequisites

- Talos cluster is running and reachable with `kubectl`.
- Worker nodes include Longhorn system extensions via:
  - `overlays/lab/talos/talos/schematic.yaml`
- Worker machine config includes Longhorn patch:
  - `overlays/lab/talos/talos/patches/longhorn.patch.yaml`
- Worker VMs have extra data disk configured (current flow uses `sdb`):
  - `overlays/base/scripts/talos/govc/provision-cluster.sh`

## Files Used By The Addon

- Helm release metadata:
  - `overlays/lab/talos/talos/helm/longhorn/release.yaml`
- Helm overrides:
  - `overlays/lab/talos/talos/helm/longhorn/values.yaml`
- Day-1 baseline orchestration:
  - `overlays/base/scripts/talos/cluster.sh apply-post-bootstrap`
- Day-2 GitOps orchestration:
  - `overlays/base/scripts/talos/talos-gitops.sh install-platform-helm`

## Install Or Upgrade Longhorn

Day-1 baseline mode (from cluster project):

```bash
./overlays/base/scripts/talos/cluster.sh apply-post-bootstrap \
  --project-dir=overlays/lab/talos/talos \
  --addons='["longhorn"]'
```

Day-2 GitOps mode (from manifest source):

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --project-dir=overlays/lab/talos/talos \
  --argocd-manifest-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["longhorn"]'
```

## How Values Updates Work

- Edit only what must differ from chart defaults in:
  - `overlays/lab/talos/talos/helm/longhorn/values.yaml`
- Re-run one of:
  - `cluster.sh apply-post-bootstrap --addons='["longhorn"]'`
  - `talos-gitops.sh install-platform-helm --addons='["longhorn"]'`
- Helm performs an in-place upgrade of the release.

## Validation Commands

```bash
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n longhorn-system get pods -o wide
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n longhorn-system get all
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl get sc
```

## Notes

- Longhorn managers should run on worker nodes in this topology.
- Namespace Pod Security labels are applied automatically by addon orchestration
  using fields in
  `overlays/lab/talos/talos/helm/longhorn/release.yaml`.
