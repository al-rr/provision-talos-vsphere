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

- App-of-apps root:
  - `overlays/lab/talos/talos/gitops/argocd/root-app.yaml`
- Child applications:
  - `overlays/lab/talos/talos/gitops/argocd/apps/`

## One-Time Bootstrap

Install Argo CD first (Helm wrapper already exists):

```bash
./overlays/base/scripts/talos/argocd.sh --env=lab
```

Create repository credentials for the private Git repository used by Argo CD:

```bash
cp overlays/lab/talos/talos/gitops/argocd/repo-secret.example.yaml /tmp/repo-secret.yaml
# Edit /tmp/repo-secret.yaml and replace sshPrivateKey with a valid deploy key.
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig \
kubectl apply -f /tmp/repo-secret.yaml
```

Then apply the app-of-apps manifest:

```bash
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig \
kubectl apply -f overlays/lab/talos/talos/gitops/argocd/root-app.yaml
```

## How The Applications Read Values

Applications use Argo CD multi-source mode:

- Source A: Helm chart repository (or OCI chart).
- Source B: this Git repository (`ref: values`).
- `helm.valueFiles` points to `$values/.../values.yaml` in this repo.

This allows values to stay in:

- `overlays/lab/talos/talos/helm/<addon>/values.yaml`

## Updating Addon Configuration

1. Edit `overlays/lab/talos/talos/helm/<addon>/values.yaml`.
2. Commit and push to the tracked branch (`main` by default).
3. Argo CD syncs automatically (when automated sync is enabled).

## Validation

```bash
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n argocd get applications
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n argocd get pods
```

## Notes

- The manifests currently target branch `main`.
- If your repository URL or branch differs, update:
  - `repoURL`
  - `targetRevision`
