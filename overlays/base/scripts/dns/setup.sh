
#!/usr/bin/env bash
# @file setup.sh
# @brief DNS install+setup wrapper for dnsmasq reusable module.
# @description
#   Runs dnsmasq install first and then setup from infra-gitops/scripts/dnsmasq,
#   while keeping a DNS module entrypoint in this repository.

set -euo pipefail

usage() {
  cat <<'EOF_USAGE'
Usage: setup.sh [dnsmasq setup options]

This wrapper executes:
1) infra-gitops/scripts/dnsmasq/install.sh
2) infra-gitops/scripts/dnsmasq/setup.sh

Common forwarded options to install+setup:
  --env=<name>        Overlay environment name (default: lab)
  --host=...
  --user=...
  --port=...
  --ssh-key=...
  --vars-file=...
  --dry-run | -n

All options are still forwarded to setup.sh.
EOF_USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
DNSMASQ_DIR="${REPO_ROOT}/../infra-gitops/scripts/dnsmasq"
DNSMASQ_INSTALL="${DNSMASQ_DIR}/install.sh"
DNSMASQ_SETUP="${DNSMASQ_DIR}/setup.sh"
ENV_NAME="lab"
EXPLICIT_VARS_FILE=""
SELECTED_VARS_FILE=""
HAS_HOST_ARG="false"
HAS_USER_ARG="false"
HAS_PORT_ARG="false"
HAS_SSH_KEY_ARG="false"

if [[ ! -x "${DNSMASQ_INSTALL}" || ! -x "${DNSMASQ_SETUP}" ]]; then
  echo "[ERROR] Missing dnsmasq scripts under: ${DNSMASQ_DIR}" >&2
  echo "[ERROR] Ensure infra-gitops is available at: ${REPO_ROOT}/../infra-gitops" >&2
  exit 1
fi

INSTALL_ARGS=()
SETUP_ARGS=()

for arg in "$@"; do
  case "${arg}" in
    --env=*)
      ENV_NAME="${arg#*=}"
      ;;
    --vars-file=*)
      EXPLICIT_VARS_FILE="${arg#*=}"
      INSTALL_ARGS+=("${arg}")
      SETUP_ARGS+=("${arg}")
      ;;
    --host=*)
      HAS_HOST_ARG="true"
      INSTALL_ARGS+=("${arg}")
      SETUP_ARGS+=("${arg}")
      ;;
    --user=*)
      HAS_USER_ARG="true"
      INSTALL_ARGS+=("${arg}")
      SETUP_ARGS+=("${arg}")
      ;;
    --port=*)
      HAS_PORT_ARG="true"
      INSTALL_ARGS+=("${arg}")
      SETUP_ARGS+=("${arg}")
      ;;
    --ssh-key=*)
      HAS_SSH_KEY_ARG="true"
      INSTALL_ARGS+=("${arg}")
      SETUP_ARGS+=("${arg}")
      ;;
    -n|--dry-run)
      INSTALL_ARGS+=("${arg}")
      SETUP_ARGS+=("${arg}")
      ;;
    -h|--help)
      usage
      exec "${DNSMASQ_SETUP}" --help
      ;;
    *)
      SETUP_ARGS+=("${arg}")
      ;;
  esac
done

if [[ -z "${EXPLICIT_VARS_FILE}" ]]; then
  SELECTED_VARS_FILE="${REPO_ROOT}/overlays/${ENV_NAME}/scripts/vars.sh"
  if [[ ! -f "${SELECTED_VARS_FILE}" ]]; then
    echo "[ERROR] Missing overlay vars file for env '${ENV_NAME}': ${SELECTED_VARS_FILE}" >&2
    echo "[ERROR] Pass --vars-file=<path> or create overlays/${ENV_NAME}/scripts/vars.sh" >&2
    exit 1
  fi
  INSTALL_ARGS+=("--vars-file=${SELECTED_VARS_FILE}")
  SETUP_ARGS+=("--vars-file=${SELECTED_VARS_FILE}")
else
  SELECTED_VARS_FILE="${EXPLICIT_VARS_FILE}"
fi

# shellcheck disable=SC1090
source "${SELECTED_VARS_FILE}"

if [[ "${HAS_HOST_ARG}" == "false" ]]; then
  AUTO_HOST="${DNS_VM_STATIC_IP:-}"
  if [[ -n "${AUTO_HOST}" ]]; then
    INSTALL_ARGS+=("--host=${AUTO_HOST}")
    SETUP_ARGS+=("--host=${AUTO_HOST}")
  else
    echo "[ERROR] No remote DNS host resolved." >&2
    echo "[ERROR] Set DNS_VM_STATIC_IP in overlays/${ENV_NAME}/scripts/vars.sh or pass --host=..." >&2
    exit 1
  fi
fi

if [[ "${HAS_USER_ARG}" == "false" ]]; then
  AUTO_USER="${DNS_SSH_USER:-${ANSIBLE_USERNAME:-${SSH_USER:-${BUILD_USERNAME:-}}}}"
  if [[ -n "${AUTO_USER}" ]]; then
    INSTALL_ARGS+=("--user=${AUTO_USER}")
    SETUP_ARGS+=("--user=${AUTO_USER}")
  fi
fi

if [[ "${HAS_PORT_ARG}" == "false" ]]; then
  AUTO_PORT="${DNS_SSH_PORT:-${SSH_PORT:-22}}"
  INSTALL_ARGS+=("--port=${AUTO_PORT}")
  SETUP_ARGS+=("--port=${AUTO_PORT}")
fi

if [[ "${HAS_SSH_KEY_ARG}" == "false" ]]; then
  AUTO_SSH_KEY="${DNS_SSH_KEY:-${ANSIBLE_PRIVATE_KEY_FILE:-${SSH_PRIVATE_KEY_FILE:-}}}"
  if [[ -n "${AUTO_SSH_KEY}" ]]; then
    INSTALL_ARGS+=("--ssh-key=${AUTO_SSH_KEY}")
    SETUP_ARGS+=("--ssh-key=${AUTO_SSH_KEY}")
  fi
fi

"${DNSMASQ_INSTALL}" "${INSTALL_ARGS[@]}"
exec "${DNSMASQ_SETUP}" "${SETUP_ARGS[@]}"
