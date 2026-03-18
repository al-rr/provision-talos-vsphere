# Script Policy

## Scope

- Applies to maintained shell entrypoints and helper libraries in active
  workflows under `overlays/base/scripts/`, `overlays/base/govc/`, and
  environment-specific bootstrap assets when they are part of the supported lab
  flow.

## Required Standards

- Use `#!/usr/bin/env bash` for Bash scripts.
- Use `set -euo pipefail`.
- Add concise `shdoc` annotations to maintained entrypoints.
- Write comments, logs, and usage text in English.
- Source shared helpers from `overlays/base/scripts/functions.sh`.
- Load variables in this order:
  1. `overlays/base/scripts/vars.sh`
  2. `overlays/<env>/scripts/vars.sh`

## Supported Patterns

- Use the maintained base entrypoints as the canonical operator interface:
  `haproxy-ansible.sh`, `haproxy-packer-build.sh`, `haproxy-terraform.sh`,
  `talos-terraform.sh`, and `lint-shell.sh`.
- Use `./overlays/base/scripts/<entrypoint>.sh --env=<env>` as the canonical
  invocation model when the entrypoint accepts environment targeting.
- Keep scripts idempotent when practical.
- Validate required inputs early and fail with explicit error messages.
- Keep root compatibility shims clearly marked as transitional.
- Keep helper loaders such as `load-ansible-vars.sh`, `load-govc-vars.sh`,
  `load-packer-vars.sh`, and `load-terraform-vars.sh` as internal support code,
  not standalone operator workflows.
- Keep lab bootstrap scripts limited to controller setup and Ansible execution
  support for the local validation environment.

## Avoid

- Do not introduce new active workflows that depend on lab-only libraries.
- Do not treat root `.env` files as the primary configuration model.
- Do not keep dead commands, obsolete paths, or placeholder inventory values in
  supported scripts.
- Do not hardcode secrets in maintained scripts.
- Do not document generic lifecycle scripts such as `install.sh`, `setup.sh`,
  `upgrade.sh`, or `backup.sh` as canonical unless those files exist as active
  entrypoints in this repository.
