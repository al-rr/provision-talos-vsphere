# Engineering Decisions

2026

Use Longhorn instead of Ceph for lab simplicity and faster iteration.

Use Cilium CNI to study eBPF networking.

Prefer infrastructure-as-code over manual configuration.

Keep day-1 and day-2 concerns separated:
- Day-1 lifecycle automation in `talos-vsphere-lab` (`cluster.sh`)
- Day-2 GitOps manifests in `talos-vsphere-gitops`

Use `--project-dir` as the primary contract for day-1 flows.

Require `--kube-context` in `talos-gitops.sh` to avoid operating on wrong clusters.

Keep system exclusions in day-2 addon install flow (for example `cilium`).
- User exclusions are additive and must not override system exclusions.

Use fixed SSH port mapping for controller access in Vagrant workflow.

Commit and push in small, scoped blocks to preserve rollback points.
