# Environment

## Execution Context

- Primary operator flow currently runs inside Vagrant guest (Codex CLI + shell).
- Push to remote repositories is performed from host machine.
- Session resilience strategy: run Codex in `tmux`.

## Host and Virtualization

- Host hypervisor: VMware Workstation
- Guest orchestrator: Vagrant (`overlays/lab/Vagrantfile`)
- Controller guest is the operational node used to run talos and gitops scripts.

## Network Model

- NAT + private lab network model.
- Fixed forwarded ports are used for controller access and UIs.
- SSH fixed port is required for stable VS Code/Codex connectivity.

## Repositories in Workspace

- `/home/vagrant/talos-vsphere-lab`
  - day-1 scripts and workflow policies
- `/home/vagrant/talos-vsphere-gitops`
  - day-2 manifests and release definitions
- `/home/vagrant/infra-gitops`
  - reusable automation modules

## Session Preconditions

Before running operational actions:

1. Confirm `git status --short --branch` in all three repositories.
2. Confirm current kube context before day-2 actions.
3. Keep changes scoped to one technical block per commit.
