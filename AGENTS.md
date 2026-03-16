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
- `overlays/base` is the canonical automation layer.
- `overlays/base/scripts/vars.sh` defines shared defaults.
- `overlays/<env>/scripts/vars.sh` overrides environment-specific values.

## Scripts Policy

- Use `shdoc` annotations on maintained shell entrypoints.
- Use `set -euo pipefail` in maintained shell scripts.
- Prefer canonical entrypoints in `overlays/base/scripts/`.
- Treat root `.env` usage as legacy compatibility only, never as the primary
  configuration model.
- `overlays/prod/scripts/vars.sh` is the default production override file.
- `overlays/lab/scripts/vars.sh` is the default lab override file.
- `overlays/lab/scripts/` must contain lab-controller bootstrap assets only.
- Reusable GOVC helpers such as `overlays/base/govc/provision_haproxy.sh`
  belong in `overlays/base`.
- Use Git Bash as the default interactive terminal for this repository.
- Run `govc` from the Windows host.
- Run Ansible from the Vagrant-based lab environment where Ansible is
  installed.

## Git

- Prefer Git Bash for Git operations when it works in the environment.
- Do not version generated artifacts such as Terraform working directories,
  Talos generated outputs, or Packer artifacts.

## Scope

- Applies to the entire repository.
- Priority folders: `overlays/base/`, `overlays/lab/`, `overlays/prod/`,
  `docs/`, and root docs.