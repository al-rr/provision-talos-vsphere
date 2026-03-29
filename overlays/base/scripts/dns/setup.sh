#!/usr/bin/env bash
# @file setup.sh
# @brief DNS setup wrapper for dnsmasq reusable module.
# @description
#   Delegates configuration rendering/apply to infra-gitops/scripts/dnsmasq/setup.sh,
#   auto-resolving env vars and remote target defaults.

set -euo pipefail

usage() {
  cat <<'EOF_USAGE'
Usage: setup.sh [dnsmasq setup options]

Options:
  --env=<name>        Overlay environment name (default: lab)
  --vars-file=<path>  Optional vars file; if omitted uses overlays/<env>/scripts/vars.sh
  --host=<host>       Optional target host override
  --user=<user>       Optional SSH user override
  --port=<port>       Optional SSH port override
  --ssh-key=<path>    Optional SSH private key override
  --show-values       Print selected project vars and resolved target values, then exit
  --dry-run, -n       Forward dry-run to target script
  --help, -h          Show help

All other arguments are forwarded to dnsmasq setup.sh.
EOF_USAGE
}

print_var_line() {
  local key="$1"
  local value="${2:-}"
  if [[ "${key}" =~ (PASSWORD|PASS|TOKEN|SECRET|PRIVATE_KEY|_KEY$) ]] && [[ -n "${value}" ]]; then
    value="***"
  fi
  printf '%s=%s\n' "${key}" "${value}"
}

print_selected_vars() {
  local vars_file="$1"
  local var_name
  echo "[INFO] Project vars from: ${vars_file}"
  while IFS= read -r var_name; do
    [[ -n "${var_name}" ]] || continue
    # shellcheck disable=SC2154
    print_var_line "${var_name}" "${!var_name:-}"
  done < <(awk 'match($0,/^export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)=/,m){print m[1]}' "${vars_file}")
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
DNSMASQ_DIR="${REPO_ROOT}/../infra-gitops/scripts/dnsmasq"
DNSMASQ_SETUP="${DNSMASQ_DIR}/setup.sh"

ENV_NAME="lab"
EXPLICIT_VARS_FILE=""
SELECTED_VARS_FILE=""
SHOW_VALUES="false"
HAS_HOST_ARG="false"
HAS_USER_ARG="false"
HAS_PORT_ARG="false"
HAS_SSH_KEY_ARG="false"

SETUP_ARGS=()
DNSMASQ_ENV_ARGS=()

if [[ ! -x "${DNSMASQ_SETUP}" ]]; then
  echo "[ERROR] Missing dnsmasq setup script: ${DNSMASQ_SETUP}" >&2
  echo "[ERROR] Ensure infra-gitops is available at: ${REPO_ROOT}/../infra-gitops" >&2
  exit 1
fi

for arg in "$@"; do
  case "${arg}" in
    --env=*) ENV_NAME="${arg#*=}" ;;
    --vars-file=*) EXPLICIT_VARS_FILE="${arg#*=}"; SETUP_ARGS+=("${arg}") ;;
    --host=*) HAS_HOST_ARG="true"; SETUP_ARGS+=("${arg}") ;;
    --user=*) HAS_USER_ARG="true"; SETUP_ARGS+=("${arg}") ;;
    --port=*) HAS_PORT_ARG="true"; SETUP_ARGS+=("${arg}") ;;
    --ssh-key=*) HAS_SSH_KEY_ARG="true"; SETUP_ARGS+=("${arg}") ;;
    --show-values) SHOW_VALUES="true" ;;
    -n|--dry-run) SETUP_ARGS+=("${arg}") ;;
    -h|--help) usage; exit 0 ;;
    *) SETUP_ARGS+=("${arg}") ;;
  esac
done

if [[ -z "${EXPLICIT_VARS_FILE}" ]]; then
  SELECTED_VARS_FILE="${REPO_ROOT}/overlays/${ENV_NAME}/scripts/vars.sh"
