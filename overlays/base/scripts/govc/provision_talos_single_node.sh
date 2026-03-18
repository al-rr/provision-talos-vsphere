#!/usr/bin/env bash
set -euo pipefail

# @file provision_talos_single_node.sh
# @brief Provision a non-HA single-node Talos VM on vSphere/ESXi using govc.

ENV_NAME="lab"
ACTION=""
VM_NAME=""
VM_CPU=""
VM_MEMORY_MB=""
VM_DISK_GB=""
VM_CONFIG_PATH=""
ISO_DATASTORE_PATH=""
VM_NETWORK=""
VM_DATASTORE=""
VM_FOLDER=""
VM_RESOURCE_POOL=""
VM_OVERWRITE=""
VM_POWER_ON=""
VM_FIRMWARE="efi"
VM_GUEST_OS_TYPE="other3xLinux64Guest"
VM_NET_ADAPTER="vmxnet3"
VM_DISK_CONTROLLER="scsi"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] <create|destroy|plan>

Options:
  -e, --env=<env>              Overlay environment (default: lab)
      --name=<vm>              VM name (default: TALOS_SINGLE_NODE_VM_NAME)
      --cpu=<n>                vCPUs
      --memory-mb=<n>          Memory MiB
      --disk-gb=<n>            Disk GiB
      --config=<path>          Talos machine config file
      --iso-path=<path>        Datastore-relative ISO path
      --network=<name>         VM network
      --datastore=<name>       Datastore
      --folder=<path>          VM folder
      --resource-pool=<path>   Resource pool
      --overwrite              Recreate VM if it exists
      --power-on               Power on after create (default)
      --no-power-on            Do not power on after create
  -h, --help                   Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--env) [[ $# -ge 2 ]] || die "Missing value for $1"; ENV_NAME="$2"; shift 2 ;;
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --name=*) VM_NAME="${1#*=}"; shift ;;
      --cpu=*) VM_CPU="${1#*=}"; shift ;;
      --memory-mb=*) VM_MEMORY_MB="${1#*=}"; shift ;;
      --disk-gb=*) VM_DISK_GB="${1#*=}"; shift ;;
      --config=*) VM_CONFIG_PATH="${1#*=}"; shift ;;
      --iso-path=*) ISO_DATASTORE_PATH="${1#*=}"; shift ;;
      --network=*) VM_NETWORK="${1#*=}"; shift ;;
      --datastore=*) VM_DATASTORE="${1#*=}"; shift ;;
      --folder=*) VM_FOLDER="${1#*=}"; shift ;;
      --resource-pool=*) VM_RESOURCE_POOL="${1#*=}"; shift ;;
      --overwrite) VM_OVERWRITE="true"; shift ;;
      --power-on) VM_POWER_ON="true"; shift ;;
      --no-power-on) VM_POWER_ON="false"; shift ;;
      create|destroy|plan) ACTION="$1"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done
}

resolve_path_from_repo() {
  local path_value="$1"
  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
  else
    printf '%s\n' "${REPO_ROOT}/${path_value}"
  fi
}

load_context() {
  load_overlay_vars "${ENV_NAME}"
  export_common_tool_env

  VM_NAME="${VM_NAME:-${TALOS_SINGLE_NODE_VM_NAME:-${TALOS_SIMPLE_VM_NAME:-talos-single-node-01}}}"
  VM_CPU="${VM_CPU:-${TALOS_SINGLE_NODE_CPU:-${TALOS_SIMPLE_CPU:-2}}}"
  VM_MEMORY_MB="${VM_MEMORY_MB:-${TALOS_SINGLE_NODE_MEMORY_MB:-${TALOS_SIMPLE_MEMORY_MB:-4096}}}"
  VM_DISK_GB="${VM_DISK_GB:-${TALOS_SINGLE_NODE_DISK_GB:-${TALOS_SIMPLE_DISK_GB:-20}}}"
  VM_CONFIG_PATH="${VM_CONFIG_PATH:-${TALOS_SINGLE_NODE_CONFIG_PATH:-${TALOS_SIMPLE_CONFIG_PATH:-${TALOS_CONTROL_PLANE_CONFIG_PATH:-}}}}"
  ISO_DATASTORE_PATH="${ISO_DATASTORE_PATH:-${TALOS_ISO_DATASTORE_PATH:-ISOs/talos-v1.12.4-uefi.iso}}"
  VM_NETWORK="${VM_NETWORK:-${GOVC_NETWORK:-${VSPHERE_NETWORK:-}}}"
  VM_DATASTORE="${VM_DATASTORE:-${GOVC_DATASTORE:-${VSPHERE_DATASTORE:-}}}"
  VM_FOLDER="${VM_FOLDER:-${GOVC_FOLDER:-${VSPHERE_FOLDER:-}}}"
  VM_RESOURCE_POOL="${VM_RESOURCE_POOL:-${VSPHERE_RESOURCE_POOL:-}}"
  VM_OVERWRITE="${VM_OVERWRITE:-${GOVC_VM_OVERWRITE:-false}}"
  VM_POWER_ON="${VM_POWER_ON:-${GOVC_VM_POWER_ON:-true}}"

  VM_CONFIG_PATH="$(resolve_path_from_repo "${VM_CONFIG_PATH}")"
}

