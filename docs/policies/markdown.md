# Markdown Policy

## Purpose
- Keep Markdown files consistent, easy to scan, and automation-friendly.

## Rules
- Write all Markdown content in English.
- Use one `#` heading per document.
- Keep headings short and descriptive.
- Prefer flat bullet lists over deeply nested lists.
- Use fenced code blocks with a language hint when practical.
- Use repository-relative paths exactly as they exist in the tree.
- Keep commands copyable and aligned with the active path structure.

## Links And References
- Link to local repository files when they are the source of truth.
- Link to official upstream documentation when the repository depends on external behavior.
- Call out when an example is illustrative instead of production-ready.

## Prohibited Patterns
- Do not document obsolete paths such as `environments/...`.
- Do not mix local draft commands with supported production commands without labeling them.
- Do not leave environment-specific secrets or private addresses in shared documentation unless they are clearly sample values.
