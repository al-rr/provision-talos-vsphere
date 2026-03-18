#!/usr/bin/env bash
# @file hardening.sh
# @brief Apply baseline HAProxy host hardening on local or remote Linux hosts.
# @description
#   Applies firewall rules for explicit HAProxy ports and a compact sysctl hardening
#   profile focused on network/kernel protections relevant to load balancer hosts.
#
# @arg --env,-e string Overlay environment name. Defaults to prod.
# @arg --ports string Comma-separated TCP ports to allow in firewall.
# @arg --host string Remote host. If omitted, runs locally.
# @arg --user string SSH user for remote execution. Defaults to root.
# @arg --port string SSH port for remote execution. Defaults to 22.
# @arg --ssh-key string SSH private key path for remote execution.
# @flag --dry-run,-n Print mutating actions without applying changes.
# @flag --help,-h Show usage information.
#
# @example
#   ./overlays/base/scripts/ha-proxy/hardening.sh --env=prod
# @example
#   ./overlays/base/scripts/ha-proxy/hardening.sh --env=lab --host=172.17.20.91 --user=rocky --ssh-key=/home/vagrant/.ssh/id_ed25519

set -euo pipefail

ENV_NAME="prod"
DRY_RUN="false"
SSH_HOST=""
SSH_USER="root"
SSH_PORT="22"
SSH_KEY=""
CLI_ALLOWED_PORTS=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${BASE_SCRIPT_DIR}/functions.sh"

TARGET_MODE="local"
TARGET_LABEL="local host"
TARGET_SUDO=""
ALLOWED_PORTS=""
SYSCTL_PROFILE="secure"
SYSCTL_CONF_PATH="/etc/sysctl.d/99-haproxy-hardening.conf"
FIREWALL_PORT_LIST=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -e, --env=<env>       Overlay environment (default: prod)
      --ports=<list>    Comma-separated TCP ports (default: HAPROXY_ALLOWED_PORTS)
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
      --ports)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        CLI_ALLOWED_PORTS="$2"
        shift 2
        ;;
      --ports=*)
        CLI_ALLOWED_PORTS="${1#*=}"
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

scp_upload() {
  local source_path="$1"
  local dest_path="$2"
  local scp_args=()

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] (${TARGET_LABEL}) scp ${source_path} -> ${dest_path}"
    return 0
  fi

  scp_args=(-F /dev/null -P "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
  if [[ -n "${SSH_KEY}" ]]; then
    scp_args+=(-i "${SSH_KEY}")
    scp "${scp_args[@]}" "${source_path}" "${SSH_USER}@${SSH_HOST}:${dest_path}"
  else
    scp "${scp_args[@]}" "${source_path}" "${SSH_USER}@${SSH_HOST}:${dest_path}"
  fi
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
    command -v scp >/dev/null 2>&1 || die "scp client not found on controller."
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

resolve_values() {
  ALLOWED_PORTS="${CLI_ALLOWED_PORTS:-${HAPROXY_ALLOWED_PORTS:-6443,8404}}"
  SYSCTL_PROFILE="${HAPROXY_SYSCTL_PROFILE:-secure}"
}

parse_and_validate_ports() {
  local raw_ports=()
  local port=""

  [[ -n "${ALLOWED_PORTS}" ]] || die "No ports defined. Set --ports or HAPROXY_ALLOWED_PORTS."

  IFS=',' read -r -a raw_ports <<<"${ALLOWED_PORTS}"
  FIREWALL_PORT_LIST=()

  for port in "${raw_ports[@]}"; do
    port="${port//[[:space:]]/}"
    [[ -n "${port}" ]] || continue
    [[ "${port}" =~ ^[0-9]+$ ]] || die "Invalid port value: ${port}"
    [[ "${port}" -ge 1 && "${port}" -le 65535 ]] || die "Port out of range: ${port}"
    FIREWALL_PORT_LIST+=("${port}")
  done

  [[ "${#FIREWALL_PORT_LIST[@]}" -gt 0 ]] || die "No valid ports were parsed from: ${ALLOWED_PORTS}"
}

apply_sysctl_profile() {
  local temp_file=""
  local remote_tmp="/tmp/haproxy-hardening-sysctl.$$.conf"
  local q_sysctl_path=""
  local q_remote_tmp=""

  [[ "${SYSCTL_PROFILE}" == "secure" ]] || die "Unsupported HAPROXY_SYSCTL_PROFILE: ${SYSCTL_PROFILE}"

  temp_file="$(mktemp)"
  cat >"${temp_file}" <<'EOF'
# Managed by overlays/base/scripts/ha-proxy/hardening.sh
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
kernel.kptr_restrict = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

  printf -v q_sysctl_path '%q' "${SYSCTL_CONF_PATH}"
  printf -v q_remote_tmp '%q' "${remote_tmp}"

  if [[ "${TARGET_MODE}" == "local" ]]; then
    run_target "$(as_root_cmd "install -o root -g root -m 0644 $(printf '%q' "${temp_file}") ${q_sysctl_path}")"
  else
    scp_upload "${temp_file}" "${remote_tmp}"
    run_target "$(as_root_cmd "install -o root -g root -m 0644 ${q_remote_tmp} ${q_sysctl_path}")"
    run_target "rm -f ${q_remote_tmp}"
  fi

  run_target "$(as_root_cmd "sysctl --system")"
  rm -f "${temp_file}"
}

apply_firewall_rules() {
  local port=""

  if run_check_target "command -v ufw"; then
    log_info "Applying firewall rules with ufw on ${TARGET_LABEL}"
    for port in "${FIREWALL_PORT_LIST[@]}"; do
      run_target "$(as_root_cmd "ufw allow ${port}/tcp")"
    done
    return 0
  fi

  if run_check_target "command -v firewall-cmd"; then
    log_info "Applying firewall rules with firewalld on ${TARGET_LABEL}"
    run_target "$(as_root_cmd "firewall-cmd --state")"
    for port in "${FIREWALL_PORT_LIST[@]}"; do
      run_target "$(as_root_cmd "firewall-cmd --add-port=${port}/tcp")"
      run_target "$(as_root_cmd "firewall-cmd --permanent --add-port=${port}/tcp")"
    done
    run_target "$(as_root_cmd "firewall-cmd --reload")"
    return 0
  fi

  if run_check_target "command -v nft"; then
    die "nft is present on ${TARGET_LABEL}, but this script currently supports only ufw or firewalld."
  fi

  die "No supported firewall backend found on ${TARGET_LABEL}. Install ufw or firewalld."
}

main() {
  parse_args "$@"
  validate_args
  init_target_mode
  ensure_target_access

  load_overlay_vars "${ENV_NAME}"
  resolve_values
  parse_and_validate_ports
  detect_target_privilege

  log_info "Applying sysctl hardening profile '${SYSCTL_PROFILE}' on ${TARGET_LABEL}"
  apply_sysctl_profile
  apply_firewall_rules

  log_info "Host hardening completed for ${TARGET_LABEL}."
}

main "$@"
