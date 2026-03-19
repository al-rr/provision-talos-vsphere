# Controller Guide (Lab)

This guide is specific to the controller host used to operate the Talos cluster.

## Scope

From the controller, you can:
- install `talosctl`
- install `kubectl`
- install `helm` (Helm 3)
- configure Helm repositories for cluster add-ons (for example Cilium)
- configure `~/.talos/config`
- generate and use `~/.kube/config`

## Prerequisites

Run commands from the repository root:

```bash
cd /home/vagrant/talos-vsphere-lab
```

## 1) Install talosctl

```bash
./overlays/base/scripts/talos/install.sh --env=lab
```

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

## 6) Configure Helm Repositories (Cilium)

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
helm repo list
```

Why this is important:
- Talos cluster bootstrap prepares Kubernetes control plane and workers, but does not install your Day-2 networking stack.
- In the new `talos` cluster flow, we disable default CNI and install Cilium as the cluster CNI.
- Cilium is installed from Helm charts, so the controller needs the Cilium Helm repository configured.
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
- Keep Helm 3 for now in this lab flow (Cilium/Day-2 validation).
- If `~/.kube/config` already exists and is shared with other clusters, prefer using:

```bash
export KUBECONFIG=~/.kube/config
kubectl config get-contexts
```
