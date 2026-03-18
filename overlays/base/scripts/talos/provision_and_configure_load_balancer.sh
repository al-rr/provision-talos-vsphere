#!/usr/bin/env bash
# @file provision_and_configure_load_balancer.sh
# @brief Orchestrate LB provisioning and Talos backend configuration in one flow.
# @description
#   Step 1: Reuse overlays/base/scripts/ha-proxy/run-full.sh to provision and configure
#   HAProxy nodes (optionally with Keepalived in HA mode).
#   Step 2: Reuse overlays/base/scripts/talos/configure_load_balancer.sh to configure
#   HAProxy backend servers for Talos control-plane endpoints.

set -euo pipefail

ENV_NAME="lab"
CUSTOM_VARS_FILE=""
DRY_RUN="false"
HA_MODE="true"
VM_COUNT=""
VM_PREFIX="talos-lb"
VM_MODE="auto"
VM_OVERWRITE="false"
SSH_USER=""
SSH_PORT="22"
SSH_KEY=""
SSH_KEY_DIR=""
CP_IPS_OVERRIDE=""
LB_HOSTS_OVERRIDE=""
BOOTSTRAP_FILE_OVERRIDE=""
SKIP_PROVISION="false"
SKIP_BACKEND="false"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BASE_SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=/dev/null
source "${BASE_SCRIPT_DIR}/functions.sh"

LB_PROVISION_SCRIPT="${REPO_ROOT}/overlays/base/scripts/ha-proxy/run-full.sh"
LB_BACKEND_SCRIPT="${REPO_ROOT}/overlays/base/scripts/talos/configure_load_balancer.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
      --env=<env>              Overlay environment (default: lab)
      --vars-file=<path>       Optional vars file with overrides
      --ha                     HA mode (Keepalived enabled; default)
      --no-ha                  Non-HA mode (Keepalived disabled)
      --count=<n>              VM count for provisioning
      --prefix=<name>          VM prefix (default: talos-lb)
      --mode=<name>            govc mode: auto|ova|ovf|clone|empty
      --overwrite              Recreate VMs during provisioning
      --user=<user>            SSH user used by both steps
      --port=<port>            SSH port used by both steps (default: 22)
      --ssh-key=<path>         SSH private key used by both steps
      --ssh-key-dir=<path>     SSH key directory for provision step
      --cp-ips=<list>          Control-plane IPs override for backend setup
      --lb-hosts=<list>        LB host IPs override for backend setup
      --bootstrap-file=<path>  bootstrap-ips.txt fallback for backend setup
      --skip-provision         Skip step 1 (provision/configure HAProxy nodes)
      --skip-backend           Skip step 2 (configure Talos backend in HAProxy)
      --dry-run                Print actions without applying
  -h, --help                   Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --vars-file=*) CUSTOM_VARS_FILE="${1#*=}"; shift ;;
      --ha) HA_MODE="true"; shift ;;
      --no-ha) HA_MODE="false"; shift ;;
      --count=*) VM_COUNT="${1#*=}"; shift ;;
      --prefix=*) VM_PREFIX="${1#*=}"; shift ;;
      --mode=*) VM_MODE="${1#*=}"; shift ;;
      --overwrite) VM_OVERWRITE="true"; shift ;;
      --user=*) SSH_USER="${1#*=}"; shift ;;
      --port=*) SSH_PORT="${1#*=}"; shift ;;
      --ssh-key=*) SSH_KEY="${1#*=}"; shift ;;
      --ssh-key-dir=*) SSH_KEY_DIR="${1#*=}"; shift ;;
      --cp-ips=*) CP_IPS_OVERRIDE="${1#*=}"; shift ;;
      --lb-hosts=*) LB_HOSTS_OVERRIDE="${1#*=}"; shift ;;
      --bootstrap-file=*) BOOTSTRAP_FILE_OVERRIDE="${1#*=}"; shift ;;
      --skip-provision) SKIP_PROVISION="true"; shift ;;
      --skip-backend) SKIP_BACKEND="true"; shift ;;
      --dry-run) DRY_RUN="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done
}

