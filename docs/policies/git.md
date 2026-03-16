# Git Policy

## Branching
- Use descriptive branch names tied to a single topic or milestone.
- Keep unrelated repository hygiene and infrastructure automation changes in separate branches when practical.

## Versioned Content
- Version source code, templates, policies, examples, and sanitized sample variables.
- Keep generated outputs out of Git.
- Track lockfiles intentionally when they are part of reproducible tooling behavior.

## Generated Artifacts
- Ignore Terraform working directories and state files.
- Ignore Packer artifacts and manifests unless there is an explicit reason to keep a generated sample.
- Ignore generated Talos cluster outputs.
- Do not treat generated credentials, kubeconfigs, or machine configs as source of truth.

## Review Expectations
- Prefer small, reviewable commits.
- Keep commit messages explicit about the subsystem or workflow changed.
- Update related documentation in the same branch when the active workflow changes.
