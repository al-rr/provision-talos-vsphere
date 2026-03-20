#!/usr/bin/env bash
# @file install.sh
# @brief Install DNS service package (dnsmasq by default) on local or remote host.
# @description
#   Installs DNS package with apt/dnf/yum, enables the service, and ensures it is running.
#
# @arg --env,-e string Overlay environment. Defaults to lab.
# @arg --host string Remote host. If omitted, runs locally.
# @arg --user string SSH user for remote execution. Defaults to root.
# @arg --port string SSH port for remote execution. Defaults to 22.
# @arg --ssh-key string SSH private key path for remote execution.
# @flag --dry-run,-n Print mutating actions without applying changes.
# @flag --help,-h Show usage.

set -euo pipefail

ENV_NAME="lab"
DRY_RUN="false"
SSH_HOST=""
SSH_USER="root"
SSH_PORT="22"
SSH_KEY=""
CUSTOM_VARS_FILE=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BASE_SCRIPT_DIR}/../../.." && pwd)"

# shellcheck disable=SC1091
source "${BASE_SCRIPT_DIR}/functions.sh"

TARGET_MODE="local"
TARGET_LABEL="local host"
TARGET_SUDO=""
DNS_PACKAGE_NAME_RESOLVED="dnsmasq"
DNS_SERVICE_NAME_RESOLVED="dnsmasq"

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options]

Options:
  -e, --env=<env>       Overlay environment (default: lab)
      --host=<host>     Remote host (optional)
      --user=<user>     Remote SSH user (default: root)
      --port=<port>     Remote SSH port (default: 22)
      --ssh-key=<path>  SSH private key path
      --vars-file=<path> Optional vars override file
  -n, --dry-run         Show mutating commands only
  -h, --help            Show this help
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--env)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        ENV_NAME="$2"
        shift 2
        ;;
      --env=*)
        ENV_NAME="${1#*=}"
        shift
        ;;
      --host)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        SSH_HOST="$2"
        shift 2
        ;;
      --host=*)
        SSH_HOST="${1#*=}"
        shift
        ;;
      --user)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        SSH_USER="$2"
        shift 2
        ;;
      --user=*)
        SSH_USER="${1#*=}"
        shift
        ;;
      --port)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        SSH_PORT="$2"
        shift 2
        ;;
      --port=*)
        SSH_PORT="${1#*=}"
        shift
        ;;
      --ssh-key)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        SSH_KEY="$2"
        shift 2
        ;;
      --ssh-key=*)
        SSH_KEY="${1#*=}"
        shift
        ;;
      --vars-file=*)
        CUSTOM_VARS_FILE="${1#*=}"
        shift
        ;;
      -n|--dry-run)
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
  [[ -n "${ENV_NAME}" ]] || die "Environment cannot be empty."

  if [[ -z "${SSH_HOST}" ]]; then
    [[ -z "${SSH_KEY}" ]] || die "--ssh-key requires --host."
    [[ "${SSH_USER}" == "root" ]] || die "--user requires --host."
    [[ "${SSH_PORT}" == "22" ]] || die "--port requires --host."
    return 0
  fi

  [[ -n "${SSH_USER}" ]] || die "Remote --user cannot be empty."
  [[ "${SSH_PORT}" =~ ^[0-9]+$ ]] || die "--port must be numeric."
  [[ "${SSH_PORT}" -ge 1 && "${SSH_PORT}" -le 65535 ]] || die "--port must be between 1 and 65535."
  [[ -z "${SSH_KEY}" || -f "${SSH_KEY}" ]] || die "SSH key file not found: ${SSH_KEY}"
}

init_target_mode() {
  if [[ -n "${SSH_HOST}" ]]; then
    TARGET_MODE="remote"
    TARGET_LABEL="${SSH_USER}@${SSH_HOST}:${SSH_PORT}"
  fi
}

