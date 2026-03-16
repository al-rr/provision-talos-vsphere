# Script Policy

## Scope

- Applies to maintained shell entrypoints and helper libraries in active
  workflows.

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

- Use `./overlays/base/scripts/<action>.sh --env=<env>` as the canonical
  invocation model.
- Keep scripts idempotent when practical.
- Validate required inputs early and fail with explicit error messages.
- Keep root compatibility shims clearly marked as transitional.

## Avoid

- Do not introduce new active workflows that depend on lab-only libraries.
- Do not treat root `.env` files as the primary configuration model.
- Do not keep dead commands, obsolete paths, or placeholder inventory values in
  supported scripts.
- Do not hardcode secrets in maintained scripts.