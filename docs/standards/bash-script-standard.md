# Bash Script Standard

This document defines the standard structure for Bash automation in
`infra-gitops`.

## Baseline Rules

- Use `#!/usr/bin/env bash`
- Use `set -euo pipefail`
- Use ASCII unless there is a clear reason not to
- Prefer idempotent behavior
- Prefer explicit validation over implicit assumptions
- Prefer functions over large inline blocks
- Document executable scripts with `shdoc`

## Required Script Layout

The preferred order is:

1. shebang
2. `shdoc` header
3. strict mode
4. script constants
5. sourced dependencies
6. helper functions
7. `usage()`
8. `parse_args()`
9. `validate_args()`
10. environment loading
11. action functions
12. `main()`
13. entrypoint

## Logging

Scripts should emit simple structured log messages:

```bash
log_info()  { echo "[INFO] $*"; }
log_warn()  { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_fatal() { echo "[FATAL] $*" >&2; exit 1; }
```

## CLI Conventions

Support long flags and short aliases when justified.

Common flags:

- `--env`, `-e`
- `--version`, `-v`
- `--yes`, `-y`
- `--dry-run`, `-n`
- `--help`, `-h`

## Idempotency Rules

Good:

- install only if missing
- create user only if absent
- overwrite generated config with the desired state
- skip upgrade when already at target version

Bad:

- assuming a clean host
- appending duplicate config on every run
- opening duplicate firewall rules
- failing on harmless re-runs

## Install Script Expectations

A well-formed `install` script should:

- install dependencies
- create required users and directories
- install packages or binaries
- leave runtime configuration for a later `setup` step

## Setup Script Expectations

A well-formed `setup` script should:

- write application or service configuration
- initialize runtime prerequisites
- configure secrets, certificates, or service units
- perform post-install configuration safely

## Upgrade Script Expectations

A well-formed `upgrade` script should:

1. detect installed version
2. resolve target version
3. stop services if needed
4. replace binaries or packages
5. restart services
6. validate the result

## Template Rule

When creating a new script, start from the examples in:

- `docs/templates/bash/install.sh.example`
- `docs/templates/bash/setup.sh.example`
- `docs/templates/bash/upgrade.sh.example`
- `docs/templates/bash/vars.sh.example`

## Validation Rule

At minimum, validate new or changed scripts with:

- `bash -n`
- `shellcheck` when available
- module-specific execution checks
- Vagrant validation when applicable
