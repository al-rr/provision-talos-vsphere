#!/usr/bin/env bash
# @file talos-gitops.sh
# @brief Deprecated local day-2 GitOps operations entrypoint.
# @description
#   Superseded by talos-gitops-toolchain.sh, which forwards to the canonical
#   talos-toolchain checkout's scripts/talos/talos-gitops.sh. This script now
#   exists only as a compatibility shim: it prints a deprecation warning and
#   forwards all arguments to talos-gitops-toolchain.sh unchanged, so any
#   caller still invoking talos-gitops.sh directly keeps working during the
#   rollback window. Do not add new behavior here; extend talos-toolchain
#   instead.
#
# @arg action string Any action supported by talos-gitops-toolchain.sh.
# @arg options string Any options supported by talos-gitops-toolchain.sh.
# @flag --help,-h Show usage information.
# @example
#   # Deprecated: prefer talos-gitops-toolchain.sh directly
#   ./talos-gitops.sh install-platform-helm --kube-context=admin@talos-dev --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"

echo "[DEPRECATED] talos-gitops.sh is a compatibility shim; use talos-gitops-toolchain.sh (delegates to talos-toolchain) instead. This shim will be removed once no documented workflow calls it directly." >&2

exec "${SCRIPT_DIR}/talos-gitops-toolchain.sh" "$@"
