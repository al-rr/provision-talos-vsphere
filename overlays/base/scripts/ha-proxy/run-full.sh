#!/usr/bin/env bash
# @file run-full.sh
# @brief Orchestrate full HAProxy HA lifecycle for a two-node pair.
# @description
#   Provisions the HAProxy VMs via govc and then reuses the HAProxy and
#   Keepalived install/setup scripts to configure both nodes over SSH.

set -euo pipefail

ENV_NAME="lab"
CUSTOM_VARS_FILE=""
VM_COUNT="2"
VM_PREFIX="talos-lb"
VM_MODE="auto"
VM_OVERWRITE="false"
HA_MODE="true"
SKIP_PROVISION="false"
SKIP_HAPROXY="false"
SKIP_KEEPALIVED="false"
DRY_RUN="false"
SSH_USER=""
SSH_PORT="22"
SSH_KEY=""
SSH_KEY_DIR=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BASE_SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=/dev/null
source "${BASE_SCRIPT_DIR}/functions.sh"

GOVC_PROVISION_SCRIPT="${REPO_ROOT}/overlays/base/scripts/govc/provision_haproxy.sh"
HAPROXY_INSTALL_SCRIPT="${SCRIPT_DIR}/install.sh"
HAPROXY_SETUP_SCRIPT="${SCRIPT_DIR}/setup.sh"
KEEPALIVED_INSTALL_SCRIPT="${REPO_ROOT}/overlays/base/scripts/keepalived/install.sh"
KEEPALIVED_SETUP_SCRIPT="${REPO_ROOT}/overlays/base/scripts/keepalived/setup.sh"

NODE_1_NAME=""
NODE_2_NAME=""
NODE_1_HOST=""
NODE_2_HOST=""
NODE_1_KEY=""
NODE_2_KEY=""
NODE_1_PRIORITY=""
NODE_2_PRIORITY=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
      --env=<env>              Overlay environment (default: lab)
      --vars-file=<path>       Optional shell vars file with overrides
      --count=<n>              Number of VMs to manage (default: 2)
      --prefix=<name>          VM name prefix (default: talos-lb)
      --mode=<name>            govc provision mode (default: auto)
      --overwrite              Recreate existing VMs during provisioning
      --ha                     Configure load balancer in HA mode (default)
      --no-ha                  Configure only HAProxy (skip Keepalived/VIP)
      --skip-provision         Skip govc provisioning
      --skip-haproxy           Skip HAProxy install/setup
      --skip-keepalived        Skip Keepalived install/setup
      --user=<user>            SSH user for remote configuration
      --port=<port>            SSH port for remote configuration (default: 22)
      --ssh-key=<path>         SSH private key used for both nodes
      --ssh-key-dir=<path>     Directory used to auto-discover per-node SSH keys
      --dry-run                Print actions without applying changes
  -h, --help                   Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env=*)
        ENV_NAME="${1#*=}"
        shift
        ;;
      --vars-file=*)
        CUSTOM_VARS_FILE="${1#*=}"
        shift
        ;;
      --count=*)
        VM_COUNT="${1#*=}"
        shift
        ;;
      --prefix=*)
        VM_PREFIX="${1#*=}"
        shift
        ;;
      --mode=*)
        VM_MODE="${1#*=}"
        shift
        ;;
      --overwrite)
        VM_OVERWRITE="true"
        shift
        ;;
      --ha)
        HA_MODE="true"
        shift
        ;;
      --no-ha)
        HA_MODE="false"
        shift
        ;;
      --skip-provision)
        SKIP_PROVISION="true"
        shift
        ;;
      --skip-haproxy)
        SKIP_HAPROXY="true"
        shift
        ;;
      --skip-keepalived)
        SKIP_KEEPALIVED="true"
        shift
        ;;
      --user=*)
        SSH_USER="${1#*=}"
        shift
        ;;
      --port=*)
        SSH_PORT="${1#*=}"
        shift
        ;;
      --ssh-key=*)
        SSH_KEY="${1#*=}"
        shift
        ;;
      --ssh-key-dir=*)
        SSH_KEY_DIR="${1#*=}"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        die "Unknown argument: $1"
        ;;
    esac
  done
}

validate_args() {
  [[ -n "${ENV_NAME}" ]] || die "--env cannot be empty."
  [[ "${VM_COUNT}" =~ ^[0-9]+$ ]] || die "--count must be numeric."
  [[ "${VM_COUNT}" -ge 1 ]] || die "--count must be at least 1."
  [[ "${VM_COUNT}" -le 2 ]] || die "This orchestrator currently supports up to 2 nodes."
  [[ -n "${VM_PREFIX}" ]] || die "--prefix cannot be empty."
  [[ -n "${VM_MODE}" ]] || die "--mode cannot be empty."
  [[ "${SSH_PORT}" =~ ^[0-9]+$ ]] || die "--port must be numeric."
  [[ "${HA_MODE}" == "true" || "${HA_MODE}" == "false" ]] || die "HA mode must be true or false."
  if [[ "${HA_MODE}" == "true" && "${VM_COUNT}" -lt 2 ]]; then
    die "HA mode requires at least 2 nodes."
  fi

  if [[ -n "${SSH_KEY}" ]]; then
    [[ -f "${SSH_KEY}" ]] || die "SSH key file not found: ${SSH_KEY}"
  fi

  if [[ -n "${SSH_KEY_DIR}" ]]; then
    [[ -d "${SSH_KEY_DIR}" ]] || die "SSH key directory not found: ${SSH_KEY_DIR}"
  fi

  require_file "${GOVC_PROVISION_SCRIPT}"
  require_file "${HAPROXY_INSTALL_SCRIPT}"
  require_file "${HAPROXY_SETUP_SCRIPT}"
  require_file "${KEEPALIVED_INSTALL_SCRIPT}"
  require_file "${KEEPALIVED_SETUP_SCRIPT}"
}