run_check_target() {
  local cmd="$1"
  local escaped=""
  local ssh_args=()

  if [[ "${TARGET_MODE}" == "remote" ]]; then
    printf -v escaped '%q' "${cmd}"
    ssh_args=(-F /dev/null -p "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
    [[ -n "${SSH_KEY}" ]] && ssh_args+=(-i "${SSH_KEY}")
    ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}" >/dev/null 2>&1
    return $?
  fi

  bash -lc "${cmd}" >/dev/null 2>&1
}

run_target() {
  local cmd="$1"
  local escaped=""
  local ssh_args=()

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] (${TARGET_LABEL}) ${cmd}"
    return 0
  fi

  if [[ "${TARGET_MODE}" == "remote" ]]; then
    printf -v escaped '%q' "${cmd}"
    ssh_args=(-F /dev/null -p "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
    [[ -n "${SSH_KEY}" ]] && ssh_args+=(-i "${SSH_KEY}")
    ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}"
    return 0
  fi

  bash -lc "${cmd}"
}

as_root_cmd() {
  local cmd="$1"
  local escaped=""
  if [[ -n "${TARGET_SUDO}" ]]; then
    printf -v escaped '%q' "${cmd}"
    printf '%s bash -lc %s' "${TARGET_SUDO}" "${escaped}"
  else
    printf '%s' "${cmd}"
  fi
}

detect_target_sudo() {
  if run_check_target "id -u | grep -qx 0"; then
    TARGET_SUDO=""
    return 0
  fi

  if run_check_target "command -v sudo >/dev/null 2>&1"; then
    TARGET_SUDO="sudo -n"
    return 0
  fi

  die "Target user is not root and sudo is unavailable on ${TARGET_LABEL}."
}

load_env() {
  load_overlay_vars "${ENV_NAME}"

  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    if [[ "${CUSTOM_VARS_FILE}" != /* ]]; then
      CUSTOM_VARS_FILE="${REPO_ROOT}/${CUSTOM_VARS_FILE}"
    fi
    require_file "${CUSTOM_VARS_FILE}"
    # shellcheck disable=SC1090
    source "${CUSTOM_VARS_FILE}"
  fi

  DNS_PACKAGE_NAME_RESOLVED="${DNS_PACKAGE_NAME:-dnsmasq}"
  DNS_SERVICE_NAME_RESOLVED="${DNS_SERVICE_NAME:-dnsmasq}"
}

install_dns_package() {
  if run_check_target "command -v apt-get >/dev/null 2>&1"; then
    run_target "$(as_root_cmd "DEBIAN_FRONTEND=noninteractive apt-get update -y")"
    run_target "$(as_root_cmd "DEBIAN_FRONTEND=noninteractive apt-get install -y ${DNS_PACKAGE_NAME_RESOLVED}")"
    return 0
  fi

  if run_check_target "command -v dnf >/dev/null 2>&1"; then
    run_target "$(as_root_cmd "dnf install -y ${DNS_PACKAGE_NAME_RESOLVED}")"
    return 0
  fi

  if run_check_target "command -v yum >/dev/null 2>&1"; then
    run_target "$(as_root_cmd "yum install -y ${DNS_PACKAGE_NAME_RESOLVED}")"
    return 0
  fi

  die "No supported package manager found on ${TARGET_LABEL} (apt/dnf/yum)."
}

enable_and_start_service() {
  run_target "$(as_root_cmd "systemctl enable ${DNS_SERVICE_NAME_RESOLVED}")"
  run_target "$(as_root_cmd "systemctl restart ${DNS_SERVICE_NAME_RESOLVED}")"
  run_target "$(as_root_cmd "systemctl is-active --quiet ${DNS_SERVICE_NAME_RESOLVED}")"
}

main() {
  parse_args "$@"
  validate_args
  init_target_mode
  load_env
  detect_target_sudo

  log_info "Installing ${DNS_PACKAGE_NAME_RESOLVED} on ${TARGET_LABEL}"
  install_dns_package
  enable_and_start_service
  log_info "DNS service ${DNS_SERVICE_NAME_RESOLVED} is active on ${TARGET_LABEL}"
}

main "$@"
