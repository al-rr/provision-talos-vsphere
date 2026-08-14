# Prometheus Stack Guide

## Purpose

Document how kube-prometheus-stack is installed, validated, and accessed in
this project.

## Manifest Source

- Helm release metadata:
  - `talos-vsphere-gitops/environments/lab/helm/prometheus-stack/release.yaml`
- Helm values:
  - `talos-vsphere-gitops/environments/lab/helm/prometheus-stack/values.yaml`

## Install Or Upgrade

Install only prometheus-stack:

```bash
./overlays/base/scripts/talos/talos-gitops-toolchain.sh install-addon \
  --addon=prometheus-stack \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

Install as part of a platform run:

```bash
./overlays/base/scripts/talos/talos-gitops-toolchain.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["prometheus-stack"]'
```

## Validation Commands

```bash
KUBECONFIG=/home/vagrant/.kube/config kubectl -n kube-prometheus-stack get pods -o wide
KUBECONFIG=/home/vagrant/.kube/config kubectl -n kube-prometheus-stack get servicemonitors,prometheusrules
KUBECONFIG=/home/vagrant/.kube/config kubectl -n kube-prometheus-stack get alertmanagers,prometheuses
```

## UI Access (Port-Forward)

Prometheus (`http://localhost:9090`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Grafana (`http://localhost:3000`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Alertmanager (`http://localhost:9093`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```

By default, `kubectl port-forward` binds to `localhost`. Use
`--address 0.0.0.0` only when you intentionally want external access.

## Notes

- First install may show transient warnings if CRDs are not fully established
  yet; re-run after CRDs are available if needed.
- Keep dashboard, alert, and scrape customization in the GitOps values file.
