#!/usr/bin/env bash
# @file configure_load_balancer.sh
# @brief Configure HAProxy backends for a Talos control-plane set.
# @description
#   Builds a TCP backend block from TALOS control-plane IPs and applies it to
#   HAProxy nodes by reusing overlays/base/scripts/ha-proxy/setup.sh.
#
# @arg --env,-e string Overlay environment name. Defaults to lab.
# @arg --cp-ips string Optional control-plane IP list override (CSV/space/JSON-like).
# @arg --lb-hosts string Optional HAProxy host list override (CSV/space/JSON-like).
# @arg --vars-file string Optional vars file to source after overlay vars (GOVC profile).
# @arg --user string SSH user for HAProxy hosts. Defaults to BUILD_USERNAME or root.
# @arg --port string SSH port for HAProxy hosts. Defaults to 22.
# @arg --ssh-key string SSH private key used for all HAProxy hosts.
# @arg --backend-name string HAProxy backend name. Defaults to talos_k8s_api_backend.
# @arg --api-port string Talos API port. Defaults to 6443.
# @arg --bootstrap-file string Optional bootstrap inventory fallback file.
# @flag --dry-run,-n Print actions without applying changes.
# @flag --help,-h Show usage information.

set -euo pipefail

ENV_NAME="lab"
DRY_RUN="false"
SSH_USER=""
SSH_PORT="22"
SSH_KEY=""
BACKEND_NAME="talos_k8s_api_backend"
API_PORT="6443"
CP_IPS_OVERRIDE=""
LB_HOSTS_OVERRIDE=""
BOOTSTRAP_FILE_OVERRIDE=""
CUSTOM_VARS_FILE=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BASE_SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=/dev/null
source "${BASE_SCRIPT_DIR}/functions.sh"

HAPROXY_SETUP_SCRIPT="${REPO_ROOT}/overlays/base/scripts/ha-proxy/setup.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -e, --env=<env>             Overlay environment (default: lab)
      --cp-ips=<list>         Control-plane IPs (CSV/space/JSON-like)
      --lb-hosts=<list>       HAProxy hosts (CSV/space/JSON-like)
      --user=<user>           SSH user for HAProxy hosts
      --port=<port>           SSH port (default: 22)
      --ssh-key=<path>        SSH private key used for HAProxy hosts
      --backend-name=<name>   HAProxy backend name (default: talos_k8s_api_backend)
      --api-port=<port>       Talos API port (default: 6443)
      --bootstrap-file=<path> Bootstrap inventory fallback file
  -n, --dry-run               Show actions without executing
  -h, --help                  Show this help
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
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --cp-ips=*) CP_IPS_OVERRIDE="${1#*=}"; shift ;;
      --lb-hosts=*) LB_HOSTS_OVERRIDE="${1#*=}"; shift ;;
      --vars-file=*) CUSTOM_VARS_FILE="${1#*=}"; shift ;;
      --user=*) SSH_USER="${1#*=}"; shift ;;
      --port=*) SSH_PORT="${1#*=}"; shift ;;
      --ssh-key=*) SSH_KEY="${1#*=}"; shift ;;
      --backend-name=*) BACKEND_NAME="${1#*=}"; shift ;;
      --api-port=*) API_PORT="${1#*=}"; shift ;;
      --bootstrap-file=*) BOOTSTRAP_FILE_OVERRIDE="${1#*=}"; shift ;;
      -n|--dry-run) DRY_RUN="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "${value}"
}

parse_list_items() {
  local raw="$1"
  printf '%s' "${raw}" \
    | tr -d '[]"' \
    | tr ',' '\n' \
    | tr ' ' '\n' \
    | tr '\t' '\n' \
    | awk 'NF'
}

