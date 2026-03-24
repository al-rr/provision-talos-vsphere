# Line Endings and File Rules

This document defines file handling rules for `infra-gitops`.

## Line Endings

Use LF for repository text files.

This applies to:

- shell scripts
- Markdown
- YAML
- JSON
- HCL
- Ruby
- config snippets

The repository already enforces this with `.gitattributes`.

## CRLF Rule

Do not commit CRLF line endings in repository text files. CRLF commonly breaks
shell scripts, diffs, and cross-platform automation behavior.

## Editor Rule

Configure editors to save repository text files with:

- UTF-8
- LF

## Generated and Local Files

Do not commit local execution artifacts such as:

- `.vagrant/`
- local logs
- virtual environments
- generated caches
- downloaded runtime artifacts
- machine-specific temp files

The repository already ignores `.vagrant/` in `.gitignore`.

## Executable Script Rule

Executable Bash scripts should keep a Unix-friendly format:

- LF line endings
- trailing newline at end of file
- no BOM

## Validation Hint

If line ending issues are suspected, check the staged diff before committing and
normalize the file before opening a PR.
