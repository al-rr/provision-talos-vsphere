#!/usr/bin/env bash
# @file cluster.sh
# @brief Deprecated local day-1 Talos cluster lifecycle entrypoint.
# @description
#   Superseded by cluster-toolchain.sh, which forwards to the canonical
#   talos-toolchain checkout's scripts/talos/cluster.sh. This script now
#   exists only as a compatibility shim: it prints a deprecation warning and
#   forwards all arguments to cluster-toolchain.sh unchanged, so any caller
#   still invoking cluster.sh directly keeps working during the rollback
#   window. Do not add new behavior here; extend talos-toolchain instead.
#
# @arg action string Any action supported by cluster-toolchain.sh.
# @arg options string Any options supported by cluster-toolchain.sh.
# @flag --help,-h Show usage information.
# @example
#   # Deprecated: prefer cluster-toolchain.sh directly
#   ./cluster.sh generate --project-dir=overlays/lab/talos/talos-dev
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"

echo "[DEPRECATED] cluster.sh is a compatibility shim; use cluster-toolchain.sh (delegates to talos-toolchain) instead. This shim will be removed once no documented workflow calls it directly." >&2

exec "${SCRIPT_DIR}/cluster-toolchain.sh" "$@"
