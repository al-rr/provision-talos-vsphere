#!/usr/bin/env bash
set -euo pipefail

# @file vmware.sh
# @brief Backward-compatible wrapper for Talos govc provisioning flows.
# @description
#   Legacy callers can still use vmware.sh, but the canonical scripts are:
#   - provision-single.sh
#   - provision-cluster.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SINGLE_SCRIPT="${SCRIPT_DIR}/provision-single-node.sh"
CLUSTER_SCRIPT="${SCRIPT_DIR}/provision-cluster.sh"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") single-node [options] <create|destroy|plan>
  $(basename "$0") single      [options] <create|destroy|plan>
  $(basename "$0") cluster [options] <create|destroy|plan>

Examples:
  $(basename "$0") single --env=lab create
  $(basename "$0") cluster --env=lab create

You can also call the canonical scripts directly:
  ${SINGLE_SCRIPT}
  ${CLUSTER_SCRIPT}
EOF
}

main() {
  [[ -x "${SINGLE_SCRIPT}" ]] || chmod +x "${SINGLE_SCRIPT}" || true
  [[ -x "${CLUSTER_SCRIPT}" ]] || chmod +x "${CLUSTER_SCRIPT}" || true

  [[ $# -gt 0 ]] || { usage; exit 1; }

  case "$1" in
    single-node|single)
      shift
      exec "${SINGLE_SCRIPT}" "$@"
      ;;
    cluster)
      shift
      exec "${CLUSTER_SCRIPT}" "$@"
      ;;
    create|destroy|plan)
      # Backward compatibility: default to cluster flow when action is first arg.
      echo "[WARN] Legacy invocation detected; defaulting to cluster flow."
      exec "${CLUSTER_SCRIPT}" "$@"
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      echo "[ERROR] Unknown mode or action: $1" >&2
      exit 1
      ;;
  esac
}

main "$@"
