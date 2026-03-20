#!/usr/bin/env bash
# @file setup.sh
# @brief Configure dnsmasq on local or remote host.
# @description
#   Renders dnsmasq config from overlay vars, validates syntax, and reloads service.
#
# @arg --env,-e string Overlay environment. Defaults to lab.
# @arg --host string Remote host. If omitted, runs locally.
# @arg --user string SSH user for remote execution. Defaults to root.
# @arg --port string SSH port for remote execution. Defaults to 22.
# @arg --ssh-key string SSH private key path for remote execution.
# @arg --output string Destination config file path.
# @flag --dry-run,-n Print mutating actions without applying changes.
# @flag --help,-h Show usage.

set -euo pipefail

ENV_NAME="lab"
DRY_RUN="false"
SSH_HOST=""
SSH_USER="root"
SSH_PORT="22"
SSH_KEY=""
CLI_OUTPUT_PATH=""
CUSTOM_VARS_FILE=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BASE_SCRIPT_DIR}/../../.." && pwd)"

# shellcheck disable=SC1091
source "${BASE_SCRIPT_DIR}/functions.sh"

TARGET_MODE="local"
TARGET_LABEL="local host"
TARGET_SUDO=""
DNS_SERVICE_NAME_RESOLVED="dnsmasq"
DNS_CONFIG_PATH_RESOLVED="/etc/dnsmasq.d/talos-lab.conf"
DNS_LISTEN_ADDRESSES_RESOLVED="127.0.0.1"
DNS_UPSTREAM_SERVERS_RESOLVED="1.1.1.1,8.8.8.8"
DNS_DOMAIN_RESOLVED="lab.local"
DNS_A_RECORDS_RESOLVED=""
DNS_CACHE_SIZE_RESOLVED="1000"

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options]

Options:
  -e, --env=<env>       Overlay environment (default: lab)
      --host=<host>     Remote host (optional)
      --user=<user>     Remote SSH user (default: root)
      --port=<port>     Remote SSH port (default: 22)
      --ssh-key=<path>  SSH private key path
      --output=<path>   Destination dnsmasq config file
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
      --output)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        CLI_OUTPUT_PATH="$2"
        shift 2
        ;;
      --output=*)
        CLI_OUTPUT_PATH="${1#*=}"
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

