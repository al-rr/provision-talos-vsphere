# Architecture Overview

## Cluster Topology (Lab Target)

- Control plane: 3 Talos nodes
- Workers: 3 Talos nodes
- HAProxy: 2 external load balancer nodes
- DNS: external dnsmasq node used by lab workflows

## Control Planes and API Access

- Kubernetes API is accessed through HAProxy load balancer endpoint.
- Talos bootstrap/management flows are executed via `talos-cluster` actions.
- Day-1 and Day-2 are intentionally separated by script contracts.

## Platform Components

- CNI baseline: Cilium (day-1 post-bootstrap baseline)
- Storage baseline: Longhorn (day-1/day-2 depending on workflow stage)
- GitOps orchestrator: Argo CD (day-2 handoff)

## Repository Split

- `talos-vsphere-lab`:
  - day-1 toolchain
  - cluster lifecycle automation
- `talos-vsphere-gitops`:
  - day-2 manifests
  - environment-scoped helm/argocd definitions
- `infra-gitops`:
  - reusable module scripts and shared automation patterns

## Automation Stack

- Bash entrypoints (`cluster.sh`, `talos-gitops.sh`)
- govc/vSphere automation in day-1 provisioning flows
- Helm/Kubectl for day-2 convergences
- Vagrant guest used as operational control host