validate_inputs() {
  [[ -n "${ACTION}" ]] || die "Action is required: create, destroy, or plan."
  [[ "${VM_CPU}" =~ ^[0-9]+$ ]] || die "--cpu must be numeric."
  [[ "${VM_MEMORY_MB}" =~ ^[0-9]+$ ]] || die "--memory-mb must be numeric."
  [[ "${VM_DISK_GB}" =~ ^[0-9]+$ ]] || die "--disk-gb must be numeric."
  [[ -n "${VM_DATASTORE}" ]] || die "Datastore is required."
  [[ -n "${VM_NETWORK}" ]] || die "Network is required."
  [[ -n "${ISO_DATASTORE_PATH}" ]] || die "ISO path is required."
  [[ -n "${GOVC_URL:-}" ]] || die "GOVC_URL is empty."
  [[ -n "${GOVC_USERNAME:-}" ]] || die "GOVC_USERNAME is empty."
  [[ -n "${GOVC_PASSWORD:-}" ]] || die "GOVC_PASSWORD is empty."

  if [[ "${ACTION}" == "create" ]]; then
    [[ -f "${VM_CONFIG_PATH}" ]] || die "Machine config file not found: ${VM_CONFIG_PATH}"
  fi
}

vm_exists() {
  govc find / -type m -name "${VM_NAME}" | grep -qx ".*/${VM_NAME}"
}

ensure_cdrom_device() {
  local device_name=""
  device_name="$(govc device.info -vm "${VM_NAME}" | awk '$1=="Name:" && $2 ~ /^cdrom-/ {print $2; exit}')"
  if [[ -z "${device_name}" ]]; then
    govc device.cdrom.add -vm "${VM_NAME}" >/dev/null
    device_name="$(govc device.info -vm "${VM_NAME}" | awk '$1=="Name:" && $2 ~ /^cdrom-/ {print $2; exit}')"
  fi
  [[ -n "${device_name}" ]] || die "Could not find/add CDROM device for ${VM_NAME}."
  printf '%s\n' "${device_name}"
}

create_vm() {
  local create_args=(vm.create)
  local talos_cfg_b64=""
  local cdrom_device=""
  local iso_full_path=""

  if vm_exists; then
    if [[ "${VM_OVERWRITE}" == "true" ]]; then
      log_warn "VM ${VM_NAME} already exists. Destroying because overwrite=true."
      govc vm.destroy "${VM_NAME}"
    else
      log_warn "VM ${VM_NAME} already exists. Skipping create."
      return 0
    fi
  fi

  talos_cfg_b64="$(base64 -w 0 "${VM_CONFIG_PATH}")"
  iso_full_path="[${VM_DATASTORE}] ${ISO_DATASTORE_PATH}"

  if [[ -n "${VM_FOLDER}" ]]; then
    create_args+=(-folder "${VM_FOLDER}")
  fi
  if [[ -n "${VM_RESOURCE_POOL}" ]]; then
    create_args+=(-pool "${VM_RESOURCE_POOL}")
  fi
  create_args+=(
    -on=false
    -ds "${VM_DATASTORE}"
    -net "${VM_NETWORK}"
    -c "${VM_CPU}"
    -m "${VM_MEMORY_MB}"
    -g "${VM_GUEST_OS_TYPE}"
    -firmware "${VM_FIRMWARE}"
    -disk "${VM_DISK_GB}G"
    -disk.controller "${VM_DISK_CONTROLLER}"
    -net.adapter "${VM_NET_ADAPTER}"
    "${VM_NAME}"
  )
  govc "${create_args[@]}"

  govc vm.change \
    -vm "${VM_NAME}" \
    -e "guestinfo.talos.config=${talos_cfg_b64}" \
    -e "guestinfo.talos.config.encoding=base64" \
    -e "disk.enableUUID=1"

  govc vm.network.change -vm "${VM_NAME}" -net "${VM_NETWORK}" ethernet-0

  cdrom_device="$(ensure_cdrom_device)"
  govc device.cdrom.insert -vm "${VM_NAME}" -device "${cdrom_device}" "${iso_full_path}"

  if [[ "${VM_POWER_ON}" == "true" ]]; then
    govc vm.power -on "${VM_NAME}"
  fi
}

destroy_vm() {
  if vm_exists; then
    log_info "Destroying VM ${VM_NAME}"
    govc vm.destroy "${VM_NAME}"
  else
    log_warn "VM ${VM_NAME} not found. Skipping destroy."
  fi
}

main() {
  parse_args "$@"
  load_context
  validate_inputs

  log_info "Talos single-node plan env=${ENV_NAME} action=${ACTION} name=${VM_NAME}"
  log_info "cpu=${VM_CPU} mem=${VM_MEMORY_MB} disk=${VM_DISK_GB} network=${VM_NETWORK} datastore=${VM_DATASTORE}"
  log_info "iso=[${VM_DATASTORE}] ${ISO_DATASTORE_PATH}"
  log_info "config=${VM_CONFIG_PATH}"

  if [[ "${ACTION}" == "plan" ]]; then
    exit 0
  fi

  case "${ACTION}" in
    create) create_vm ;;
    destroy) destroy_vm ;;
    *) die "Unsupported action: ${ACTION}" ;;
  esac

  log_info "Action '${ACTION}' completed successfully."
}

main "$@"
