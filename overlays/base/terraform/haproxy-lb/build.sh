#!/usr/bin/env bash
set -euo pipefail

# @describe Compatibility wrapper for the canonical HAProxy Terraform entrypoint.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../../scripts/haproxy-terraform.sh" "$@"
