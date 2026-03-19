# Cluster Spec Schema (`cluster-spec.yaml`)

This document defines the internal schema used by this repository for:

- `overlays/lab/talos/talos/cluster-spec.yaml`

Important:
- This is a **project-local schema** (not an official Talos API object).
- Keep this file aligned when adding/removing fields in `cluster-spec.yaml`.

## Envelope

```yaml
apiVersion: platform.labs/v1alpha1
kind: TalosClusterSpec
metadata:
  name: <cluster-name>
  environment: <overlay-env>
spec: {}
```

### `apiVersion` (required)
- Type: `string`
- Current value: `platform.labs/v1alpha1`
- Purpose: versioning of this internal schema.

### `kind` (required)
- Type: `string`
- Current value: `TalosClusterSpec`
- Purpose: identifies this file type as a Talos cluster blueprint.

### `metadata.name` (required)
- Type: `string`
- Example: `talos`
- Purpose: canonical cluster name.

### `metadata.environment` (required)
- Type: `string`
- Example: `lab`, `prod`
- Purpose: overlay/environment scope.

## `spec`

### `spec.purpose` (required)
- Type: `string`
- Purpose: human-readable objective for this cluster.

### `spec.versions` (recommended)
- Type: `object`
- Fields:
  - `talos` (`string`, e.g. `v1.12.4`)
  - `kubernetes` (`string`, e.g. `v1.35.0`)
  - `ciliumChart` (`string`, e.g. `1.19.1`)
- Purpose: pin expected platform versions.

### `spec.access` (required)
- Type: `object`
- Fields:
  - `controlPlaneEndpoint` (`string`, URL with port, e.g. `https://192.168.0.250:6443`)
  - `talosApiPort` (`integer`, typically `50000`)
  - `kubeApiPort` (`integer`, typically `6443`)
- Purpose: defines operator access and API endpoints.

### `spec.network` (required)
- Type: `object`
- Fields:
  - `podCIDR` (`string`, CIDR)
  - `serviceCIDR` (`string`, CIDR)
  - `gateway` (`string`, IPv4)
  - `nameservers` (`list[string]`, IPv4 list)
  - `note` (`string`, optional)
- Purpose: defines cluster and node-level network assumptions.

### `spec.loadBalancer` (required for HA)
- Type: `object`
- Fields:
  - `implementation` (`string`, e.g. `HAProxy + Keepalived`)
  - `vip` (`string`, IPv4)
  - `nodes` (`list[object]`)
    - `name` (`string`)
    - `ip` (`string`, IPv4)
    - `role` (`string`, typically `MASTER` or `BACKUP`)
  - `backends` (`list[string]`, format `<ip>:<port>`)
- Purpose: external control-plane access path (HAProxy/keepalived).

### `spec.topology` (required)
- Type: `object`
- Sub-objects:
  - `controlPlanes`
  - `workers`

Each sub-object fields:
- `count` (`integer`)
- `nodes` (`list[object]`)
  - `name` (`string`)
  - `ip` (`string`, IPv4)

Purpose:
- explicit inventory for cluster shape and static addressing.

### `spec.cni` (required)
- Type: `object`
- Fields:
  - `strategy` (`string`)
  - `talosPatchFile` (`string`, repository path)
  - `ciliumValuesFile` (`string`, repository path)
- Purpose: records CNI decision and implementation files.

### `spec.controllerPrerequisites` (recommended)
- Type: `object`
- Fields:
  - `tools` (`list[string]`)
  - `shell` (`list[string]`)
- Purpose: controller-side dependencies and shell ergonomics expected.

### `spec.operations` (recommended)
- Type: `object`
- Fields:
  - `bootstrapMode` (`string`)
  - `globalPatchesDefault` (`string`)
  - `globalPatchesEnableFlag` (`string`)
  - `clusterPatchesDir` (`string`, repository path)
- Purpose: captures operational conventions used by scripts.

### `spec.validation` (recommended)
- Type: `object`
- Fields:
  - `checks` (`list[string]`)
- Purpose: minimum verification checklist after bootstrap/changes.

## Path Conventions

Paths stored in this file should be repository-relative, for example:

- `overlays/lab/talos/talos/patches/cni.patch.yaml`
- `overlays/lab/talos/talos/cilium/values.yaml`

## Update Rules

When changing `cluster-spec.yaml`:

1. Keep values consistent with actual scripts and patches.
2. Update this `SCHEMA.md` if fields are added/removed/renamed.
3. Prefer additive changes to avoid breaking readers.
4. If a breaking schema change is required, bump `apiVersion`.