is_ipv4() {
  local ip="$1"
  [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local o1 o2 o3 o4
  IFS='.' read -r o1 o2 o3 o4 <<<"${ip}"
  (( o1 <= 255 && o2 <= 255 && o3 <= 255 && o4 <= 255 ))
}

resolve_repo_path() {
  local path_value="$1"
  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
  else
    printf '%s\n' "${REPO_ROOT}/${path_value}"
  fi
}

collect_cp_ips_from_bootstrap_file() {
  local bootstrap_file="$1"
  [[ -f "${bootstrap_file}" ]] || return 0
  awk '/^control-plane-[0-9]+[[:space:]]+/ {print $3}' "${bootstrap_file}" | awk 'NF'
}

build_backend_block() {
  local backend_name="$1"
  local api_port="$2"
  shift 2
  local ips=("$@")
  local block=""
  local idx=0
  local ip=""
  local server_name=""

  block+=$'backend '"${backend_name}"$'\n'
  block+=$'  mode tcp\n'
  block+=$'  balance roundrobin\n'
  block+=$'  option tcp-check\n'

  for ip in "${ips[@]}"; do
    idx=$((idx + 1))
    printf -v server_name 'cp%02d' "${idx}"
    block+="  server ${server_name} ${ip}:${api_port} check"$'\n'
  done

  printf '%s' "${block}"
}

run_or_echo() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

main() {
  local cp_source=""
  local lb_source=""
  local bootstrap_file=""
  local cp_raw=""
  local lb_raw=""
  local cp_ip=""
  local lb_host=""
  local backend_block=""
  local q_backend=""
  local ssh_user_resolved=""
  local -a cp_ips=()
  local -a lb_hosts=()
  local setup_cmd=()

  parse_args "$@"
  load_overlay_vars "${ENV_NAME}"
  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    CUSTOM_VARS_FILE="$(resolve_repo_path "${CUSTOM_VARS_FILE}")"
    require_file "${CUSTOM_VARS_FILE}"
    # shellcheck disable=SC1090
    source "${CUSTOM_VARS_FILE}"
    normalize_global_env
  fi
  require_file "${HAPROXY_SETUP_SCRIPT}"

  [[ "${SSH_PORT}" =~ ^[0-9]+$ ]] || die "--port must be numeric."
  [[ "${SSH_PORT}" -ge 1 && "${SSH_PORT}" -le 65535 ]] || die "--port must be between 1 and 65535."
  [[ -n "${BACKEND_NAME}" ]] || die "--backend-name cannot be empty."
  [[ "${API_PORT}" =~ ^[0-9]+$ ]] || die "--api-port must be numeric."
  [[ "${API_PORT}" -ge 1 && "${API_PORT}" -le 65535 ]] || die "--api-port must be between 1 and 65535."

  cp_source="${CP_IPS_OVERRIDE:-}"
  if [[ -z "${cp_source}" ]]; then
    cp_source="${TALOS_CONTROL_PLANE_IPS:-}"
  fi

  bootstrap_file="${BOOTSTRAP_FILE_OVERRIDE:-}"
  if [[ -z "${bootstrap_file}" ]]; then
    bootstrap_file="$(dirname "$(resolve_repo_path "${TALOS_CONTROL_PLANE_CONFIG_PATH}")")/bootstrap-ips.txt"
  else
    bootstrap_file="$(resolve_repo_path "${bootstrap_file}")"
  fi

  if [[ -z "${cp_source}" ]]; then
    while IFS= read -r cp_raw; do
      cp_raw="$(trim "${cp_raw}")"
      [[ -n "${cp_raw}" ]] || continue
      cp_ips+=("${cp_raw}")
    done < <(collect_cp_ips_from_bootstrap_file "${bootstrap_file}")
  else
    while IFS= read -r cp_raw; do
      cp_raw="$(trim "${cp_raw}")"
      [[ -n "${cp_raw}" ]] || continue
      cp_ips+=("${cp_raw}")
    done < <(parse_list_items "${cp_source}")
  fi

  (( ${#cp_ips[@]} > 0 )) || die "No control-plane IPs found. Set TALOS_CONTROL_PLANE_IPS or provide --cp-ips."
  for cp_ip in "${cp_ips[@]}"; do
    is_ipv4 "${cp_ip}" || die "Invalid control-plane IP: ${cp_ip}"
  done

  lb_source="${LB_HOSTS_OVERRIDE:-}"
  if [[ -z "${lb_source}" ]]; then
    lb_source="${HAPROXY_NODE_1_IP:-},${HAPROXY_NODE_2_IP:-}"
  fi
  while IFS= read -r lb_raw; do
    lb_raw="$(trim "${lb_raw}")"
    [[ -n "${lb_raw}" ]] || continue
    lb_hosts+=("${lb_raw}")
  done < <(parse_list_items "${lb_source}")

  (( ${#lb_hosts[@]} > 0 )) || die "No HAProxy hosts found. Set HAPROXY_NODE_1_IP/HAPROXY_NODE_2_IP or use --lb-hosts."

  ssh_user_resolved="${SSH_USER:-${HAPROXY_SSH_USER:-${ANSIBLE_USER:-${BUILD_USERNAME:-root}}}}"
  if [[ -n "${SSH_KEY}" ]]; then
    [[ -f "${SSH_KEY}" ]] || die "SSH key not found: ${SSH_KEY}"
  fi

  backend_block="$(build_backend_block "${BACKEND_NAME}" "${API_PORT}" "${cp_ips[@]}")"
  printf -v q_backend '%q' "${backend_block}"

  log_info "Configuring HAProxy backend '${BACKEND_NAME}' with ${#cp_ips[@]} control-plane node(s)."
  log_info "Targets: ${lb_hosts[*]}"

  for lb_host in "${lb_hosts[@]}"; do
    setup_cmd=("${HAPROXY_SETUP_SCRIPT}" "--env=${ENV_NAME}" "--host=${lb_host}" "--user=${ssh_user_resolved}" "--port=${SSH_PORT}")
    if [[ -n "${SSH_KEY}" ]]; then
      setup_cmd+=("--ssh-key=${SSH_KEY}")
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] HAPROXY_BACKENDS_BLOCK=${q_backend} ${setup_cmd[*]}"
      continue
    fi

    HAPROXY_BACKENDS_BLOCK="${backend_block}" "${setup_cmd[@]}"
  done

  log_info "HAProxy Talos backend configuration completed."
}

main "$@"
