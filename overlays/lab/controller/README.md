# Controller Guide (Lab)

This guide is specific to the controller host used to operate the Talos cluster.

## Scope

From the controller, you can:
- install `talosctl`
- install `kubectl`
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

## 3) Configure talosctl context

```bash
mkdir -p ~/.talos
install -m 0600 overlays/lab/talos/k8s-cluster-lab/talosconfig ~/.talos/config
```

## 4) Generate kubeconfig

```bash
mkdir -p ~/.kube
talosctl --talosconfig ~/.talos/config \
  kubeconfig ~/.kube/config \
  --nodes 192.168.0.88 \
  --endpoints 192.168.0.88
```

## 5) Validate

```bash
talosctl --talosconfig ~/.talos/config \
  --nodes 192.168.0.88 \
  --endpoints 192.168.0.88 \
  version

KUBECONFIG=~/.kube/config kubectl get nodes -o wide
```

## Notes

- Keep `talosctl` compatible with Talos node version.
- Keep `kubectl` close to Kubernetes cluster minor version (supported skew is usually +/- 1 minor).
- If `~/.kube/config` already exists and is shared with other clusters, prefer using:

```bash
export KUBECONFIG=~/.kube/config
kubectl config get-contexts
```
