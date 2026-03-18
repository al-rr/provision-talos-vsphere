#!/usr/bin/env bash
# @file setup.sh
# @brief Render and apply HAProxy configuration on a local or remote Linux host.
# @description
#   Renders haproxy.cfg from a template and environment variables, applies secure
#   file permissions, validates with haproxy -c, and reloads the service only if
#   validation passes.
#
# @arg --env,-e string Overlay environment name. Defaults to prod.
# @arg --template string Template path on controller. Defaults to HAPROXY_TEMPLATE_PATH.
# @arg --output string Target config path. Defaults to HAPROXY_CONFIG_PATH.
# @arg --host string Remote host. If omitted, runs locally.
# @arg --user string SSH user for remote execution. Defaults to root.
# @arg --port string SSH port for remote execution. Defaults to 22.
# @arg --ssh-key string SSH private key path for remote execution.
# @flag --reload Reload service after successful validation. Enabled by default.
# @flag --no-reload Skip service reload.
# @flag --dry-run,-n Print mutating actions without applying changes.
# @flag --help,-h Show usage information.
#
# @example
#   ./overlays/base/scripts/ha-proxy/setup.sh --env=prod
# @example
#   ./overlays/base/scripts/ha-proxy/setup.sh --env=lab --host=172.17.20.91 --user=rocky --ssh-key=/home/vagrant/.ssh/id_ed25519

set -euo pipefail

ENV_NAME="lab"
DRY_RUN="false"
RELOAD_SERVICE="true"
SSH_HOST=""
SSH_USER="root"
SSH_PORT="22"
SSH_KEY=""
CLI_TEMPLATE_PATH=""
CLI_OUTPUT_PATH=""

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
HAPROXY_SERVICE_NAME_RESOLVED="haproxy"
HAPROXY_STATS_URI_RESOLVED="/stats"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -e, --env=<env>       Overlay environment (default: lab)
      --template=<path> Template path on controller
      --output=<path>   Target HAProxy config path
      --host=<host>     Remote host (optional)
      --user=<user>     Remote SSH user (default: root)
      --port=<port>     Remote SSH port (default: 22)
      --ssh-key=<path>  SSH private key for remote mode
      --reload          Reload service after successful validation (default)
      --no-reload       Do not reload service
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
      --reload)
        RELOAD_SERVICE="true"
        shift
        ;;
      --no-reload)
        RELOAD_SERVICE="false"
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

