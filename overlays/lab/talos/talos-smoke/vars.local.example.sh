#!/usr/bin/env bash
# Copy to vars.local.sh and customize local/sensitive values.
set -euo pipefail

# Day-1 command mapping overrides — legacy, not read by any active dispatch
# path since Iteration 10 (cluster.sh is now a pure shim to
# cluster-toolchain.sh with no command-hook indirection). Kept commented-out
# for historical reference only.
# export TALOS_DAY1_GENERATE_CMD="..."
# export TALOS_DAY1_PROVISION_CMD="..."
# export TALOS_DAY1_PREPARE_BOOTSTRAP_CMD="..."
# export TALOS_DAY1_APPLY_CONFIG_CMD="..."
# export TALOS_DAY1_BOOTSTRAP_CMD="..."
# export TALOS_DAY1_SYNC_ACCESS_CMD="..."

# Day-1 post-bootstrap baseline overrides
# export TALOS_DAY1_MANIFEST_ROOT_DIR="${WORKSPACE_ROOT}/talos-vsphere-gitops/environments/lab"
# export TALOS_DAY1_KUBE_CONTEXT="admin@<cluster-context>"
# export TALOS_CLUSTER_BASELINE_ADDONS='["cilium","longhorn"]'
# export TALOS_DAY1_REQUIRE_CILIUM="true"

# Environment integration example (vSphere/govc-backed commands)
# Legacy lab adapter compatibility (when mapped commands still use --env=lab):
# export OVERLAY_VARS_FILE="${PROJECT_DIR}/vars.sh"
# export OVERLAY_LOCAL_VARS_FILE="${PROJECT_DIR}/vars.local.sh"
#
# export VSPHERE_ENDPOINT="192.168.0.233"
# export VSPHERE_USERNAME="root"
# export VSPHERE_PASSWORD="CHANGE_ME"
# export VSPHERE_INSECURE_CONNECTION="true"
# export VSPHERE_DATASTORE="DATASTORE_02"
# export VSPHERE_NETWORK="VM Network"
# export VSPHERE_FOLDER=""
# export VSPHERE_RESOURCE_POOL=""
# export SSH_USER="vagrant"
# export HAPROXY_SSH_USER="vagrant"

# Optional topology/network local overrides
# export TALOS_CLUSTER_ENDPOINT="https://192.168.0.30:6443"
# export TALOS_CONTROL_PLANE_IPS='["192.168.0.61","192.168.0.62","192.168.0.63"]'
# export TALOS_WORKER_IPS='["192.168.0.71","192.168.0.72","192.168.0.73"]'
# export TALOS_NAMESERVERS='["192.168.0.53","1.1.1.1","8.8.8.8"]'
