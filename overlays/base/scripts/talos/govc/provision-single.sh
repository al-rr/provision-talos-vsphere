#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible alias.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/provision-single-node.sh" "$@"
