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

- Wrapper:
  - `overlays/base/scripts/talos/longhorn.sh`
- Helm release metadata:
  - `overlays/lab/talos/talos/helm/longhorn/release.yaml`
- Helm overrides:
  - `overlays/lab/talos/talos/helm/longhorn/values.yaml`
- Shared Helm orchestration:
  - `overlays/base/scripts/talos/phase-network-bringup.sh`

## Install Or Upgrade Longhorn

Run from repository root:

```bash
./overlays/base/scripts/talos/longhorn.sh --env=lab
```

Dry-run without applying:

```bash
./overlays/base/scripts/talos/longhorn.sh --env=lab --dry-run
```

## How Values Updates Work

- Edit only what must differ from chart defaults in:
  - `overlays/lab/talos/talos/helm/longhorn/values.yaml`
- Re-run:
  - `./overlays/base/scripts/talos/longhorn.sh --env=lab`
- Helm performs an in-place upgrade of the release.

## Validation Commands

```bash
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n longhorn-system get pods -o wide
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n longhorn-system get all
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl get sc
```

## Notes

- Longhorn managers should run on worker nodes in this topology.
- Namespace Pod Security labels are applied automatically by
  `phase-network-bringup.sh` using fields in
  `overlays/lab/talos/talos/helm/longhorn/release.yaml`.
