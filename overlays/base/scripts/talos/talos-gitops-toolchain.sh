#!/usr/bin/env bash
# @file talos-gitops-toolchain.sh
# @brief Run day-2 actions using external talos-toolchain.
# @description
#   Thin wrapper that forwards all arguments to talos-toolchain talos-gitops.sh.
#   This allows migration testing without replacing the current local talos-gitops.sh.
#
# @arg action string Any action supported by toolchain talos-gitops.sh.
# @arg options string Any options supported by toolchain talos-gitops.sh.
# @arg --toolchain-dir path Optional talos-toolchain repository dir override.
# @flag --help,-h Show usage information.
# @example
#   ./talos-gitops-toolchain.sh install-platform-helm --kube-context=admin@talos-dev --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

TOOLCHAIN_DIR="${TALOS_TOOLCHAIN_DIR:-/home/vagrant/talos-toolchain}"

usage() {
  cat <<'EOF_USAGE'
Usage: talos-gitops-toolchain.sh [--toolchain-dir=<path>] <action> [options]

Forwards all arguments to:
  <toolchain-dir>/scripts/talos/talos-gitops.sh

Options:
  --toolchain-dir=<path>   Override talos-toolchain repository location
  -h, --help               Show help
EOF_USAGE
}

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --toolchain-dir=*) TOOLCHAIN_DIR="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

[[ ${#ARGS[@]} -gt 0 ]] || { usage; exit 1; }

TOOLCHAIN_DIR="$(cd "${TOOLCHAIN_DIR}" && pwd)"
TARGET_SCRIPT="${TOOLCHAIN_DIR}/scripts/talos/talos-gitops.sh"
[[ -x "${TARGET_SCRIPT}" ]] || {
  echo "[ERROR] Toolchain talos-gitops.sh not found or not executable: ${TARGET_SCRIPT}" >&2
  echo "[INFO] Set TALOS_TOOLCHAIN_DIR or pass --toolchain-dir=<path>." >&2
  exit 1
}

exec "${TARGET_SCRIPT}" "${ARGS[@]}"

