# ArgoCD Apps

## Purpose

This directory contains bootstrap handoff manifests that point Argo CD to the
dedicated GitOps repository (`talos-vsphere-gitops`).

## Structure

- `root-app.yaml`: bootstrap app-of-apps entrypoint (handoff).
- `apps/*.yaml`: legacy local copies kept for reference.

## Apply

If the repository is private, create repository credentials first.
If it is public, skip this step.

```bash
cp overlays/lab/talos/talos/gitops/argocd/repo-secret.example.yaml /tmp/repo-secret.yaml
# Edit /tmp/repo-secret.yaml and replace sshPrivateKey.
# This step must be done by the operator. Do not commit real keys.
KUBECONFIG=/home/vagrant/.kube/config \
kubectl apply -f /tmp/repo-secret.yaml
```

Then apply app-of-apps:

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl apply -f overlays/lab/talos/talos/gitops/argocd/root-app.yaml
```

## Notes

- Applications use Argo CD multi-source mode:
  - Source A: external Helm chart repository.
  - Source B: this Git repository (`ref: values`) for values files.
- Update `repoURL` or `targetRevision` if your repository address or branch
  differs from current defaults.
