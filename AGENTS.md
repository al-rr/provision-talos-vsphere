# Project Agent Instructions

## Language Policy (Mandatory)

- All comments, log messages, documentation, inline notes, and examples must be
  written in English.
- Do not add Portuguese or any other non-English language text to scripts,
  templates, variable files, or docs.
- If a file contains mixed language content, new edits must normalize that
  content to English.

## Source Of Truth

- `agenda.md` is the official project roadmap.
- `docs/policies/*.md` contains the repository policies for documentation, Git,
  worktrees, scripts, and tooling.
- `docs/devops/platform-automation-architecture.md` is the concise
  repository-specific architecture and execution context document.
- `overlays/base` is the canonical automation layer.
- `overlays/base/scripts/vars.sh` defines shared defaults.
- `overlays/<env>/scripts/vars.sh` overrides environment-specific values.

## Repository Direction

- This repository is currently the working integration space where modules are
  tested together, especially against the ESXi lab and the local validation lab.
- Reusable scripts and module-level operational logic are expected to migrate to
  `infra-gitops` over time.
- Until that migration happens, keep module structure and documentation aligned
  with that future target so the move remains straightforward.
- Treat this repository primarily as the place for deployed-project context:
  architecture, environment values, topology, node counts, overlays, patches,
  and validation scenarios.
- When deciding where documentation belongs:
  - module usage, operational guides, and reusable script behavior should be
    written as module documentation
  - environment layout, cluster intent, deployment plans, and scenario-specific
    values should stay with the environment or cluster workspace

## Scripts Policy

- Use `shdoc` annotations on maintained shell entrypoints.
- Use `set -euo pipefail` in maintained shell scripts.
- Prefer canonical entrypoints in `overlays/base/scripts/`.
- Treat root `.env` usage as legacy compatibility only, never as the primary
  configuration model.
- Treat helper loaders such as `load-*.sh` as internal support scripts rather
  than operator entrypoints.
- Wrapper entrypoints should accept `--env` (default `lab`) and resolve
  `overlays/<env>/scripts/vars.sh` automatically when `--vars-file` is not
  explicitly provided.
- Pure compatibility wrappers that only `exec` an external script may delegate
  this behavior to that external implementation.
- `overlays/prod/scripts/vars.sh` is the default production override file.
- `overlays/lab/scripts/vars.sh` is the default lab override file.
- `overlays/lab/scripts/` must contain lab-controller bootstrap assets only.
- Module-specific VMware provisioning entrypoints belong inside the owning
  module, such as `overlays/base/scripts/talos/govc/` or
  `overlays/base/scripts/ha-proxy/govc/`.
- If a script belongs to a workload module and only happens to use `govc`,
  keep it in the workload module under a VMware-specific subdirectory instead of
  the top-level `govc` module.
- Use Git Bash as the default interactive terminal for this repository.
- Run `govc` from the Windows host.
- Run Ansible from the Vagrant-based lab environment where Ansible is
  installed.
- Keep lab validation assets available, but do not present them as the
  production source of truth.

## Documentation Model

- Module READMEs and guides should describe the reusable module itself.
- Deployment plans should describe the concrete environment being built, such as
  ESXi lab topology, VIPs, node IPs, DNS layout, and enabled patches.
- Prefer keeping deployment-plan style documents close to the cluster or
  environment that owns those values.
- Prefer keeping reusable operational guides close to the module that provides
  the behavior.

## Git

- Prefer Git Bash for Git operations when it works in the environment.
- Do not version generated artifacts such as Terraform working directories,
  Talos generated outputs, or Packer artifacts.

## Scope

- Applies to the entire repository.
- Priority folders: `overlays/base/`, `overlays/lab/`, `overlays/prod/`,
  `docs/`, and root docs.
