#!/usr/bin/env bash
# @file install.sh
# @brief Install talosctl in an idempotent way on local or remote Linux hosts.
# @description
#   Downloads talosctl from official GitHub releases and installs into the target
#   install directory. Supports local execution or SSH remote mode.
#
# @arg --env,-e string Overlay environment name. Defaults to lab.
# @arg --version string talosctl version tag (e.g. v1.12.4). Defaults to TALOSCTL_VERSION.
# @arg --install-dir string Target install directory. Defaults to TALOSCTL_INSTALL_DIR.
# @arg --host string Remote host. If omitted, runs locally.
# @arg --user string SSH user for remote execution. Defaults to root.
# @arg --port string SSH port for remote execution. Defaults to 22.
# @arg --ssh-key string SSH private key path for remote execution.
# @flag --dry-run,-n Print planned actions without applying changes.
# @flag --help,-h Show usage information.

set -euo pipefail

ENV_NAME="lab"
TARGET_VERSION=""
INSTALL_DIR=""
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

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -e, --env=<env>       Overlay environment (default: lab)
      --version=<tag>   talosctl version tag (default from vars)
      --install-dir=<d> install directory (default from vars)
      --host=<host>     Remote host (optional)
      --user=<user>     Remote SSH user (default: root)
      --port=<port>     Remote SSH port (default: 22)
      --ssh-key=<path>  SSH private key for remote mode
  -n, --dry-run         Show actions without executing
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
      --version=*)
        TARGET_VERSION="${1#*=}"
        shift
        ;;
      --install-dir=*)
        INSTALL_DIR="${1#*=}"
        shift
        ;;
      --host=*)
        SSH_HOST="${1#*=}"
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
    fi
    ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}" >/dev/null 2>&1
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
    fi
    ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}"
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
    fi
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

  if run_check_target "command -v sudo" && run_check_target "sudo -n true"; then
    TARGET_SUDO="sudo"
    return 0
  fi

  TARGET_SUDO=""
  log_warn "sudo is unavailable on ${TARGET_LABEL}; continuing without sudo. Use a writable --install-dir."
}

detect_target_os_arch() {
  local os arch
  os="$(capture_target "uname -s | tr '[:upper:]' '[:lower:]'" | tr -d '[:space:]')"
  arch="$(capture_target "uname -m" | tr -d '[:space:]')"

  case "${os}" in
    linux) ;;
    *) die "Unsupported target OS '${os}' on ${TARGET_LABEL}. Only Linux is supported." ;;
  esac

  case "${arch}" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "Unsupported target architecture '${arch}' on ${TARGET_LABEL}." ;;
  esac

  printf '%s %s\n' "${os}" "${arch}"
}

installed_version() {
  local output version
  if ! run_check_target "command -v talosctl"; then
    return 1
  fi

  output="$(capture_target "talosctl version --client --short 2>/dev/null || talosctl version --short 2>/dev/null || talosctl version 2>/dev/null || true")"
  version="$(printf '%s\n' "${output}" | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
  [[ -n "${version}" ]] || return 1
  printf '%s\n' "${version}"
}

install_talosctl() {
  local os="$1"
  local arch="$2"
  local url=""
  local q_url q_install_dir

  url="https://github.com/siderolabs/talos/releases/download/${TARGET_VERSION}/talosctl-${os}-${arch}"
  printf -v q_url '%q' "${url}"
  printf -v q_install_dir '%q' "${INSTALL_DIR}"

  run_target "$(as_root_cmd "command -v curl >/dev/null 2>&1 || (command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install -y curl) || (command -v dnf >/dev/null 2>&1 && dnf install -y curl) || (command -v yum >/dev/null 2>&1 && yum install -y curl)")"
  run_target "$(as_root_cmd "install -d -m 0755 ${q_install_dir}")"
  run_target "$(as_root_cmd "curl -fL ${q_url} -o ${q_install_dir}/talosctl")"
  run_target "$(as_root_cmd "chmod 0755 ${q_install_dir}/talosctl")"
}

main() {
  parse_args "$@"
  validate_args
  init_target_mode
  ensure_target_access

  load_overlay_vars "${ENV_NAME}"
  TARGET_VERSION="${TARGET_VERSION:-${TALOSCTL_VERSION:-v1.12.4}}"
  INSTALL_DIR="${INSTALL_DIR:-${TALOSCTL_INSTALL_DIR:-/usr/local/bin}}"

  [[ "${TARGET_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "--version must look like v1.12.4"
  [[ -n "${INSTALL_DIR}" ]] || die "--install-dir cannot be empty."

  detect_target_privilege

  local current="" os_arch=() os="" arch=""
  if current="$(installed_version)"; then
    if [[ "${current}" == "${TARGET_VERSION}" ]]; then
      log_info "talosctl ${current} already installed on ${TARGET_LABEL}. Nothing to do."
      exit 0
    fi
    log_warn "talosctl ${current} installed on ${TARGET_LABEL}; target is ${TARGET_VERSION}. Upgrading."
  else
    log_info "talosctl not found on ${TARGET_LABEL}. Installing ${TARGET_VERSION}."
  fi

  read -r os arch < <(detect_target_os_arch)
  install_talosctl "${os}" "${arch}"

  if [[ "${DRY_RUN}" == "false" ]]; then
    local final=""
    final="$(installed_version || true)"
    [[ "${final}" == "${TARGET_VERSION}" ]] || die "talosctl install failed on ${TARGET_LABEL}. Expected ${TARGET_VERSION}, got ${final:-unknown}."
    log_info "talosctl installed successfully on ${TARGET_LABEL}: ${final}"
  fi
}

main "$@"
