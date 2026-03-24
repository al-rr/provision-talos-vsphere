# Repository Conventions

This document defines the repository-level rules for `infra-gitops`.

## Directory Roles

- `scripts/`: reusable Bash automation modules
- `ansible/`: reusable roles, collections, and playbooks
- `terraform/`: reusable modules and environment definitions
- `packer/`: image-building assets
- `containers/`: container images and support files
- `overlays/`: local lab support or tool-specific overlays
- `docs/`: canonical documentation

## What Belongs Here

Add content here when it is reusable across multiple services, environments, or
repositories.

Examples:

- installing and hardening Apache
- installing MariaDB
- reusable Ansible roles
- generic Terraform modules
- Vagrant-based test assets for a reusable module

## What Does Not Belong Here

Do not place the following in `infra-gitops` unless it is clearly reusable:

- service-specific deployment logic
- project-only runtime configuration
- environment-specific secrets
- ad hoc local artifacts
- copied draft documentation from unrelated repositories

## Change Scope

Keep each change set focused on one topic, one module, or one cross-cutting
standard.

Good scopes:

- `scripts/apache/`
- `scripts/freeipa/`
- `docs/standards/bash-script-standard.md`

Bad scope:

- unrelated changes in `apache`, `freeipa`, `terraform`, and README in one PR

## Module Layout

A Bash module should prefer a layout like:

```text
scripts/<module>/
├── README.md
├── vars.sh
├── functions.sh
├── install_*.sh
├── setup_*.sh
├── upgrade_*.sh
├── conf/
└── tests/ or Vagrant assets when justified
```

Not every module needs every file, but structure should stay predictable.

## Canonical Documentation Rule

Normative rules live in `docs/standards/`.

Module READMEs should document module-specific behavior, not redefine platform
standards.

## Legacy Rule

Drafts, imports, or superseded documents must be moved to `docs/archive/` and
must not be referenced as authoritative guidance.