resolve_paths_and_settings() {
  local default_template="${REPO_ROOT}/overlays/base/scripts/ha-proxy/templates/haproxy.cfg.tpl"

  TEMPLATE_PATH="${CLI_TEMPLATE_PATH:-${HAPROXY_TEMPLATE_PATH:-${default_template}}}"
  OUTPUT_PATH="${CLI_OUTPUT_PATH:-${HAPROXY_CONFIG_PATH:-/etc/haproxy/haproxy.cfg}}"
  HAPROXY_SERVICE_NAME_RESOLVED="${HAPROXY_SERVICE_NAME:-haproxy}"
  HAPROXY_STATS_URI_RESOLVED="${HAPROXY_STATS_URI:-/stats}"

  if [[ "${TEMPLATE_PATH}" != /* ]]; then
    TEMPLATE_PATH="${REPO_ROOT}/${TEMPLATE_PATH}"
  fi
}

validate_required_vars() {
  [[ -n "${HAPROXY_FRONTENDS_BLOCK:-}" ]] || die "HAPROXY_FRONTENDS_BLOCK is required."
  [[ -n "${HAPROXY_BACKENDS_BLOCK:-}" ]] || die "HAPROXY_BACKENDS_BLOCK is required."
  [[ -n "${HAPROXY_STATS_USER:-}" ]] || die "HAPROXY_STATS_USER is required."
  [[ -n "${HAPROXY_STATS_PASS:-}" ]] || die "HAPROXY_STATS_PASS is required."
  [[ -f "${TEMPLATE_PATH}" ]] || die "Template file not found: ${TEMPLATE_PATH}"
}

ensure_runtime_socket_dirs() {
  local socket_path=""
  local socket_dir=""
  local q_socket_dir=""

  while IFS= read -r socket_path; do
    [[ -n "${socket_path}" ]] || continue
    [[ "${socket_path}" == /* ]] || continue
    socket_dir="$(dirname "${socket_path}")"
    printf -v q_socket_dir '%q' "${socket_dir}"
    run_target "$(as_root_cmd "install -d -m 0755 ${q_socket_dir}")"
  done < <(
    printf '%s\n' "${HAPROXY_GLOBAL_BLOCK:-}" |
      awk '/^[[:space:]]*stats[[:space:]]+socket[[:space:]]+/ { print $3 }'
  )
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
  echo ""
}

ensure_semanage_available_if_needed() {
  local mode=""
  local pkg_manager=""

  if ! run_check_target "command -v getenforce"; then
    return 0
  fi

  mode="$(capture_target "getenforce | tr -d '[:space:]'" || true)"
  if [[ "${mode}" == "Disabled" || -z "${mode}" ]]; then
    return 0
  fi

  if run_check_target "command -v semanage"; then
    return 0
  fi

  pkg_manager="$(detect_package_manager)"
  case "${pkg_manager}" in
    apt)
      run_target "$(as_root_cmd "apt-get update")"
      run_target "$(as_root_cmd "apt-get install -y policycoreutils-python-utils")"
      ;;
    dnf)
      run_target "$(as_root_cmd "dnf install -y policycoreutils-python-utils")"
      ;;
    yum)
      run_target "$(as_root_cmd "yum install -y policycoreutils-python-utils")"
      ;;
    *)
      die "SELinux is enabled on ${TARGET_LABEL}, but semanage is missing and no supported package manager was found."
      ;;
  esac
}

collect_bind_ports_from_rendered_cfg() {
  local rendered_path="$1"
  awk '
    $1 == "bind" {
      for (i = 2; i <= NF; i++) {
        if ($i ~ /:[0-9]+/) {
          n = split($i, addr_parts, ":")
          port = addr_parts[n]
          sub(/[^0-9].*$/, "", port)
          if (port ~ /^[0-9]+$/) {
            print port
          }
        }
      }
    }
  ' "${rendered_path}" | sort -u
}

apply_selinux_port_policy_for_binds() {
  local rendered_path="$1"
  local mode=""
  local bind_port=""

  if [[ "${DRY_RUN}" == "true" ]]; then
    return 0
  fi

  if ! run_check_target "command -v getenforce"; then
    return 0
  fi

  mode="$(capture_target "getenforce | tr -d '[:space:]'" || true)"
  if [[ "${mode}" == "Disabled" || -z "${mode}" ]]; then
    return 0
  fi

  ensure_semanage_available_if_needed

  while IFS= read -r bind_port; do
    [[ -n "${bind_port}" ]] || continue
    run_target "$(as_root_cmd "semanage port -a -t http_port_t -p tcp ${bind_port} 2>/dev/null || semanage port -m -t http_port_t -p tcp ${bind_port}")"
  done < <(collect_bind_ports_from_rendered_cfg "${rendered_path}")
}

sed_escape_replacement() {
  printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

render_config() {
  local out_path="$1"
  local escaped_stats_user=""
  local escaped_stats_pass=""
  local escaped_stats_uri=""

  awk \
    -v global_block="${HAPROXY_GLOBAL_BLOCK:-}" \
    -v defaults_block="${HAPROXY_DEFAULTS_BLOCK:-}" \
    -v frontends_block="${HAPROXY_FRONTENDS_BLOCK}" \
    -v backends_block="${HAPROXY_BACKENDS_BLOCK}" \
    '
    function print_block(text, line_count, idx, lines) {
      line_count = split(text, lines, "\n")
      for (idx = 1; idx <= line_count; idx++) {
        print lines[idx]
      }
    }
    $0 == "__HAPROXY_GLOBAL_BLOCK__"   { print_block(global_block); next }
    $0 == "__HAPROXY_DEFAULTS_BLOCK__" { print_block(defaults_block); next }
    $0 == "__HAPROXY_FRONTENDS_BLOCK__" { print_block(frontends_block); next }
    $0 == "__HAPROXY_BACKENDS_BLOCK__" { print_block(backends_block); next }
    { print }
    ' "${TEMPLATE_PATH}" >"${out_path}"

  escaped_stats_user="$(sed_escape_replacement "${HAPROXY_STATS_USER}")"
  escaped_stats_pass="$(sed_escape_replacement "${HAPROXY_STATS_PASS}")"
  escaped_stats_uri="$(sed_escape_replacement "${HAPROXY_STATS_URI_RESOLVED}")"

  sed -i \
    -e "s|__HAPROXY_STATS_USER__|${escaped_stats_user}|g" \
    -e "s|__HAPROXY_STATS_PASS__|${escaped_stats_pass}|g" \
    -e "s|__HAPROXY_STATS_URI__|${escaped_stats_uri}|g" \
    "${out_path}"
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
    run_target "$(as_root_cmd "install -o root -g root -m 0640 ${q_rendered} ${q_output}")"
    return 0
  fi

  remote_tmp="/tmp/haproxy.cfg.$$.tmp"
  printf -v q_remote_tmp '%q' "${remote_tmp}"

  scp_upload "${rendered_path}" "${remote_tmp}"
  run_target "$(as_root_cmd "install -d -m 0755 $(printf '%q' "$(dirname "${OUTPUT_PATH}")")")"
  run_target "$(as_root_cmd "if [[ -f ${q_output} ]]; then cp -a ${q_output} ${q_backup}; fi")"
  run_target "$(as_root_cmd "install -o root -g root -m 0640 ${q_remote_tmp} ${q_output}")"
  run_target "rm -f ${q_remote_tmp}"
}

validate_and_reload() {
  local q_output=""
  local q_service=""

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Dry-run mode: skipping haproxy config validation and reload."
    return 0
  fi

  printf -v q_output '%q' "${OUTPUT_PATH}"
  printf -v q_service '%q' "${HAPROXY_SERVICE_NAME_RESOLVED}"

  run_target "$(as_root_cmd "haproxy -c -f ${q_output}")"

  if [[ "${RELOAD_SERVICE}" == "true" ]]; then
    run_target "$(as_root_cmd "systemctl reload ${q_service}")"
    run_target "$(as_root_cmd "systemctl is-active ${q_service}")"
  fi
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

  rendered_cfg="$(mktemp)"
  trap '[[ -n "${rendered_cfg:-}" ]] && rm -f "${rendered_cfg}"' EXIT

  render_config "${rendered_cfg}"
  apply_config "${rendered_cfg}"
  ensure_runtime_socket_dirs
  apply_selinux_port_policy_for_binds "${rendered_cfg}"
  validate_and_reload

  log_info "HAProxy setup completed for ${TARGET_LABEL}."
}

main "$@"
