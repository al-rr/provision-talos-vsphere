# Useful Commands

Validated commands for routine operation in this workspace.

## Day-1 (`talos-vsphere-lab`)

```bash
# Create project scaffold
talos-cluster create-project --project-dir=overlays/lab/talos/talos-dev

# Generate Talos artifacts
talos-cluster generate --project-dir=overlays/lab/talos/talos-dev

# Provision VMs
talos-cluster provision --project-dir=overlays/lab/talos/talos-dev

# Prepare hosts for bootstrap (pre-bootstrap apply flow)
talos-cluster prepare-bootstrap --project-dir=overlays/lab/talos/talos-dev

# Bootstrap control plane
talos-cluster bootstrap --project-dir=overlays/lab/talos/talos-dev

# Post-bootstrap machine config convergence
talos-cluster apply-config --project-dir=overlays/lab/talos/talos-dev

# Sync local talosctl/kubectl access
talos-cluster sync-access --project-dir=overlays/lab/talos/talos-dev

# Mandatory post-bootstrap baseline (CNI/storage baseline workflow)
talos-cluster apply-post-bootstrap --project-dir=overlays/lab/talos/talos-dev
```

## Day-2 (`talos-vsphere-lab` + `talos-vsphere-gitops`)

```bash
# Install/update all eligible platform addons
talos-gitops install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab

# Install/update one addon only
talos-gitops install-addon \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addon=cert-manager

# Deploy Argo CD root app
talos-gitops deploy-argocd-root-app \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

## Health Checks

```bash
kubectl --context=admin@talos-dev get nodes -o wide
kubectl --context=admin@talos-dev get pods -A
talosctl -n 192.168.0.61 get members
```
