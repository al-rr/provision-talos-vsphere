#!/usr/bin/env bash
# @file provision.sh
# @brief Backward-compatible DNS provision entrypoint.
# @description
#   This wrapper keeps legacy command compatibility and delegates to the
#   module-scoped GOVC provisioner at overlays/base/scripts/dns/govc/provision.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/govc/provision.sh" "$@"
