#!/usr/bin/env bash
set -euo pipefail

# ================================
# CLUSTER CONFIGURATION
# ================================
CLUSTER_NAME="k8s-cluster-lab"
DISK_NAME="sda"
# Selected VIP (adjust for your network)
CLUSTER_VIP="192.168.0.249"
# Default Kubernetes API port
API_ENDPOINT="https://${CLUSTER_VIP}:6443"

TALOS_CONF_PATH="../talos"

if test -z "${CONTROL_PLANE_IP:-}"; then
    echo "Required variable CONTROL_PLANE_IP is not set"
    exit 1
fi
CONTROL_PLANE_IP=("<control-plane-ip-1>" "<control-plane-ip-2>" "<control-plane-ip-3>")
WORKER_IP=("<worker-ip-1>" "<worker-ip-2>" "<worker-ip-3>")

# Relative path to patch files
CONTROLPLANE_PATCH_FILE="$TALOS_CONF_PATH/cp.patch.yaml"
WORKER_PATCH_FILE="$TALOS_CONF_PATH/worker.patch.yaml"

# Output directory
OUTPUT_DIR="$TALOS_CONF_PATH/${CLUSTER_NAME}"

# ================================
# EXECUTION
# ================================
echo "Generating configuration for cluster '${CLUSTER_NAME}'..."
echo "VIP/API: ${API_ENDPOINT}"
echo "Output directory: ${OUTPUT_DIR}"

if [[ -d "${OUTPUT_DIR}" ]]; then
    rm -rf "${OUTPUT_DIR}"
fi

mkdir -p "${OUTPUT_DIR}"

talosctl gen config "${CLUSTER_NAME}" \
    "https://${CONTROL_PLANE_IP}:6443" \
    --output-dir "${OUTPUT_DIR}" \
    --install-disk /dev/"${DISK_NAME}" \
    --config-patch-control-plane @"${CONTROLPLANE_PATCH_FILE}" \
    --config-patch-worker @"${WORKER_PATCH_FILE}"

# Verify the target disk when needed:
# talosctl get disks --nodes "${API_ENDPOINT}" --insecure

echo "Files generated in: ${OUTPUT_DIR}"
echo " - controlplane.yaml"
echo " - worker.yaml"
echo " - talosconfig"
