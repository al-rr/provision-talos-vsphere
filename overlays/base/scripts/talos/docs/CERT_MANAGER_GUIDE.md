# cert-manager Guide

## Purpose

Document how cert-manager is installed and operated in this project.

## Important Behavior

- cert-manager does not provide a built-in web UI.
- Operations are done with `kubectl` (and optionally `cmctl`).
- Day-2 ownership is expected through `talos-gitops.sh`.

## Manifest Source

- Helm release metadata:
  - `talos-vsphere-gitops/environments/lab/helm/cert-manager/release.yaml`
- Helm values:
  - `talos-vsphere-gitops/environments/lab/helm/cert-manager/values.yaml`

## Install Or Upgrade

Install only cert-manager:

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-addon \
  --addon=cert-manager \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

Install as part of a platform run:

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["cert-manager"]'
```

## Validation Commands

```bash
KUBECONFIG=/home/vagrant/.kube/config kubectl -n cert-manager get pods -o wide
KUBECONFIG=/home/vagrant/.kube/config kubectl get crd | grep cert-manager.io
KUBECONFIG=/home/vagrant/.kube/config kubectl get clusterissuers,issuers -A
```

## Optional CLI (cmctl)

If `cmctl` is installed:

```bash
cmctl check api
```

## Notes

- cert-manager CRDs must exist before Certificate resources reconcile.
- Keep issuer and certificate manifests in GitOps source and let Argo CD sync
  them after cert-manager is healthy.
