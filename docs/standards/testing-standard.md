# Testing Standard

This document defines the minimum validation expectations for reusable
automation in `infra-gitops`.

## Testing Goals

- catch syntax errors early
- validate expected behavior
- confirm idempotency
- confirm supported platform coverage

## Validation Levels

### 1. Static Validation

Run when applicable:

- `bash -n <script>`
- `shellcheck -x <script>`
- `shfmt -d <script>` when formatting is standardized for that module

### 2. Module Execution Validation

If the module has executable automation, validate at least one realistic run
path.

### 3. Idempotency Validation

When a script changes system state, validate re-execution.

Preferred pattern:

- pass 1: install/configure baseline
- pass 2: run the same steps again
- post-checks: confirm service and config remain valid

The Apache matrix runner already demonstrates this pattern in
`scripts/apache/test_apache_scripts_matrix.sh`.

### 4. Multi-Platform Validation

If a module supports multiple distributions, validate at least:

- Ubuntu
- Oracle Linux

Use Vagrant unless another reproducible mechanism is already standardized for
that module.

The CrowdSec matrix runner already demonstrates multi-platform Vagrant testing
in `scripts/crowdsec/test_crowdsec_matrix.sh`.

## Test Script Naming

Prefer names like:

```text
test_<module>_matrix.sh
test_<module>_smoke.sh
quality-check.sh
```

## Logs

Store local test logs under a module-local `.logs/` directory and keep those
artifacts out of Git.

## PR Validation Summary

Every PR should state:

- what was tested
- on which platform
- whether idempotency was checked
- what was not tested, if anything
