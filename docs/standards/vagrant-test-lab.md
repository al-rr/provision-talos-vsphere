# Vagrant Test Lab Standard

This document defines how Vagrant should be used to validate reusable automation
modules in `infra-gitops`.

## Purpose

Use Vagrant to validate automation in an isolated, repeatable environment before
merging changes that affect system state or cross-platform behavior.

## Default Platforms

When a module supports both major families used in this platform, validate on:

- Ubuntu
- Oracle Linux

## Standard Flow

1. validate the Vagrantfile
2. bring machines up
3. run provisioning or module test automation
4. perform post-checks
5. destroy or halt machines when done

Example commands:

```bash
vagrant validate
vagrant up
vagrant provision
vagrant status
vagrant destroy -f
```

## Multi-Platform Matrix Rule

When a module is intended to be cross-platform, prefer a matrix-oriented test
runner instead of manual one-off commands.

Examples in this repository:

- `scripts/apache/test_apache_scripts_matrix.sh`
- `scripts/crowdsec/test_crowdsec_matrix.sh`

## Idempotency Rule

If the module changes persistent state, run the provisioning flow twice or use a
dedicated idempotency test path.

## Local Artifact Rule

`.vagrant/` is a local execution artifact and must never be committed.

Box images, temporary logs, downloaded artifacts, and generated runtime state
must also stay out of Git unless there is an explicit exception.

## Provider Rule

Module documentation should state the supported Vagrant provider when the module
depends on one. If the module is provider-agnostic, say so explicitly.
