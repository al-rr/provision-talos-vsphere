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
./overlays/base/scripts/talos/talos-gitops-toolchain.sh install-platform-helm \
  --kube-context=admin@talos-dev \
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
- `--kube-context` is required to reduce risk of applying to the wrong cluster
  when multiple contexts exist in kubeconfig.

Examples:

```bash
# Scenario 1: install broad platform set (system excludes still applied)
./overlays/base/scripts/talos/talos-gitops-toolchain.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab

# Scenario 2: install only what you choose
./overlays/base/scripts/talos/talos-gitops-toolchain.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["longhorn"]'

# Scenario 2b: still selective, but skip extra addons for this run
./overlays/base/scripts/talos/talos-gitops-toolchain.sh install-platform-helm \
  --kube-context=admin@talos-dev \
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

Deploy the app-of-apps manifest using the day-2 entrypoint:

```bash
./overlays/base/scripts/talos/talos-gitops-toolchain.sh deploy-argocd-root-app \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

Equivalent manual command (same effect as the action above):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl apply -f /home/vagrant/talos-vsphere-gitops/environments/lab/argocd/root-app.yaml
```

Behavior note:

- `deploy-argocd-root-app` applies `root-app.yaml` and exits.
- Child `Application` resources are created later by Argo CD reconciliation.
- If Argo CD cannot compare/sync (for example cache/API connectivity issues),
  only `addons-root` may exist and child apps will not be created yet.

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
KUBECONFIG=/home/vagrant/.kube/config kubectl -n argocd describe application addons-root
```

Expected:

- `addons-root` exists.
- Child apps (for example `cilium`, `longhorn`, `cert-manager`,
  `prometheus-stack`) appear in `kubectl -n argocd get applications` after
  reconciliation.

If child apps do not appear:

```bash
KUBECONFIG=/home/vagrant/.kube/config kubectl -n argocd logs statefulset/argocd-application-controller --tail=200
```

## UI Access (Port-Forward Model)

This project uses `kubectl port-forward` as the default operator access model
for internal UIs.

Why:

- Services stay internal (typically `ClusterIP`).
- Access is granted only to operators with valid kubeconfig/context.
- No persistent external exposure is required for day-to-day lab operation.

Run the command from the controller/guest session that has cluster access, then
open the corresponding `localhost` URL on your host.

Argo CD UI (`https://localhost:8080`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Longhorn UI (`http://localhost:8081`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8081:80
```

Prometheus UI (`http://localhost:9090`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Grafana UI (`http://localhost:3000`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Alertmanager UI (`http://localhost:9093`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```

Notes:

- Keep each `port-forward` process running while the UI is in use.
- If a local port is busy, change the left side only (for example `18080:443`).
- By default, `kubectl port-forward` binds to `localhost`. Use
  `--address 0.0.0.0` only when you intentionally want external access.

## Notes

- The manifests currently target branch `main`.
- If your repository URL or branch differs, update:
  - `repoURL`
  - `targetRevision`
