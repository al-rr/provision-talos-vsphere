# Documentation Policy

## Source Of Truth
- `README.md` explains repository purpose, layout, active workflows, and key references.
- `agenda.md` is the project roadmap and status tracker.
- `docs/policies/*.md` defines repository rules and collaboration standards.
- `docs/devops/platform-automation-architecture.md` is the concise repo-specific
  architecture and execution context reference.
- `overlays/base` is the canonical automation layer for shared workflows.
- Overlay-specific README files document only their own supported workflow and constraints.

## When To Update Docs
- Update `README.md` when the active entrypoint, path layout, or architecture changes.
- Update `agenda.md` when a phase starts, completes, or changes scope.
- Update the relevant policy file when a repository-wide convention changes.
- Update `docs/devops/platform-automation-architecture.md` when operator
  workflows, execution context, or canonical entrypoints change.
- Update overlay docs when supported commands or prerequisites change.

## Draft Handling
- Label incomplete workflows as `draft` or `legacy`.
- Keep lab-only or exploratory material out of primary production instructions.
- Prefer removing broken instructions from the main path instead of leaving ambiguous notes.
- Prefer deleting copied generic standards instead of maintaining parallel local
  standards that conflict with the active repository model.

## Architecture Notes
- Document the `overlays/base -> overlays/<env>` precedence explicitly when a workflow changes.
- Document the Kubernetes endpoint on `:6443` separately from Talos API access on `:50000`.
- State whether a workflow targets standalone ESXi, vCenter, or both.
- State which tool is authoritative for each lifecycle step.
