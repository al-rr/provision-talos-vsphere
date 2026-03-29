# shdoc Standard

This document defines the required `shdoc` convention for executable Bash
scripts in `infra-gitops`.

## Rule

Executable scripts must include `shdoc` metadata near the top of the file.

Helper libraries such as `functions.sh` do not need a full executable script
header, but should still use comments where clarity is needed.

## Minimum Header

Each executable script should include:

- `@file`
- `@brief`
- `@description`
- `@arg` and `@flag` entries as needed
- `@example`

## Example

```bash
#!/usr/bin/env bash

# @file install_example.sh
# @brief Install Example Service.
# @description
#   Installs Example Service and its OS dependencies.
#
# @arg --version,-v string Version to install.
# @arg --env,-e string Environment name.
# @flag --yes,-y Proceed without interactive confirmation.
# @flag --help,-h Show usage information.
#
# @example
#   sudo ./install_example.sh --env=lab --version=1.2.3 --yes
```

## Description Style

- Write descriptions in English
- State what the script does, not marketing text
- Call out idempotency behavior when relevant
- Call out prerequisites when relevant

## Option Documentation

Every supported CLI option must be reflected in the header and in `usage()`.

## Examples In Usage

- `usage()` output must include an `Examples:` section for maintained
  entrypoints.
- Each example should include a short intent comment (for example:
  "Generate configs only", "Bootstrap only"), following the style used in
  `kubectl --help`.

## Function-Level Clarity

- `shdoc` is required at file level for entrypoints.
- For non-trivial helper functions inside scripts, add short inline comments to
  clarify purpose and critical decision points.

## Drift Rule

If script behavior changes, update the `shdoc` header in the same change.

## Generated Documentation

When a module generates API-style docs from `shdoc`, generated files must be
clearly marked as generated and must not become the normative source.
