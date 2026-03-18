#!/usr/bin/env bash
# @file vars.sh
# @description Lab overlay environment defaults (shared by all lab tooling).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BASE_VARS="${REPO_ROOT}/overlays/base/scripts/vars.sh"

if [[ ! -f "${BASE_VARS}" ]]; then
  echo "[ERROR] Missing base vars file: ${BASE_VARS}" >&2
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    exit 1
  fi
  return 1
fi

# shellcheck source=/dev/null
source "${BASE_VARS}"

export OVERLAY_ENV="${OVERLAY_ENV:-lab}"
export TALOS_CLUSTER_NAME="${TALOS_CLUSTER_NAME:-k8s-cluster-lab}"
export TALOS_CLUSTER_ENDPOINT="${TALOS_CLUSTER_ENDPOINT:-192.168.0.249}"
export TALOS_CONTROL_PLANE_CONFIG_PATH="${TALOS_CONTROL_PLANE_CONFIG_PATH:-overlays/lab/talos/k8s-cluster-lab/controlplane.yaml}"
export TALOS_WORKER_CONFIG_PATH="${TALOS_WORKER_CONFIG_PATH:-overlays/lab/talos/k8s-cluster-lab/worker.yaml}"
