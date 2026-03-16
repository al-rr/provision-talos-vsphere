#!/usr/bin/env bash
set -euo pipefail

# @describe Reusable govc helper to prepare HAProxy VMs from overlay variables.
# @option --env Target overlay environment. Defaults to prod.
# @option --node Target node: 1, 2, or all. Defaults to all.
# @arg action string Required action: create or destroy.

ENV_NAME="prod"
NODE_SELECTOR="all"
ACTION=""

for arg in "$@"; do
  case "$arg" in
    --env=*)
      ENV_NAME="${arg#*=}"
      ;;
    --node=*)
      NODE_SELECTOR="${arg#*=}"
      ;;
    create|destroy)
      ACTION="$arg"
      ;;
    *)
      echo "Usage: $0 [--env=<env>] [--node=1|2|all] <create|destroy>"
      exit 1
      ;;
  esac
done

if [[ -z "${ACTION}" ]]; then
  echo "Usage: $0 [--env=<env>] [--node=1|2|all] <create|destroy>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"
load_overlay_vars "${ENV_NAME}"
export_common_tool_env

vm_cpu="${TF_VM_CPUS:-2}"
vm_memory_mb="${TF_VM_MEMORY_MB:-4096}"
vm_disk_gb="${TF_VM_DISK_GB:-40}"
vm_disk_name="${HAPROXY_VM_DISK_NAME:-disk-1000-0}"

create_node() {
  local vm_name="$1"

  log_info "Preparing HAProxy VM ${vm_name}"
  govc vm.change \
    -c "${vm_cpu}" \
    -m "${vm_memory_mb}" \
    -e "disk.enableUUID=1" \
    -vm "${vm_name}"

  govc vm.disk.change -vm "${vm_name}" -disk.name "${vm_disk_name}" -size "${vm_disk_gb}G"

  if [[ -n "${GOVC_NETWORK:-}" ]]; then
    log_info "Configuring network ${GOVC_NETWORK} on ${vm_name}"
    govc vm.network.change -vm "${vm_name}" -net "${GOVC_NETWORK}" ethernet-0
  else
    log_warn "GOVC_NETWORK is not set. Keeping the current network for ${vm_name}."
  fi

  govc vm.power -on "${vm_name}"
}

destroy_node() {
  local vm_name="$1"
  log_info "Destroying HAProxy VM ${vm_name}"
  govc vm.destroy "${vm_name}"
}

run_action() {
  local vm_name="$1"
  case "${ACTION}" in
    create) create_node "${vm_name}" ;;
    destroy) destroy_node "${vm_name}" ;;
  esac
}

case "${NODE_SELECTOR}" in
  1)
    run_action "${HAPROXY_NODE_1_NAME}"
    ;;
  2)
    run_action "${HAPROXY_NODE_2_NAME}"
    ;;
  all)
    run_action "${HAPROXY_NODE_1_NAME}"
    run_action "${HAPROXY_NODE_2_NAME}"
    ;;
  *)
    die "Invalid --node value: ${NODE_SELECTOR}. Use 1, 2, or all."
    ;;
esac