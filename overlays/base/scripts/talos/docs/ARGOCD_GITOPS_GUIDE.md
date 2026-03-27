# ArgoCD GitOps Guide

## Purpose

Explain how to hand off addon lifecycle to Argo CD after the cluster is ready.

## Scope

This guide manages these addons through Argo CD `Application` resources:

- Cilium
- cert-manager
- Longhorn
- kube-prometheus-stack

## Repository Paths

- Bootstrap repo (this repository) keeps only the handoff manifest:
  - `overlays/lab/talos/talos/gitops/argocd/root-app.yaml`
- GitOps source of truth (separate repository):
  - `talos-vsphere-gitops/environments/lab/argocd/root-app.yaml`
  - `talos-vsphere-gitops/environments/lab/argocd/apps/`
  - `talos-vsphere-gitops/environments/lab/helm/<addon>/values.yaml`

## One-Time Bootstrap

Install Argo CD first from the GitOps manifest source:

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["argocd"]'
```

## Install Policy In Day-2

`install-platform-helm` supports both inclusive and exclusive selection:

- `--addons='[...]'`: install only the listed addons.
- `--exclude-addons='[...]'`: skip listed addons from the resolved set (merged with system excludes; does not override them).

Default behavior:

- `cilium` is excluded by default in day-2 runs.
- Reason: Cilium is a day-1 baseline dependency in this project; reapplying CNI
  as part of broad day-2 platform sync can cause avoidable network churn.
- System excludes are always enforced and merged with user excludes.
- In practice, this means `install-platform-helm` is for day-2/platform addons,
  while Cilium lifecycle stays in day-1 flow.

Examples:

```bash
# Scenario 1: install broad platform set (system excludes still applied)
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab

# Scenario 2: install only what you choose
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["longhorn"]'

# Scenario 2b: still selective, but skip extra addons for this run
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["argocd","longhorn","cert-manager"]' \
  --exclude-addons='["longhorn"]'
```

## Security Model For Repository Credentials

- `repo-secret.example.yaml` is only a template.
- The real SSH private key must be added only by the cluster operator.
- Do not commit real repository credentials into Git.
- Keep secret creation as a manual operator step.

Create repository credentials only if the GitOps repository is private.
For a public repository, skip this section.

```bash
cp /home/vagrant/talos-vsphere-gitops/environments/lab/argocd/repo-secret.example.yaml /tmp/repo-secret.yaml
# Edit /tmp/repo-secret.yaml and replace sshPrivateKey with a valid deploy key.
KUBECONFIG=/home/vagrant/.kube/config \
kubectl apply -f /tmp/repo-secret.yaml
```

Then apply the app-of-apps manifest:

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl apply -f /home/vagrant/talos-vsphere-gitops/environments/lab/argocd/root-app.yaml
```

## How The Applications Read Values

Applications use Argo CD multi-source mode:

- Source A: Helm chart repository (or OCI chart).
- Source B: this Git repository (`ref: values`).
- `helm.valueFiles` points to `$values/.../values.yaml` in this repo.

This allows values to stay in:

- `environments/lab/helm/<addon>/values.yaml` (in `talos-vsphere-gitops`)

## Updating Addon Configuration

1. Edit `environments/lab/helm/<addon>/values.yaml` in `talos-vsphere-gitops`.
2. Commit and push to the tracked branch (`main` by default).
3. Argo CD syncs automatically (when automated sync is enabled).

## Validation

```bash
KUBECONFIG=/home/vagrant/.kube/config kubectl -n argocd get applications
KUBECONFIG=/home/vagrant/.kube/config kubectl -n argocd get pods
```

## UI Access (Controller Port-Forward + Vagrant Forward)

Run `kubectl port-forward` on `talos-controller` and access from your host using
the forwarded ports configured in `overlays/lab/Vagrantfile`.

Current Vagrant mappings:

- Argo CD: host `18080` -> guest `8080`
- Argo CD (alt): host `18443` -> guest `8443`
- Longhorn: host `18081` -> guest `8081`
- Grafana: host `13000` -> guest `3000`
- Prometheus: host `19090` -> guest `9090`
- Alertmanager: host `19093` -> guest `9093`

Argo CD UI:

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n argocd port-forward svc/argocd-server 8080:443 --address 0.0.0.0
```

Open on host: `https://localhost:18080`.

Longhorn UI:

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8081:80 --address 0.0.0.0
```

Open on host: `http://localhost:18081`.

Prometheus UI:

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-prometheus 9090:9090 --address 0.0.0.0
```

Open on host: `http://localhost:19090`.

## Notes

- The manifests currently target branch `main`.
- If your repository URL or branch differs, update:
  - `repoURL`
  - `targetRevision`
