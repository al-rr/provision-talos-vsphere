#!/usr/bin/env bash
# @file cluster-toolchain.sh
# @brief Run day-1 actions using external talos-toolchain.
# @description
#   Thin wrapper that forwards all arguments to talos-toolchain cluster.sh.
#   This allows migration testing without replacing the current local cluster.sh.
#
# @arg action string Any action supported by toolchain cluster.sh.
# @arg options string Any options supported by toolchain cluster.sh.
# @arg --toolchain-dir path Optional talos-toolchain repository dir override.
# @flag --help,-h Show usage information.
# @example
#   ./cluster-toolchain.sh create-project --project-dir=overlays/lab/talos/talos-dev
# @example
#   ./cluster-toolchain.sh generate --project-dir=overlays/lab/talos/talos-dev
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

TOOLCHAIN_DIR="${TALOS_TOOLCHAIN_DIR:-/home/vagrant/talos-toolchain}"

usage() {
  cat <<'EOF_USAGE'
Usage: cluster-toolchain.sh [--toolchain-dir=<path>] <action> [options]

Forwards all arguments to:
  <toolchain-dir>/scripts/talos/cluster.sh

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
TARGET_SCRIPT="${TOOLCHAIN_DIR}/scripts/talos/cluster.sh"
[[ -x "${TARGET_SCRIPT}" ]] || {
  echo "[ERROR] Toolchain cluster.sh not found or not executable: ${TARGET_SCRIPT}" >&2
  echo "[INFO] Set TALOS_TOOLCHAIN_DIR or pass --toolchain-dir=<path>." >&2
  exit 1
}

exec "${TARGET_SCRIPT}" "${ARGS[@]}"

