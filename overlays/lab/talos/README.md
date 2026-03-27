# Talos Clusters (Lab)

This directory is the Talos cluster workspace for lab environments.

## Cluster Directories

- `k8s-single-node-lab/`: legacy single-node Talos scenario (non-HA)
- `k8s-cluster-lab/`: multi-node Talos cluster scenario (control plane + workers)
- `talos/`: new blueprint-driven cluster scenario (Cilium-focused)

## Recommended Source Of Truth

For new clusters, use a blueprint style:
- `overlays/lab/talos/<cluster-name>/cluster-spec.yaml`
- `overlays/lab/talos/<cluster-name>/README.md`
- `overlays/lab/talos/<cluster-name>/patches/`

Current example:
- `overlays/lab/talos/talos/cluster-spec.yaml`

## Patch Model

- Cluster-specific patches: `overlays/lab/talos/<cluster-name>/patches/`

## Cluster Creation Entry Point

Use:
- `overlays/base/scripts/talos/cluster-bootstrap.sh`

This script runs:
1. config generation
2. apply-config per node
3. bootstrap

## Notes

- Runtime files like `bootstrap-ips.txt` are ignored in git and should not be treated as architecture source.
- Keep architecture intent in `cluster-spec.yaml`, not in generated runtime artifacts.
