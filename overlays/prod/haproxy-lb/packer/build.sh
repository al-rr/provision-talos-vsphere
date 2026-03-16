#!/usr/bin/env bash
set -euo pipefail

# @describe Compatibility wrapper for the canonical HAProxy Packer entrypoint.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../../../base/scripts/haproxy-packer-build.sh" --env=prod "$@"
