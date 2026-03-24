#!/usr/bin/env bash
# Compatibility wrapper: delegates HAProxy setup lifecycle to infra-gitops module.

set -euo pipefail

usage() {
  cat <<'EOF_USAGE'
Usage: setup.sh [ha-proxy setup options]

Options:
  --env=<name>        Overlay environment name (default: lab)
  --vars-file=<path>  Optional vars file; if omitted uses overlays/<env>/scripts/vars.sh
  --host=<host>       Optional target host override
  --user=<user>       Optional SSH user override
  --port=<port>       Optional SSH port override
  --ssh-key=<path>    Optional SSH private key override
  --show-values       Print selected project vars and resolved target values, then exit
  --help, -h          Show help

All other arguments are forwarded to infra-gitops/scripts/ha-proxy/setup.sh.
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
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"
INFRA_GITOPS_ROOT="${INFRA_GITOPS_ROOT:-${REPO_ROOT}/../infra-gitops}"
TARGET_SCRIPT="${INFRA_GITOPS_ROOT}/scripts/ha-proxy/setup.sh"

ENV_NAME="lab"
EXPLICIT_VARS_FILE=""
SELECTED_VARS_FILE=""
SHOW_VALUES="false"
HAS_HOST_ARG="false"
HAS_USER_ARG="false"
HAS_PORT_ARG="false"
HAS_SSH_KEY_ARG="false"
SETUP_ARGS=()

if [[ ! -x "${TARGET_SCRIPT}" ]]; then
  echo "[ERROR] Missing executable script: ${TARGET_SCRIPT}" >&2
  echo "[INFO] Set INFRA_GITOPS_ROOT or install module in /home/vagrant/infra-gitops." >&2
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

if [[ "${HAS_HOST_ARG}" == "false" ]]; then
  AUTO_HOST="${HAPROXY_NODE_1_IP:-}"
  [[ -n "${AUTO_HOST}" ]] && SETUP_ARGS+=("--host=${AUTO_HOST}")
fi
if [[ "${HAS_USER_ARG}" == "false" ]]; then
  AUTO_USER="${SSH_USER:-${ANSIBLE_USERNAME:-${BUILD_USERNAME:-}}}"
  [[ -n "${AUTO_USER}" ]] && SETUP_ARGS+=("--user=${AUTO_USER}")
fi
if [[ "${HAS_PORT_ARG}" == "false" ]]; then
  AUTO_PORT="${SSH_PORT:-22}"
  SETUP_ARGS+=("--port=${AUTO_PORT}")
fi
if [[ "${HAS_SSH_KEY_ARG}" == "false" ]]; then
  AUTO_SSH_KEY="${SSH_PRIVATE_KEY_FILE:-${ANSIBLE_PRIVATE_KEY_FILE:-}}"
  [[ -n "${AUTO_SSH_KEY}" ]] && SETUP_ARGS+=("--ssh-key=${AUTO_SSH_KEY}")
fi

if [[ "${SHOW_VALUES}" == "true" ]]; then
  echo "[INFO] env=${ENV_NAME}"
  print_selected_vars "${SELECTED_VARS_FILE}"
  echo "[INFO] Resolved setup target:"
  print_var_line "HAPROXY_TARGET_HOST" "${AUTO_HOST:-<from-cli>}"
  print_var_line "HAPROXY_TARGET_USER" "${AUTO_USER:-<from-cli>}"
  print_var_line "HAPROXY_TARGET_PORT" "${AUTO_PORT:-<from-cli>}"
  print_var_line "HAPROXY_TARGET_SSH_KEY" "${AUTO_SSH_KEY:-<from-cli>}"
  exit 0
fi

exec "${TARGET_SCRIPT}" "${SETUP_ARGS[@]}"
