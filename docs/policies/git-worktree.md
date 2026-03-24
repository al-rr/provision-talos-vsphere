# Git Worktree Policy

## Purpose
- Use worktrees to isolate parallel changes without contaminating the main checkout.

## Conventions
- Use one branch per worktree.
- Name worktrees after the workstream or ticket they support.
- Keep worktrees outside generated artifact directories.
- Remove stale worktrees when the branch is merged or abandoned.

## Repository Hygiene
- Do not share generated Terraform or Talos outputs between worktrees.
- Recreate local generated outputs inside the active worktree when needed.
- Keep `overlays/<env>/scripts/vars.sh` as the active env contract.
- Treat root `.env` files as legacy local compatibility only unless a sanitized sample is being committed.