load_context() {
  load_overlay_vars "${ENV_NAME}"
  export_common_tool_env

  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    if [[ "${CUSTOM_VARS_FILE}" != /* ]]; then
      CUSTOM_VARS_FILE="${REPO_ROOT}/${CUSTOM_VARS_FILE}"
    fi
    require_file "${CUSTOM_VARS_FILE}"
    # shellcheck disable=SC1090
    source "${CUSTOM_VARS_FILE}"
  fi
}

resolve_defaults() {
  local build_user_default=""

  NODE_1_NAME="${VM_PREFIX}-1"
  NODE_2_NAME=""
  if [[ "${VM_COUNT}" -ge 2 ]]; then
    NODE_2_NAME="${VM_PREFIX}-2"
  fi

  build_user_default="${BUILD_USERNAME:-}"
  if [[ -z "${build_user_default}" && "${ENV_NAME}" == "lab" ]]; then
    build_user_default="vagrant"
  fi
  SSH_USER="${SSH_USER:-${build_user_default:-root}}"

  NODE_1_PRIORITY="${KEEPALIVED_MASTER_PRIORITY:-$(( ${KEEPALIVED_PRIORITY:-100} + 20 ))}"
  if [[ -n "${NODE_2_NAME}" ]]; then
    NODE_2_PRIORITY="${KEEPALIVED_BACKUP_PRIORITY:-${KEEPALIVED_PRIORITY:-100}}"
  fi

  if [[ -z "${SSH_KEY_DIR}" && "${ENV_NAME}" == "lab" ]]; then
    SSH_KEY_DIR="${REPO_ROOT}/overlays/lab/.vagrant/machines"
  fi
}

format_cmd() {
  local out=""
  local arg=""
  for arg in "$@"; do
    printf -v out '%s%q ' "${out}" "${arg}"
  done
  printf '%s\n' "${out% }"
}

run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] $(format_cmd "$@")"
    return 0
  fi
  "$@"
}

resolve_vm_ip() {
  local vm_name="$1"
  local fallback_ip="$2"
  local ip=""

  ip="$(govc vm.ip -v4 -wait 2m "${vm_name}" 2>/dev/null | awk 'NF {print $1; exit}' || true)"

  if [[ -z "${ip}" ]]; then
    ip="${fallback_ip}"
  fi

  [[ -n "${ip}" ]] || die "Could not resolve an IP for ${vm_name}. Set overlay IPs or ensure VMware Tools reports guest IP."
  printf '%s\n' "${ip}"
}

resolve_node_key() {
  local node_name="$1"
  local candidate=""

  if [[ -n "${SSH_KEY}" ]]; then
    printf '%s\n' "${SSH_KEY}"
    return 0
  fi

  if [[ -n "${SSH_KEY_DIR}" ]]; then
    candidate="${SSH_KEY_DIR}/${node_name}.key"
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi

    candidate="$(find "${SSH_KEY_DIR}" -path "*/${node_name}/*/private_key" -type f 2>/dev/null | sort | head -n 1 || true)"
    if [[ -n "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  if [[ -n "${ANSIBLE_PRIVATE_KEY_FILE:-}" && -f "${ANSIBLE_PRIVATE_KEY_FILE}" ]]; then
    printf '%s\n' "${ANSIBLE_PRIVATE_KEY_FILE}"
    return 0
  fi

  printf '\n'
}

resolve_nodes() {
  NODE_1_HOST="$(resolve_vm_ip "${NODE_1_NAME}" "${HAPROXY_NODE_1_IP:-}")"
  NODE_1_KEY="$(resolve_node_key "${NODE_1_NAME}")"

  log_info "Resolved node 1: ${NODE_1_NAME} -> ${NODE_1_HOST}"
  if [[ -n "${NODE_2_NAME}" ]]; then
    NODE_2_HOST="$(resolve_vm_ip "${NODE_2_NAME}" "${HAPROXY_NODE_2_IP:-}")"
    NODE_2_KEY="$(resolve_node_key "${NODE_2_NAME}")"
    log_info "Resolved node 2: ${NODE_2_NAME} -> ${NODE_2_HOST}"
  fi

  if [[ -n "${NODE_1_KEY}" ]]; then
    log_info "Resolved SSH key for ${NODE_1_NAME}: ${NODE_1_KEY}"
  else
    log_warn "No SSH key discovered for ${NODE_1_NAME}; SSH agent/default key must work."
  fi

  if [[ -n "${NODE_2_NAME}" ]]; then
    if [[ -n "${NODE_2_KEY}" ]]; then
      log_info "Resolved SSH key for ${NODE_2_NAME}: ${NODE_2_KEY}"
    else
      log_warn "No SSH key discovered for ${NODE_2_NAME}; SSH agent/default key must work."
    fi
  fi
}

append_remote_args() {
  local -n args_ref=$1
  local host="$2"
  local key_path="$3"

  args_ref+=("--host=${host}" "--user=${SSH_USER}" "--port=${SSH_PORT}")
  if [[ -n "${key_path}" ]]; then
    args_ref+=("--ssh-key=${key_path}")
  fi
  if [[ "${DRY_RUN}" == "true" ]]; then
    args_ref+=("--dry-run")
  fi
}

run_provision() {
  local cmd=("${GOVC_PROVISION_SCRIPT}" "--env=${ENV_NAME}")

  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    cmd+=("--vars-file=${CUSTOM_VARS_FILE}")
  fi
  cmd+=("--count=${VM_COUNT}" "--prefix=${VM_PREFIX}" "--mode=${VM_MODE}")
  if [[ "${VM_OVERWRITE}" == "true" ]]; then
    cmd+=("--overwrite")
  fi
  if [[ "${DRY_RUN}" == "true" ]]; then
    cmd+=("--dry-run")
  fi
  cmd+=("create")

  log_info "Running govc provisioning step"
  run_cmd "${cmd[@]}"
}

run_haproxy_for_node() {
  local host="$1"
  local key_path="$2"
  local install_cmd=("${HAPROXY_INSTALL_SCRIPT}" "--env=${ENV_NAME}")
  local setup_cmd=("${HAPROXY_SETUP_SCRIPT}" "--env=${ENV_NAME}")

  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    # The called scripts do not support vars-file, so we preload vars in this process only.
    :
  fi

  append_remote_args install_cmd "${host}" "${key_path}"
  append_remote_args setup_cmd "${host}" "${key_path}"

  run_cmd "${install_cmd[@]}"
  run_cmd "${setup_cmd[@]}"
}

run_keepalived_for_node() {
  local host="$1"
  local key_path="$2"
  local state="$3"
  local priority="$4"
  local src_ip="$5"
  local peers="$6"
  local install_cmd=("${KEEPALIVED_INSTALL_SCRIPT}" "--env=${ENV_NAME}")
  local setup_cmd=(
    "${KEEPALIVED_SETUP_SCRIPT}"
    "--env=${ENV_NAME}"
    "--state=${state}"
    "--priority=${priority}"
    "--src-ip=${src_ip}"
    "--peers=${peers}"
    "--vips=${KEEPALIVED_VIPS:-}"
  )

  if [[ -n "${KEEPALIVED_INTERFACE:-}" && "${KEEPALIVED_INTERFACE}" != "auto" ]]; then
    setup_cmd+=("--interface=${KEEPALIVED_INTERFACE}")
  fi

  append_remote_args install_cmd "${host}" "${key_path}"
  append_remote_args setup_cmd "${host}" "${key_path}"

  run_cmd "${install_cmd[@]}"
  run_cmd "${setup_cmd[@]}"
}

run_haproxy_steps() {
  log_info "Running HAProxy install/setup"
  run_haproxy_for_node "${NODE_1_HOST}" "${NODE_1_KEY}"
  if [[ -n "${NODE_2_NAME}" ]]; then
    run_haproxy_for_node "${NODE_2_HOST}" "${NODE_2_KEY}"
  fi
}

run_keepalived_steps() {
  log_info "Running Keepalived install/setup on both nodes"
  run_keepalived_for_node "${NODE_1_HOST}" "${NODE_1_KEY}" "MASTER" "${NODE_1_PRIORITY}" "${NODE_1_HOST}" "${NODE_2_HOST}"
  run_keepalived_for_node "${NODE_2_HOST}" "${NODE_2_KEY}" "BACKUP" "${NODE_2_PRIORITY}" "${NODE_2_HOST}" "${NODE_1_HOST}"
}

main() {
  parse_args "$@"
  validate_args
  load_context
  resolve_defaults
  if [[ "${HA_MODE}" != "true" ]]; then
    SKIP_KEEPALIVED="true"
  fi
  log_info "HA mode: ${HA_MODE}"

  if [[ "${SKIP_PROVISION}" != "true" ]]; then
    run_provision
  else
    log_info "Skipping govc provisioning step"
  fi

  resolve_nodes

  if [[ "${SKIP_HAPROXY}" != "true" ]]; then
    run_haproxy_steps
  else
    log_info "Skipping HAProxy install/setup steps"
  fi

  if [[ "${SKIP_KEEPALIVED}" != "true" ]]; then
    run_keepalived_steps
  else
    log_info "Skipping Keepalived install/setup steps (HA disabled or explicit skip)"
  fi

  log_info "Full HAProxy HA orchestration completed."
}

main "$@"