else
  SELECTED_VARS_FILE="${EXPLICIT_VARS_FILE}"
  [[ "${SELECTED_VARS_FILE}" = /* ]] || SELECTED_VARS_FILE="${REPO_ROOT}/${SELECTED_VARS_FILE}"
fi

if [[ ! -f "${SELECTED_VARS_FILE}" ]]; then
  echo "[ERROR] Missing vars file: ${SELECTED_VARS_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${SELECTED_VARS_FILE}"

# Bridge DNS module vars to reusable dnsmasq module vars (wrapper-local only).
DNSMASQ_DOMAIN_BRIDGE="${DNSMASQ_DOMAIN:-${DNS_DOMAIN:-}}"
DNSMASQ_LISTEN_ADDRESSES_BRIDGE="${DNSMASQ_LISTEN_ADDRESSES:-${DNS_LISTEN_ADDRESSES:-}}"
DNSMASQ_UPSTREAM_SERVERS_BRIDGE="${DNSMASQ_UPSTREAM_SERVERS:-${DNS_UPSTREAM_SERVERS:-}}"
DNSMASQ_USE_TCP_UPSTREAM_BRIDGE="${DNSMASQ_USE_TCP_UPSTREAM:-${DNS_USE_TCP_UPSTREAM:-}}"
DNSMASQ_A_RECORDS_BRIDGE="${DNSMASQ_A_RECORDS:-${DNS_A_RECORDS:-}}"

if [[ -z "${DNSMASQ_A_RECORDS_BRIDGE}" ]] && declare -p DNS_A_RECORDS_LIST >/dev/null 2>&1; then
  if [[ "${#DNS_A_RECORDS_LIST[@]}" -gt 0 ]]; then
    DNSMASQ_A_RECORDS_BRIDGE="$(printf '%s,' "${DNS_A_RECORDS_LIST[@]}")"
    DNSMASQ_A_RECORDS_BRIDGE="${DNSMASQ_A_RECORDS_BRIDGE%,}"
  fi
fi

if [[ "${HAS_HOST_ARG}" == "false" ]]; then
  AUTO_HOST="${DNS_VM_STATIC_IP:-}"
  if [[ -z "${AUTO_HOST}" ]]; then
    echo "[ERROR] No remote DNS host resolved." >&2
    echo "[ERROR] Set DNS_VM_STATIC_IP in overlays/${ENV_NAME}/scripts/vars.sh or pass --host=..." >&2
    exit 1
  fi
  SETUP_ARGS+=("--host=${AUTO_HOST}")
fi

if [[ "${HAS_USER_ARG}" == "false" ]]; then
  AUTO_USER="${DNS_SSH_USER:-${ANSIBLE_USERNAME:-${SSH_USER:-${BUILD_USERNAME:-}}}}"
  [[ -n "${AUTO_USER}" ]] && SETUP_ARGS+=("--user=${AUTO_USER}")
fi

if [[ "${HAS_PORT_ARG}" == "false" ]]; then
  AUTO_PORT="${DNS_SSH_PORT:-${SSH_PORT:-22}}"
  SETUP_ARGS+=("--port=${AUTO_PORT}")
fi

if [[ "${HAS_SSH_KEY_ARG}" == "false" ]]; then
  AUTO_SSH_KEY="${DNS_SSH_KEY:-${ANSIBLE_PRIVATE_KEY_FILE:-${SSH_PRIVATE_KEY_FILE:-}}}"
  [[ -n "${AUTO_SSH_KEY}" ]] && SETUP_ARGS+=("--ssh-key=${AUTO_SSH_KEY}")
fi

if [[ "${SHOW_VALUES}" == "true" ]]; then
  echo "[INFO] env=${ENV_NAME}"
  print_selected_vars "${SELECTED_VARS_FILE}"
  echo "[INFO] Resolved setup target:"
  print_var_line "DNS_TARGET_HOST" "${AUTO_HOST:-<from-cli>}"
  print_var_line "DNS_TARGET_USER" "${AUTO_USER:-<from-cli>}"
  print_var_line "DNS_TARGET_PORT" "${AUTO_PORT:-<from-cli>}"
  print_var_line "DNS_TARGET_SSH_KEY" "${AUTO_SSH_KEY:-<from-cli>}"
  exit 0
fi

if [[ -n "${DNSMASQ_DOMAIN_BRIDGE}" ]]; then
  DNSMASQ_ENV_ARGS+=("DNSMASQ_DOMAIN=${DNSMASQ_DOMAIN_BRIDGE}")
fi
if [[ -n "${DNSMASQ_LISTEN_ADDRESSES_BRIDGE}" ]]; then
  DNSMASQ_ENV_ARGS+=("DNSMASQ_LISTEN_ADDRESSES=${DNSMASQ_LISTEN_ADDRESSES_BRIDGE}")
fi
if [[ -n "${DNSMASQ_UPSTREAM_SERVERS_BRIDGE}" ]]; then
  DNSMASQ_ENV_ARGS+=("DNSMASQ_UPSTREAM_SERVERS=${DNSMASQ_UPSTREAM_SERVERS_BRIDGE}")
fi
if [[ -n "${DNSMASQ_USE_TCP_UPSTREAM_BRIDGE}" ]]; then
  DNSMASQ_ENV_ARGS+=("DNSMASQ_USE_TCP_UPSTREAM=${DNSMASQ_USE_TCP_UPSTREAM_BRIDGE}")
fi
if [[ -n "${DNSMASQ_A_RECORDS_BRIDGE}" ]]; then
  DNSMASQ_ENV_ARGS+=("DNSMASQ_A_RECORDS=${DNSMASQ_A_RECORDS_BRIDGE}")
fi

if [[ "${#DNSMASQ_ENV_ARGS[@]}" -gt 0 ]]; then
  exec env "${DNSMASQ_ENV_ARGS[@]}" "${DNSMASQ_SETUP}" "${SETUP_ARGS[@]}"
fi

exec "${DNSMASQ_SETUP}" "${SETUP_ARGS[@]}"
