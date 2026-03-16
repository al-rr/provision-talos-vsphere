#!/usr/bin/env bash
# @file vars.sh
# @description Lab environment overrides for local validation workflows.

BASE_VARS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../base/scripts" && pwd)/vars.sh"
# shellcheck source=/dev/null
source "${BASE_VARS}"

export OVERLAY_ENV="lab"
export TALOS_CLUSTER_NAME="k8s-cluster-lab"
export TALOS_CLUSTER_ENDPOINT="192.168.0.249"
export TALOS_CONTROL_PLANE_CONFIG_PATH="overlays/lab/talos/k8s-cluster-lab/controlplane.yaml"
export TALOS_WORKER_CONFIG_PATH="overlays/lab/talos/k8s-cluster-lab/worker.yaml"

