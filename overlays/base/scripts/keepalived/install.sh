#!/usr/bin/env bash
# @file install.sh
# @brief Install and start Keepalived on a local or remote Linux host.
# @description
#   Installs Keepalived with apt/dnf/yum, enables the service, and ensures it is running.
#   Supports direct local execution or remote execution through SSH.
#
# @arg --env,-e string Overlay environment name. Defaults to lab.
# @arg --host string Remote host. If omitted, runs locally.
# @arg --user string SSH user for remote execution. Defaults to root.
# @arg --port string SSH port for remote execution. Defaults to 22.
# @arg --ssh-key string SSH private key path for remote execution.
# @flag --dry-run,-n Print mutating actions without applying changes.
# @flag --help,-h Show usage information.
#
# @example
#   ./overlays/base/scripts/keepalived/install.sh --env=lab
# @example
#   ./overlays/base/scripts/keepalived/install.sh --env=lab --host=172.17.20.181 --user=vagrant --ssh-key=/tmp/talos-lb-1.key

set -euo pipefail

ENV_NAME="lab"
DRY_RUN="false"
SSH_HOST=""
SSH_USER="root"
SSH_PORT="22"
SSH_KEY=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${BASE_SCRIPT_DIR}/functions.sh"

TARGET_MODE="local"
TARGET_LABEL="local host"
TARGET_SUDO=""
KEEPALIVED_SERVICE_NAME_RESOLVED="keepalived"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -e, --env=<env>       Overlay environment (default: lab)
      --host=<host>     Remote host (optional)
      --user=<user>     Remote SSH user (default: root)
      --port=<port>     Remote SSH port (default: 22)
      --ssh-key=<path>  SSH private key for remote mode
  -n, --dry-run         Show mutating commands without executing
  -h, --help            Show this help
EOF
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

  if [[ -n "${SSH_KEY}" ]]; then
    [[ -f "${SSH_KEY}" ]] || die "SSH key file not found: ${SSH_KEY}"
  fi
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
    if [[ -n "${SSH_KEY}" ]]; then
      ssh_args+=(-i "${SSH_KEY}")
      ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}" >/dev/null 2>&1
    else
      ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}" >/dev/null 2>&1
    fi
    return $?
  fi

  bash -lc "${cmd}" >/dev/null 2>&1
}

capture_target() {
  local cmd="$1"
  local escaped=""
  local ssh_args=()

  if [[ "${TARGET_MODE}" == "remote" ]]; then
    printf -v escaped '%q' "${cmd}"
    ssh_args=(-F /dev/null -p "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
    if [[ -n "${SSH_KEY}" ]]; then
      ssh_args+=(-i "${SSH_KEY}")
      ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}"
    else
      ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}"
    fi
    return 0
  fi

  bash -lc "${cmd}"
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
    if [[ -n "${SSH_KEY}" ]]; then
      ssh_args+=(-i "${SSH_KEY}")
      ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}"
    else
      ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}"
    fi
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

ensure_target_access() {
  if [[ "${TARGET_MODE}" == "remote" ]]; then
    command -v ssh >/dev/null 2>&1 || die "ssh client not found on controller."
  fi
}

detect_target_privilege() {
  local uid=""
  uid="$(capture_target "id -u" | tr -d '[:space:]')"
  [[ -n "${uid}" ]] || die "Could not detect target uid."

  if [[ "${uid}" == "0" ]]; then
    TARGET_SUDO=""
    return 0
  fi

  run_check_target "command -v sudo" || die "sudo is required on target when not running as root."
  TARGET_SUDO="sudo"
}

detect_package_manager() {
  if run_check_target "command -v apt-get"; then
    echo "apt"
    return 0
  fi
  if run_check_target "command -v dnf"; then
    echo "dnf"
    return 0
  fi
  if run_check_target "command -v yum"; then
    echo "yum"
    return 0
  fi

  die "No supported package manager found on ${TARGET_LABEL}."
}

install_keepalived() {
  local pkg_manager="$1"
  log_info "Installing Keepalived on ${TARGET_LABEL} using ${pkg_manager}"

  case "${pkg_manager}" in
    apt)
      run_target "$(as_root_cmd "apt-get update")"
      run_target "$(as_root_cmd "apt-get install -y keepalived")"
      ;;
    dnf)
      run_target "$(as_root_cmd "dnf install -y keepalived")"
      ;;
    yum)
      run_target "$(as_root_cmd "yum install -y keepalived")"
      ;;
    *)
      die "Unsupported package manager: ${pkg_manager}"
      ;;
  esac
}

enable_service() {
  log_info "Ensuring service ${KEEPALIVED_SERVICE_NAME_RESOLVED} is enabled on ${TARGET_LABEL}"
  run_target "$(as_root_cmd "systemctl enable ${KEEPALIVED_SERVICE_NAME_RESOLVED}")"

  if [[ "${DRY_RUN}" == "true" ]]; then
    return 0
  fi

  if ! run_target "$(as_root_cmd "systemctl start ${KEEPALIVED_SERVICE_NAME_RESOLVED}")"; then
    log_warn "Could not start ${KEEPALIVED_SERVICE_NAME_RESOLVED} yet on ${TARGET_LABEL}. This is expected before setup on some distros."
  fi
}

validate_service_status() {
  local status=""

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Dry-run mode: skipping service active validation."
    return 0
  fi

  status="$(capture_target "$(as_root_cmd "systemctl is-active ${KEEPALIVED_SERVICE_NAME_RESOLVED}")" | tr -d '[:space:]' || true)"
  if [[ "${status}" != "active" ]]; then
    log_warn "Service ${KEEPALIVED_SERVICE_NAME_RESOLVED} is not active on ${TARGET_LABEL} yet. This is expected before setup on some distros."
    return 0
  fi
  log_info "Service ${KEEPALIVED_SERVICE_NAME_RESOLVED} is active."
}

main() {
  parse_args "$@"
  validate_args
  init_target_mode
  ensure_target_access

  load_overlay_vars "${ENV_NAME}"
  KEEPALIVED_SERVICE_NAME_RESOLVED="${KEEPALIVED_SERVICE_NAME:-keepalived}"
  [[ -n "${KEEPALIVED_SERVICE_NAME_RESOLVED}" ]] || die "KEEPALIVED_SERVICE_NAME is empty."

  detect_target_privilege
  install_keepalived "$(detect_package_manager)"
  enable_service
  validate_service_status

  log_info "Keepalived install completed for ${TARGET_LABEL}."
}

main "$@"
