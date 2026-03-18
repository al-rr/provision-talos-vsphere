#!/usr/bin/env bash
# @file setup.sh
# @brief Render and apply Keepalived configuration on a local or remote Linux host.
# @description
#   Renders keepalived.conf from a template and environment variables, applies secure
#   file permissions, validates configuration syntax, and restarts the service safely.
#
# @arg --env,-e string Overlay environment name. Defaults to lab.
# @arg --template string Template path on controller. Defaults to KEEPALIVED_TEMPLATE_PATH.
# @arg --output string Target config path. Defaults to KEEPALIVED_CONFIG_PATH.
# @arg --interface string Keepalived network interface for this node.
# @arg --state string Keepalived state for this node (MASTER or BACKUP).
# @arg --priority int Keepalived priority for this node.
# @arg --src-ip string Unicast source IP for this node.
# @arg --peers string Comma-separated unicast peers.
# @arg --vips string Comma-separated VIPs (CIDR format recommended).
# @arg --host string Remote host. If omitted, runs locally.
# @arg --user string SSH user for remote execution. Defaults to root.
# @arg --port string SSH port for remote execution. Defaults to 22.
# @arg --ssh-key string SSH private key path for remote execution.
# @flag --dry-run,-n Print mutating actions without applying changes.
# @flag --help,-h Show usage information.
#
# @example
#   ./overlays/base/scripts/keepalived/setup.sh --env=lab --host=172.17.20.181 --user=vagrant --ssh-key=/tmp/talos-lb-1.key --state=MASTER --priority=120 --src-ip=172.17.20.181
# @example
#   ./overlays/base/scripts/keepalived/setup.sh --env=lab --host=172.17.20.182 --user=vagrant --ssh-key=/tmp/talos-lb-2.key --state=BACKUP --priority=100 --src-ip=172.17.20.182

set -euo pipefail

ENV_NAME="lab"
DRY_RUN="false"
SSH_HOST=""
SSH_USER="root"
SSH_PORT="22"
SSH_KEY=""
CLI_TEMPLATE_PATH=""
CLI_OUTPUT_PATH=""
CLI_INTERFACE=""
CLI_STATE=""
CLI_PRIORITY=""
CLI_SRC_IP=""
CLI_PEERS=""
CLI_VIPS=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BASE_SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=/dev/null
source "${BASE_SCRIPT_DIR}/functions.sh"

TARGET_MODE="local"
TARGET_LABEL="local host"
TARGET_SUDO=""
TEMPLATE_PATH=""
OUTPUT_PATH=""
KEEPALIVED_SERVICE_NAME_RESOLVED="keepalived"
KEEPALIVED_STATE_RESOLVED=""
KEEPALIVED_PRIORITY_RESOLVED=""
KEEPALIVED_INTERFACE_RESOLVED=""
KEEPALIVED_ROUTER_ID_RESOLVED=""
KEEPALIVED_AUTH_TYPE_RESOLVED=""
KEEPALIVED_AUTH_PASS_RESOLVED=""
KEEPALIVED_ADVERT_INT_RESOLVED=""
KEEPALIVED_UNICAST_SRC_IP_RESOLVED=""
KEEPALIVED_UNICAST_PEERS_RESOLVED=""
KEEPALIVED_VIPS_RESOLVED=""
KEEPALIVED_TRACK_HAPROXY_RESOLVED=""
KEEPALIVED_TRACK_SCRIPT_NAME_RESOLVED=""
KEEPALIVED_TRACK_SCRIPT_COMMAND_RESOLVED=""
KEEPALIVED_TRACK_SCRIPT_INTERVAL_RESOLVED=""
KEEPALIVED_TRACK_SCRIPT_WEIGHT_RESOLVED=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -e, --env=<env>       Overlay environment (default: lab)
      --template=<path> Template path on controller
      --output=<path>   Target Keepalived config path
      --interface=<if>  Network interface used by VRRP VIP
      --state=<value>   MASTER or BACKUP
      --priority=<num>  VRRP priority
      --src-ip=<ip>     Unicast source IP for this node
      --peers=<list>    Comma-separated unicast peer IPs
      --vips=<list>     Comma-separated VIPs
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
      --template)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        CLI_TEMPLATE_PATH="$2"
        shift 2
        ;;
      --template=*)
        CLI_TEMPLATE_PATH="${1#*=}"
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
      --interface)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        CLI_INTERFACE="$2"
        shift 2
        ;;
      --interface=*)
        CLI_INTERFACE="${1#*=}"
        shift
        ;;
      --state)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        CLI_STATE="$2"
        shift 2
        ;;
      --state=*)
        CLI_STATE="${1#*=}"
        shift
        ;;
      --priority)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        CLI_PRIORITY="$2"
        shift 2
        ;;
      --priority=*)
        CLI_PRIORITY="${1#*=}"
        shift
        ;;
      --src-ip)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        CLI_SRC_IP="$2"
        shift 2
        ;;
      --src-ip=*)
        CLI_SRC_IP="${1#*=}"
        shift
        ;;
      --peers)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        CLI_PEERS="$2"
        shift 2
        ;;
      --peers=*)
        CLI_PEERS="${1#*=}"
        shift
        ;;
      --vips)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        CLI_VIPS="$2"
        shift 2
        ;;
      --vips=*)
        CLI_VIPS="${1#*=}"
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

