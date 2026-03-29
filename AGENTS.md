# Project Agent Instructions

## Language Policy (Mandatory)

- Scripts, code comments, log messages, variable names, function names, and CLI
  help text must be written in English.
- Technical documentation intended for operators must be maintained in two
  languages:
  - English (`docs/en/`)
  - Portuguese Brazil (`docs/pt-br/`)
- Do not mix both languages in the same document file.
- When creating or updating an operator-facing guide, keep both language
  versions aligned in the same change scope whenever possible.

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
- Shell CLI help must follow a consistent operator format:
  - `Usage:` line with script and primary contract
  - `Actions:` (or `Commands:`) with one-line purpose per action
  - `Options:` with explicit flag semantics
  - `Examples:` with short intent comments above each example command
  - Prefer example style similar to `kubectl -h`, where examples explain "what"
    and "why", not only raw command syntax.
- Maintained Bash entrypoints must include `shdoc` metadata that explains:
  - file purpose (`@file`, `@brief`, `@description`)
  - supported arguments/flags (`@arg`, `@flag`)
  - practical command usage (`@example`)
- When scripts define non-trivial helper functions, add concise inline comments
  to explain intent and decision points.
- Prefer canonical entrypoints in `overlays/base/scripts/`.
- Treat root `.env` usage as legacy compatibility only, never as the primary
  configuration model.
- Treat helper loaders such as `load-*.sh` as internal support scripts rather
  than operator entrypoints.
- Wrapper entrypoints should accept `--env` (default `lab`) and resolve
  `overlays/<env>/scripts/vars.sh` automatically when `--vars-file` is not
  explicitly provided, unless the module has already migrated to a
  project-dir-first contract.
- For Talos cluster lifecycle orchestration (`overlays/base/scripts/talos/cluster.sh`):
  - `--project-dir` is the primary contract.
  - `--env` is removed from this entrypoint.
  - `--vars-file` remains available for advanced/manual use.
  - `create-project` is the scaffold action that creates missing project files.
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

## Documentation Taxonomy

- Use `README.md` as the entrypoint map, not a full runbook.
- Use `GUIDE` documents for end-to-end flows with strict execution order and
  decision points. A guide should answer "what to run first, second, and why".
- Use `HOWTO` documents for focused tasks, such as "add one worker",
  "rotate certificates", or "update addon values". A how-to should not repeat
  full cluster lifecycle steps.
- Use SOP (standard operating procedure) documents for repeatable operations
  with checks and rollback notes. SOPs should state pre-checks, execution
  commands, validation steps, and rollback path.
- Use deployment plan documents for environment intent and values, not command
  tutorials.
- Keep docs user-facing and reproducible: every operational command in docs
  should be runnable from the documented context.
- When a script behavior changes, update the nearest owning document in the
  same change set.
- Avoid mixing reusable module behavior and environment-specific values in a
  single document unless the file is explicitly an environment runbook.

## Git

- Prefer Git Bash for Git operations when it works in the environment.
- Do not version generated artifacts such as Terraform working directories,
  Talos generated outputs, or Packer artifacts.
- Never create commits unless the user explicitly asks for a commit in the
  current conversation turn.
- Before any commit, confirm scope by staging only the intended files.

## Scope

- Applies to the entire repository.
- Priority folders: `overlays/base/`, `overlays/lab/`, `overlays/prod/`,
  `docs/`, and root docs.

## Bash Conventions (Project)

- Keep shell scripts simple and explicit; avoid abstraction without repeated
  concrete use-cases.
- Prefer idempotent create/update operations:
  - create missing files
  - do not overwrite existing user files unless explicitly requested.
- Separate responsibilities:
  - scaffold/create phase creates project structure and templates
  - generate phase creates generated artifacts and dynamic render outputs
  - apply/bootstrap phases execute lifecycle actions.
- Always fail fast with actionable errors:
  - include what is missing
  - include which flag/path should be provided.
- Resolve real script path when symlinks are supported:
  - use `readlink -f` before deriving repository-relative paths.
- Keep defaults in one place (`overlays/base/scripts/vars.sh`) and let project
  or environment vars override them explicitly.
- Prefer deterministic file paths derived from project context instead of
  hardcoded environment paths.
