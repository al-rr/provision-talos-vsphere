# Controller Guide (Lab)

This guide is specific to the controller host used to operate the Talos cluster.

## Scope

From the controller, you can:
- install `talosctl`
- install `kubectl`
- install `helm` (Helm 3)
- prepare OCI-based Helm artifacts for cluster add-ons (for example Cilium)
- configure `~/.talos/config`
- generate and use `~/.kube/config`

## Prerequisites

Run commands from the repository root:

```bash
cd /home/vagrant/talos-vsphere-lab
```

## 1) Install talosctl

```bash
./overlays/lab/controller/scripts/install-talosctl.sh
```

Optional version pin:

```bash
./overlays/lab/controller/scripts/install-talosctl.sh --version=v1.12.4
```

This script also configures:
- `talosctl` bash completion

Open a new shell (or run `source ~/.bashrc`) to load completion.

## 2) Install kubectl

```bash
./overlays/lab/controller/scripts/install-kubectl.sh
```

Optional version pin:

```bash
./overlays/lab/controller/scripts/install-kubectl.sh --version=v1.35.0
```

This script also configures:
- `kubectl` bash completion
- alias `k=kubectl` with completion

Open a new shell (or run `source ~/.bashrc`) to load completion and aliases.

## 3) Configure talosctl context

```bash
mkdir -p ~/.talos
install -m 0600 overlays/lab/talos/k8s-cluster-lab/talosconfig ~/.talos/config
```

## 4) Install Helm 3

```bash
./overlays/lab/controller/scripts/install-helm.sh
```

Optional version pin:

```bash
./overlays/lab/controller/scripts/install-helm.sh --version=v3.19.0
```

This script also configures:
- `helm` bash completion

Open a new shell (or run `source ~/.bashrc`) to load completion and aliases.

## 5) Generate kubeconfig

```bash
mkdir -p ~/.kube
talosctl --talosconfig ~/.talos/config \
  kubeconfig ~/.kube/config \
  --nodes 192.168.0.88 \
  --endpoints 192.168.0.88
```

## 6) Prepare Cilium Values Using OCI (No Helm Repo Add)

```bash
mkdir -p overlays/lab/talos/talos/helm/cilium

helm show values oci://quay.io/cilium/charts/cilium --version 1.19.1 \
  > overlays/lab/talos/talos/helm/cilium/values.base.yaml

cp overlays/lab/talos/talos/helm/cilium/values.base.yaml \
  overlays/lab/talos/talos/helm/cilium/values.yaml
```

Why this is important:
- Talos cluster bootstrap prepares Kubernetes control plane and workers, but does not install your post-bootstrap networking stack.
- In the new `talos` cluster flow, we disable default CNI and install Cilium as the cluster CNI.
- Cilium is consumed from OCI charts, and we keep values under version control before installation.
- This step runs on the controller host (the operator node), not inside Talos nodes.

## 7) Validate

```bash
talosctl --talosconfig ~/.talos/config \
  --nodes 192.168.0.88 \
  --endpoints 192.168.0.88 \
  version

KUBECONFIG=~/.kube/config kubectl get nodes -o wide
helm version --short
k version --client --output=yaml | sed -n 's/^  gitVersion: //p'
```

## Notes

- Keep `talosctl` compatible with Talos node version.
- Keep `kubectl` close to Kubernetes cluster minor version (supported skew is usually +/- 1 minor).
- Keep Helm 3 for now in this lab flow (Cilium post-bootstrap validation).
- If `~/.kube/config` already exists and is shared with other clusters, prefer using:

```bash
export KUBECONFIG=~/.kube/config
kubectl config get-contexts
```
