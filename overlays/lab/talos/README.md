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

- Global patches are optional and disabled by default.
- Candidate global patches: `overlays/lab/talos/patches-available/`
- Active global patches: `overlays/lab/talos/patches-enabled/`
- Cluster-specific patches: `overlays/lab/talos/<cluster-name>/patches/`

Enable global patches in bootstrap flow only when needed:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --enable-global-patches \
  --cluster-name=talos
```

## Day-1 Bootstrap Entry Point

Use:
- `overlays/base/scripts/talos/cluster-bootstrap.sh`

This script runs:
1. config generation
2. apply-config per node
3. bootstrap

## Notes

- Runtime files like `bootstrap-ips.txt` are ignored in git and should not be treated as architecture source.
- Keep architecture intent in `cluster-spec.yaml`, not in generated runtime artifacts.