validate_args() {
  [[ -n "${ENV_NAME}" ]] || die "--env cannot be empty."
  [[ "${HA_MODE}" == "true" || "${HA_MODE}" == "false" ]] || die "HA mode must be true or false."
  [[ "${SSH_PORT}" =~ ^[0-9]+$ ]] || die "--port must be numeric."
  if [[ -n "${SSH_KEY}" ]]; then
    [[ -f "${SSH_KEY}" ]] || die "SSH key not found: ${SSH_KEY}"
  fi
  if [[ -n "${SSH_KEY_DIR}" ]]; then
    [[ -d "${SSH_KEY_DIR}" ]] || die "SSH key directory not found: ${SSH_KEY_DIR}"
  fi
  require_file "${LB_PROVISION_SCRIPT}"
  require_file "${LB_BACKEND_SCRIPT}"
}

load_context() {
  load_overlay_vars "${ENV_NAME}"
  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    local resolved_vars_file=""
    if [[ "${CUSTOM_VARS_FILE}" = /* ]]; then
      resolved_vars_file="${CUSTOM_VARS_FILE}"
    else
      resolved_vars_file="${REPO_ROOT}/${CUSTOM_VARS_FILE}"
    fi
    require_file "${resolved_vars_file}"
    # shellcheck disable=SC1090
    source "${resolved_vars_file}"
  fi
}

resolve_defaults() {
  if [[ -z "${SSH_USER}" ]]; then
    SSH_USER="${HAPROXY_SSH_USER:-${ANSIBLE_USER:-${BUILD_USERNAME:-root}}}"
  fi
}

run_or_echo() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

main() {
  local provision_cmd=("${LB_PROVISION_SCRIPT}" "--env=${ENV_NAME}" "--prefix=${VM_PREFIX}" "--mode=${VM_MODE}")
  local backend_cmd=("${LB_BACKEND_SCRIPT}" "--env=${ENV_NAME}" "--port=${SSH_PORT}")

  parse_args "$@"
  validate_args
  load_context
  resolve_defaults

  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    provision_cmd+=("--vars-file=${CUSTOM_VARS_FILE}")
    backend_cmd+=("--vars-file=${CUSTOM_VARS_FILE}")
  fi
  if [[ -n "${VM_COUNT}" ]]; then
    provision_cmd+=("--count=${VM_COUNT}")
  fi
  if [[ "${VM_OVERWRITE}" == "true" ]]; then
    provision_cmd+=("--overwrite")
  fi
  if [[ "${HA_MODE}" == "true" ]]; then
    provision_cmd+=("--ha")
  else
    provision_cmd+=("--no-ha")
  fi
  if [[ -n "${SSH_USER}" ]]; then
    provision_cmd+=("--user=${SSH_USER}")
    backend_cmd+=("--user=${SSH_USER}")
  fi
  if [[ -n "${SSH_KEY}" ]]; then
    provision_cmd+=("--ssh-key=${SSH_KEY}")
    backend_cmd+=("--ssh-key=${SSH_KEY}")
  fi
  if [[ -n "${SSH_KEY_DIR}" ]]; then
    provision_cmd+=("--ssh-key-dir=${SSH_KEY_DIR}")
  fi
  if [[ -n "${CP_IPS_OVERRIDE}" ]]; then
    backend_cmd+=("--cp-ips=${CP_IPS_OVERRIDE}")
  fi
  if [[ -n "${LB_HOSTS_OVERRIDE}" ]]; then
    backend_cmd+=("--lb-hosts=${LB_HOSTS_OVERRIDE}")
  fi
  if [[ -n "${BOOTSTRAP_FILE_OVERRIDE}" ]]; then
    backend_cmd+=("--bootstrap-file=${BOOTSTRAP_FILE_OVERRIDE}")
  fi
  if [[ "${DRY_RUN}" == "true" ]]; then
    provision_cmd+=("--dry-run")
    backend_cmd+=("--dry-run")
  fi

  if [[ "${SKIP_PROVISION}" != "true" ]]; then
    log_info "Step 1/2: Provision/configure HAProxy nodes (HA mode: ${HA_MODE})"
    run_or_echo "${provision_cmd[@]}"
  else
    log_info "Step 1/2 skipped: HAProxy provisioning/configuration"
  fi

  if [[ "${SKIP_BACKEND}" != "true" ]]; then
    log_info "Step 2/2: Configure Talos control-plane backend in HAProxy"
    run_or_echo "${backend_cmd[@]}"
  else
    log_info "Step 2/2 skipped: HAProxy backend configuration"
  fi

  log_info "Load balancer orchestration finished."
}

main "$@"
