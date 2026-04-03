# Repository Conventions

This document defines repository-level conventions for `provision-talos-vsphere`.

## Directory Roles

- `overlays/`: canonical project automation and environment-specific overrides
- external `infra-gitops/`: reusable shared automation modules consumed by this project
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

Do not place the following in this repository unless it is required by the
project runtime flow:

- service-specific deployment logic
- project-only runtime configuration
- environment-specific secrets
- ad hoc local artifacts
- copied draft documentation from unrelated repositories

## Change Scope

Keep each change set focused on one topic, one module, or one cross-cutting
standard.

Good scopes:

- `overlays/base/scripts/talos/`
- `overlays/base/scripts/ha-proxy/`
- `docs/policies/`

Bad scope:

- unrelated changes in Talos, HAProxy, DNS, and docs in one PR

## Module Layout

A Bash module should prefer a layout like:

This repository keeps active automation under `overlays/base/scripts/` and
environment overrides under `overlays/<env>/`.

## Canonical Documentation Rule

Normative rules live in `docs/standards/`.

Module READMEs should document module-specific behavior, not redefine project
standards.

## Legacy Rule

Drafts, imports, or superseded documents must be moved to `docs/archive/` and
must not be referenced as authoritative guidance.
