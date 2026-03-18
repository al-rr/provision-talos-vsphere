# Git Workflow Standard

This document defines the standard Git workflow for `infra-gitops`.

## Goals

- topic-focused history
- small, reviewable pull requests
- fewer merge conflicts
- repeatable work for humans and agents

## Branch Naming

Use branch names that reflect the change type and target:

```text
feature/<module>-<change>
fix/<module>-<issue>
docs/<topic>
refactor/<module>
test/<module>
chore/<topic>
```

Examples:

```text
feature/apache-hardening
fix/mariadb-idempotency
docs/bash-standards
refactor/freeipa-helpers
test/crowdsec-matrix
```

## Commit Standard

Prefer conventional-style commits:

```text
feat(apache): add idempotent cache configuration
fix(mariadb): avoid duplicate firewall rule creation
docs(standards): define git worktree usage
refactor(freeipa): extract certificate helper function
test(crowdsec): add oraclelinux smoke validation
```

## Pull Request Standard

Each pull request should:

- focus on one module or one standard
- explain why the change is needed
- summarize what changed
- list validation performed
- call out risks or follow-up work

## Pre-PR Checklist

Before opening a PR:

1. confirm the branch scope is still focused
2. run syntax and static checks for changed files
3. run module-specific tests when available
4. run Vagrant validation when the change affects cross-platform behavior
5. verify no local artifacts are staged

## Merge Preference

Prefer squash merge when the PR contains incremental work that should become a
single logical change.

Prefer merge commits only when preserving branch history adds clear value.

## Review Rule

Review comments should focus on:

- correctness
- idempotency
- portability
- security impact
- documentation gaps
- missing validation

## Scope Isolation Rule

When a second topic appears during the work, stop and open a new branch for it.
Do not silently expand the current PR into a multi-topic change.
