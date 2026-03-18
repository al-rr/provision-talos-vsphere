# Git Worktree Standard

This document defines how `git worktree` should be used in `infra-gitops`.

## Why Worktrees Are Standard Here

`infra-gitops` contains many unrelated modules. Using one working directory for
all topics increases the chance of:

- accidental mixed commits
- unrelated branch changes
- merge conflicts
- agent sessions stepping on each other

The standard approach is one worktree per topic.

## Default Rule

Create a dedicated worktree for each module, refactor, or documentation topic.

Examples:

```bash
git worktree add ../wt-apache -b feature/apache-refactor main
git worktree add ../wt-freeipa -b fix/freeipa-cert-logic main
git worktree add ../wt-standards -b docs/platform-standards main
```

## Recommended Mapping

- Apache work: only `scripts/apache/` and direct supporting docs
- FreeIPA work: only `scripts/freeipa/` and direct supporting docs
- MariaDB work: only `scripts/mariadb/` and direct supporting docs
- Standards work: only `docs/` and direct examples/templates

If a shared helper must change, document that dependency in the PR summary.

## Worktree Naming

Use a clear directory name:

```text
../wt-apache
../wt-freeipa
../wt-mariadb
../wt-standards
../wt-testing
```

## Branch Naming with Worktrees

The worktree and branch should tell the same story.

Good:

```text
worktree: ../wt-apache
branch:   refactor/apache-module-layout
```

Bad:

```text
worktree: ../wt-apache
branch:   fix/random-stuff
```

## Agent Usage Rule

When using multiple agent sessions, assign one worktree per session and one
topic per worktree.

This allows:

- parallel development
- isolated validation
- smaller commits
- lower conflict risk

## Cleanup

After merge:

```bash
git worktree remove ../wt-apache
git branch -d refactor/apache-module-layout
```

Only remove the worktree after its branch has been merged or intentionally
discarded.
