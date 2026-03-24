# Talos Cluster Blueprint (lab/talos)

This directory contains the architecture and deployment intent for the `talos`
cluster in lab.

## Why This Exists

`cluster-spec.yaml` is the **single source of truth** for cluster intent:

- node counts and IPs
- endpoint and access model
- network ranges
- CNI strategy
- toolchain and operations expectations

This avoids scattering critical decisions across many scripts and patch files.

## Files

- `cluster-spec.yaml`: declarative architecture blueprint
- `patches/cni.patch.yaml`: disables Talos default CNI and kube-proxy
- `helm/cilium/values.yaml`: Cilium chart custom values (post-bootstrap)
- `helm/cilium/values.base.yaml`: upstream defaults snapshot for reference

## Typical Flow

1. Provision VMs (govc).
2. Generate/apply/bootstrap cluster using:
   `overlays/base/scripts/talos/cluster-bootstrap.sh`.
3. Validate control plane and worker readiness.
4. Render Cilium manifests from OCI chart (`helm template`) and review.
5. Install Cilium when ready.

## Notes

- This file is conceptually similar to `.env`, but structured and versionable
  for architecture decisions rather than shell exports.
- Keep this document updated when changing IPs, endpoint, node counts, or CNI.