capture_target() {
  local cmd="$1"
  local escaped=""
  local ssh_args=()

  if [[ "${TARGET_MODE}" == "remote" ]]; then
    printf -v escaped '%q' "${cmd}"
    ssh_args=(-F /dev/null -p "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
    [[ -n "${SSH_KEY}" ]] && ssh_args+=(-i "${SSH_KEY}")
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
    [[ -n "${SSH_KEY}" ]] && ssh_args+=(-i "${SSH_KEY}")
    ssh "${ssh_args[@]}" "${SSH_USER}@${SSH_HOST}" "bash -lc ${escaped}"
    return 0
  fi

  bash -lc "${cmd}"
}

scp_upload() {
  local source_path="$1"
  local dest_path="$2"
  local scp_args=()

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] (${TARGET_LABEL}) scp ${source_path} -> ${dest_path}"
    return 0
  fi

  [[ "${TARGET_MODE}" == "remote" ]] || die "scp_upload is only valid in remote mode."
  scp_args=(-F /dev/null -P "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
  [[ -n "${SSH_KEY}" ]] && scp_args+=(-i "${SSH_KEY}")
  scp "${scp_args[@]}" "${source_path}" "${SSH_USER}@${SSH_HOST}:${dest_path}"
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

  DNS_SERVICE_NAME_RESOLVED="${DNS_SERVICE_NAME:-dnsmasq}"
  DNS_CONFIG_PATH_RESOLVED="${DNS_CONFIG_PATH:-/etc/dnsmasq.d/talos-lab.conf}"
  DNS_LISTEN_ADDRESSES_RESOLVED="${DNS_LISTEN_ADDRESSES:-127.0.0.1}"
  DNS_UPSTREAM_SERVERS_RESOLVED="${DNS_UPSTREAM_SERVERS:-1.1.1.1,8.8.8.8}"
  DNS_DOMAIN_RESOLVED="${DNS_DOMAIN:-lab.local}"
  DNS_A_RECORDS_RESOLVED="${DNS_A_RECORDS:-}"
  DNS_CACHE_SIZE_RESOLVED="${DNS_CACHE_SIZE:-1000}"

  if [[ -n "${CLI_OUTPUT_PATH}" ]]; then
    DNS_CONFIG_PATH_RESOLVED="${CLI_OUTPUT_PATH}"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

parse_csv() {
  local raw="$1"
  printf '%s' "${raw}" \
    | tr ',' '\n' \
    | awk 'NF'
}

render_dnsmasq_config() {
  local output_path="$1"
  local item=""
  local host_name=""
  local host_ip=""

  {
    echo "# Generated by overlays/base/scripts/dns/setup.sh"
    echo "port=53"
    echo "domain-needed"
    echo "bogus-priv"
    echo "no-resolv"
    echo "bind-interfaces"
    echo "cache-size=${DNS_CACHE_SIZE_RESOLVED}"
    echo
  } >"${output_path}"

  if [[ -n "${DNS_DOMAIN_RESOLVED}" ]]; then
    printf 'local=/%s/\n' "${DNS_DOMAIN_RESOLVED}" >>"${output_path}"
  fi

  while IFS= read -r item; do
    item="$(trim "${item}")"
    [[ -n "${item}" ]] || continue
    printf 'listen-address=%s\n' "${item}" >>"${output_path}"
  done < <(parse_csv "${DNS_LISTEN_ADDRESSES_RESOLVED}")

  while IFS= read -r item; do
    item="$(trim "${item}")"
    [[ -n "${item}" ]] || continue
    printf 'server=%s\n' "${item}" >>"${output_path}"
  done < <(parse_csv "${DNS_UPSTREAM_SERVERS_RESOLVED}")

  while IFS= read -r item; do
    item="$(trim "${item}")"
    [[ -n "${item}" ]] || continue
    host_name="$(trim "${item%%=*}")"
    host_ip="$(trim "${item#*=}")"
    [[ "${host_name}" != "${host_ip}" ]] || die "Invalid DNS_A_RECORDS entry (expected host=ip): ${item}"
    printf 'address=/%s/%s\n' "${host_name}" "${host_ip}" >>"${output_path}"
  done < <(parse_csv "${DNS_A_RECORDS_RESOLVED}")
}

apply_config() {
  local rendered_path="$1"
  local remote_tmp=""
  local config_dir=""
  local backup_dir="/var/backups/dnsmasq"
  local backup_file=""
  local config_base=""
  local timestamp=""

  config_dir="$(dirname "${DNS_CONFIG_PATH_RESOLVED}")"
  config_base="$(basename "${DNS_CONFIG_PATH_RESOLVED}")"
  timestamp="$(date +%Y%m%d%H%M%S)"
  backup_file="${backup_dir}/${config_base}.${timestamp}.bak"

  if [[ "${TARGET_MODE}" == "remote" ]]; then
    remote_tmp="/tmp/dnsmasq-config-${timestamp}.conf"
    scp_upload "${rendered_path}" "${remote_tmp}"
    run_target "$(as_root_cmd "mkdir -p ${config_dir}")"
    run_target "$(as_root_cmd "mkdir -p ${backup_dir}")"
    run_target "$(as_root_cmd "if [[ -f ${DNS_CONFIG_PATH_RESOLVED} ]]; then cp ${DNS_CONFIG_PATH_RESOLVED} ${backup_file}; fi")"
    run_target "$(as_root_cmd "mv ${remote_tmp} ${DNS_CONFIG_PATH_RESOLVED}")"
    run_target "$(as_root_cmd "chmod 0644 ${DNS_CONFIG_PATH_RESOLVED}")"
    return 0
  fi

  run_target "$(as_root_cmd "mkdir -p ${config_dir}")"
  run_target "$(as_root_cmd "mkdir -p ${backup_dir}")"
  run_target "$(as_root_cmd "if [[ -f ${DNS_CONFIG_PATH_RESOLVED} ]]; then cp ${DNS_CONFIG_PATH_RESOLVED} ${backup_file}; fi")"
  run_target "$(as_root_cmd "cp ${rendered_path} ${DNS_CONFIG_PATH_RESOLVED}")"
  run_target "$(as_root_cmd "chmod 0644 ${DNS_CONFIG_PATH_RESOLVED}")"
}

validate_and_reload() {
  run_target "$(as_root_cmd "dnsmasq --test")"
  run_target "$(as_root_cmd "systemctl restart ${DNS_SERVICE_NAME_RESOLVED}")"
  run_target "$(as_root_cmd "systemctl is-active --quiet ${DNS_SERVICE_NAME_RESOLVED}")"
}

main() {
  local rendered=""
  parse_args "$@"
  validate_args
  init_target_mode
  load_env
  detect_target_sudo

  if ! run_check_target "command -v dnsmasq >/dev/null 2>&1"; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_warn "dnsmasq binary not found on ${TARGET_LABEL}; continuing because --dry-run is enabled."
    else
      die "dnsmasq binary not found on ${TARGET_LABEL}. Run dns/install.sh first."
    fi
  fi

  rendered="$(mktemp)"
  render_dnsmasq_config "${rendered}"
  apply_config "${rendered}"
  validate_and_reload
  rm -f "${rendered}"

  log_info "DNS config applied on ${TARGET_LABEL}: ${DNS_CONFIG_PATH_RESOLVED}"
}

main "$@"
