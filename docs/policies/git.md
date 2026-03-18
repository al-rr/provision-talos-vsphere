# Git Policy

## Operator Context
- On Windows, use Git Bash as the default terminal for Git operations.
- Prefer Git Bash first for `git status`, `git diff`, `git log`,
  `git worktree`, branch creation, branch cleanup, and merge workflows.
- If Git Bash shell integration is unavailable in the current runner, call Git
  for Windows explicitly instead of switching the workflow to a different Git
  model:
  - `C:\Program Files\Git\bin\bash.exe -lc "<git command>"`
  - `C:\Program Files\Git\cmd\git.exe -C "<repo>" <git command>`
- Do not assume `git` is available on the default PowerShell `PATH`.

## Branching
- Use descriptive branch names tied to a single topic or milestone.
- Keep unrelated repository hygiene and infrastructure automation changes in separate branches when practical.

## Repository State Checks
- Run `git status --short` before deleting, consolidating, or moving
  repository content.
- Run `git diff --stat` or `git diff --name-only` before broad documentation or
  automation refactors.
- Treat untracked files and directories as potential user work until they are
  inspected.
- If `git status --short` shows `??` paths under `docs/`, `overlays/`, or
  other active project folders, inspect them before deleting or rewriting
  related content.
- Do not use documentation cleanup as a reason to remove files that have not
  been verified as redundant in the current working tree.

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
- When a change depends on repo structure or operator workflow, update the
  relevant policy or architecture document in the same branch.
