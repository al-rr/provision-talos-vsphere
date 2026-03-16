#!/usr/bin/env bash
set -euo pipefail

# @describe Compatibility wrapper for the canonical shell lint entrypoint.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../../base/scripts/lint-shell.sh" --env=prod