resolve_paths_and_settings() {
  local default_template="${REPO_ROOT}/overlays/base/scripts/keepalived/templates/keepalived.conf.tpl"

  TEMPLATE_PATH="${CLI_TEMPLATE_PATH:-${KEEPALIVED_TEMPLATE_PATH:-${default_template}}}"
  OUTPUT_PATH="${CLI_OUTPUT_PATH:-${KEEPALIVED_CONFIG_PATH:-/etc/keepalived/keepalived.conf}}"
  KEEPALIVED_SERVICE_NAME_RESOLVED="${KEEPALIVED_SERVICE_NAME:-keepalived}"
  KEEPALIVED_STATE_RESOLVED="${CLI_STATE:-${KEEPALIVED_STATE:-BACKUP}}"
  KEEPALIVED_PRIORITY_RESOLVED="${CLI_PRIORITY:-${KEEPALIVED_PRIORITY:-100}}"
  KEEPALIVED_INTERFACE_RESOLVED="${CLI_INTERFACE:-${KEEPALIVED_INTERFACE:-auto}}"
  KEEPALIVED_ROUTER_ID_RESOLVED="${KEEPALIVED_ROUTER_ID:-51}"
  KEEPALIVED_AUTH_TYPE_RESOLVED="${KEEPALIVED_AUTH_TYPE:-PASS}"
  KEEPALIVED_AUTH_PASS_RESOLVED="${KEEPALIVED_AUTH_PASS:-}"
  KEEPALIVED_ADVERT_INT_RESOLVED="${KEEPALIVED_ADVERT_INT:-1}"
  KEEPALIVED_UNICAST_SRC_IP_RESOLVED="${CLI_SRC_IP:-${KEEPALIVED_UNICAST_SRC_IP:-}}"
  KEEPALIVED_UNICAST_PEERS_RESOLVED="${CLI_PEERS:-${KEEPALIVED_UNICAST_PEERS:-}}"
  KEEPALIVED_VIPS_RESOLVED="${CLI_VIPS:-${KEEPALIVED_VIPS:-}}"
  KEEPALIVED_TRACK_HAPROXY_RESOLVED="${KEEPALIVED_TRACK_HAPROXY:-true}"
  KEEPALIVED_TRACK_SCRIPT_NAME_RESOLVED="${KEEPALIVED_TRACK_SCRIPT_NAME:-chk_haproxy}"
  KEEPALIVED_TRACK_SCRIPT_COMMAND_RESOLVED="${KEEPALIVED_TRACK_SCRIPT_COMMAND:-systemctl is-active --quiet haproxy}"
  KEEPALIVED_TRACK_SCRIPT_INTERVAL_RESOLVED="${KEEPALIVED_TRACK_SCRIPT_INTERVAL:-2}"
  KEEPALIVED_TRACK_SCRIPT_WEIGHT_RESOLVED="${KEEPALIVED_TRACK_SCRIPT_WEIGHT:--20}"

  if [[ "${TEMPLATE_PATH}" != /* ]]; then
    TEMPLATE_PATH="${REPO_ROOT}/${TEMPLATE_PATH}"
  fi
}

validate_required_vars() {
  [[ -f "${TEMPLATE_PATH}" ]] || die "Template file not found: ${TEMPLATE_PATH}"
  [[ -n "${KEEPALIVED_INTERFACE_RESOLVED}" ]] || die "KEEPALIVED_INTERFACE is required."
  [[ -n "${KEEPALIVED_ROUTER_ID_RESOLVED}" ]] || die "KEEPALIVED_ROUTER_ID is required."
  [[ -n "${KEEPALIVED_AUTH_PASS_RESOLVED}" ]] || die "KEEPALIVED_AUTH_PASS is required."
  [[ -n "${KEEPALIVED_VIPS_RESOLVED}" ]] || die "KEEPALIVED_VIPS (or --vips) is required."
  [[ -n "${KEEPALIVED_UNICAST_SRC_IP_RESOLVED}" ]] || die "KEEPALIVED_UNICAST_SRC_IP (or --src-ip) is required for unicast mode."
  [[ -n "${KEEPALIVED_UNICAST_PEERS_RESOLVED}" ]] || die "KEEPALIVED_UNICAST_PEERS (or --peers) is required for unicast mode."
  [[ "${KEEPALIVED_STATE_RESOLVED^^}" == "MASTER" || "${KEEPALIVED_STATE_RESOLVED^^}" == "BACKUP" ]] || die "--state must be MASTER or BACKUP."
  [[ "${KEEPALIVED_PRIORITY_RESOLVED}" =~ ^[0-9]+$ ]] || die "--priority must be numeric."
  [[ "${KEEPALIVED_ROUTER_ID_RESOLVED}" =~ ^[0-9]+$ ]] || die "KEEPALIVED_ROUTER_ID must be numeric."
  [[ "${KEEPALIVED_ADVERT_INT_RESOLVED}" =~ ^[0-9]+$ ]] || die "KEEPALIVED_ADVERT_INT must be numeric."
}

validate_target_interface() {
  local detected_iface=""
  local prefer_auto="false"

  if [[ -z "${CLI_INTERFACE}" && "${KEEPALIVED_INTERFACE_RESOLVED}" == "auto" ]]; then
    prefer_auto="true"
  fi

  if [[ "${prefer_auto}" == "false" ]] && run_check_target "ip link show ${KEEPALIVED_INTERFACE_RESOLVED}"; then
    return 0
  fi

  detected_iface="$(capture_target "ip -o route show to default | awk '{print \$5; exit}'" | tr -d '[:space:]')"
  [[ -n "${detected_iface}" ]] || die "Could not detect default network interface on ${TARGET_LABEL}. Use --interface to override."
  run_check_target "ip link show ${detected_iface}" || die "Detected interface '${detected_iface}' is not valid on ${TARGET_LABEL}. Use --interface to override."

  if [[ "${prefer_auto}" == "true" ]]; then
    log_info "Using auto-detected interface '${detected_iface}' on ${TARGET_LABEL}."
  else
    log_warn "Interface '${KEEPALIVED_INTERFACE_RESOLVED}' not found on ${TARGET_LABEL}; falling back to '${detected_iface}'."
  fi

  KEEPALIVED_INTERFACE_RESOLVED="${detected_iface}"
}

build_unicast_block() {
  cat <<EOF
  unicast_src_ip ${KEEPALIVED_UNICAST_SRC_IP_RESOLVED}
  unicast_peer {
$(printf '%s' "${KEEPALIVED_UNICAST_PEERS_RESOLVED}" | tr ',' '\n' | sed '/^[[:space:]]*$/d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^/    /')
  }
EOF
}

build_vips_block() {
  printf '%s' "${KEEPALIVED_VIPS_RESOLVED}" | tr ',' '\n' | sed '/^[[:space:]]*$/d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^/    /'
}

build_track_block() {
  local track_bool=""
  track_bool="$(to_bool "${KEEPALIVED_TRACK_HAPROXY_RESOLVED}")"
  if [[ "${track_bool}" != "true" ]]; then
    echo ""
    return 0
  fi

  cat <<EOF
  track_script {
    ${KEEPALIVED_TRACK_SCRIPT_NAME_RESOLVED}
  }
EOF
}

render_config() {
  local out_path="$1"
  local unicast_block=""
  local vips_block=""
  local track_block=""

  unicast_block="$(build_unicast_block)"
  vips_block="$(build_vips_block)"
  track_block="$(build_track_block)"

  awk \
    -v keepalived_state="${KEEPALIVED_STATE_RESOLVED^^}" \
    -v keepalived_interface="${KEEPALIVED_INTERFACE_RESOLVED}" \
    -v keepalived_router_id="${KEEPALIVED_ROUTER_ID_RESOLVED}" \
    -v keepalived_priority="${KEEPALIVED_PRIORITY_RESOLVED}" \
    -v keepalived_advert_int="${KEEPALIVED_ADVERT_INT_RESOLVED}" \
    -v keepalived_auth_type="${KEEPALIVED_AUTH_TYPE_RESOLVED}" \
    -v keepalived_auth_pass="${KEEPALIVED_AUTH_PASS_RESOLVED}" \
    -v track_script_name="${KEEPALIVED_TRACK_SCRIPT_NAME_RESOLVED}" \
    -v track_script_command="${KEEPALIVED_TRACK_SCRIPT_COMMAND_RESOLVED}" \
    -v track_script_interval="${KEEPALIVED_TRACK_SCRIPT_INTERVAL_RESOLVED}" \
    -v track_script_weight="${KEEPALIVED_TRACK_SCRIPT_WEIGHT_RESOLVED}" \
    -v unicast_block="${unicast_block}" \
    -v vips_block="${vips_block}" \
    -v track_block="${track_block}" \
    '
    function print_block(text, line_count, idx, lines) {
      line_count = split(text, lines, "\n")
      for (idx = 1; idx <= line_count; idx++) {
        print lines[idx]
      }
    }
    $0 == "__KEEPALIVED_UNICAST_BLOCK__" { print_block(unicast_block); next }
    $0 == "__KEEPALIVED_VIPS_BLOCK__"    { print_block(vips_block); next }
    $0 == "__KEEPALIVED_TRACK_BLOCK__"   { print_block(track_block); next }
    {
      gsub(/__KEEPALIVED_STATE__/, keepalived_state)
      gsub(/__KEEPALIVED_INTERFACE__/, keepalived_interface)
      gsub(/__KEEPALIVED_ROUTER_ID__/, keepalived_router_id)
      gsub(/__KEEPALIVED_PRIORITY__/, keepalived_priority)
      gsub(/__KEEPALIVED_ADVERT_INT__/, keepalived_advert_int)
      gsub(/__KEEPALIVED_AUTH_TYPE__/, keepalived_auth_type)
      gsub(/__KEEPALIVED_AUTH_PASS__/, keepalived_auth_pass)
      gsub(/__KEEPALIVED_TRACK_SCRIPT_NAME__/, track_script_name)
      gsub(/__KEEPALIVED_TRACK_SCRIPT_COMMAND__/, track_script_command)
      gsub(/__KEEPALIVED_TRACK_SCRIPT_INTERVAL__/, track_script_interval)
      gsub(/__KEEPALIVED_TRACK_SCRIPT_WEIGHT__/, track_script_weight)
      print
    }
    ' "${TEMPLATE_PATH}" >"${out_path}"
}

apply_config() {
  local rendered_path="$1"
  local backup_path="${OUTPUT_PATH}.bak.$(date +%Y%m%d%H%M%S)"
  local q_rendered=""
  local q_output=""
  local q_backup=""
  local remote_tmp=""
  local q_remote_tmp=""

  printf -v q_rendered '%q' "${rendered_path}"
  printf -v q_output '%q' "${OUTPUT_PATH}"
  printf -v q_backup '%q' "${backup_path}"

  if [[ "${TARGET_MODE}" == "local" ]]; then
    run_target "$(as_root_cmd "install -d -m 0755 $(printf '%q' "$(dirname "${OUTPUT_PATH}")")")"
    run_target "$(as_root_cmd "if [[ -f ${q_output} ]]; then cp -a ${q_output} ${q_backup}; fi")"
    run_target "$(as_root_cmd "install -o root -g root -m 0644 ${q_rendered} ${q_output}")"
    return 0
  fi

  remote_tmp="/tmp/keepalived.conf.$$.tmp"
  printf -v q_remote_tmp '%q' "${remote_tmp}"

  scp_upload "${rendered_path}" "${remote_tmp}"
  run_target "$(as_root_cmd "install -d -m 0755 $(printf '%q' "$(dirname "${OUTPUT_PATH}")")")"
  run_target "$(as_root_cmd "if [[ -f ${q_output} ]]; then cp -a ${q_output} ${q_backup}; fi")"
  run_target "$(as_root_cmd "install -o root -g root -m 0644 ${q_remote_tmp} ${q_output}")"
  run_target "rm -f ${q_remote_tmp}"
}

validate_keepalived_config() {
  local q_output=""

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Dry-run mode: skipping keepalived config validation and service restart."
    return 0
  fi

  printf -v q_output '%q' "${OUTPUT_PATH}"

  if run_check_target "keepalived --help | grep -q -- '--config-test'"; then
    run_target "$(as_root_cmd "keepalived --config-test -f ${q_output}")"
  else
    run_target "$(as_root_cmd "keepalived -t -f ${q_output}")"
  fi
}

restart_service() {
  local q_service=""

  if [[ "${DRY_RUN}" == "true" ]]; then
    return 0
  fi

  printf -v q_service '%q' "${KEEPALIVED_SERVICE_NAME_RESOLVED}"
  run_target "$(as_root_cmd "systemctl restart ${q_service}")"
  run_target "$(as_root_cmd "systemctl is-active ${q_service}")"
}

main() {
  local rendered_cfg=""

  parse_args "$@"
  validate_args
  init_target_mode
  ensure_target_access

  load_overlay_vars "${ENV_NAME}"
  resolve_paths_and_settings
  validate_required_vars
  detect_target_privilege
  validate_target_interface

  rendered_cfg="$(mktemp)"
  trap '[[ -n "${rendered_cfg:-}" ]] && rm -f "${rendered_cfg}"' EXIT

  render_config "${rendered_cfg}"
  apply_config "${rendered_cfg}"
  validate_keepalived_config
  restart_service

  log_info "Keepalived setup completed for ${TARGET_LABEL}."
}

main "$@"
