#!/usr/bin/env bash
# @file run-full.sh
# @brief Orchestrate full DNS bootstrap flow.
# @description
#   Runs DNS VM provisioning, dnsmasq install, and dnsmasq setup in sequence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVISION_SCRIPT="${SCRIPT_DIR}/govc/provision.sh"
INSTALL_SCRIPT="${SCRIPT_DIR}/install.sh"
SETUP_SCRIPT="${SCRIPT_DIR}/setup.sh"

ENV_NAME="lab"
VARS_FILE=""
PROVISION_ACTION="create"
SHOW_VALUES="false"
SKIP_PROVISION="false"
SKIP_INSTALL="false"
SKIP_SETUP="false"
PASSTHROUGH_ARGS=()

usage() {
  cat <<'EOF_USAGE'
Usage: run-full.sh [options]

Options:
  --env=<name>             Overlay environment name (default: lab)
  --vars-file=<path>       Optional vars file override
  --provision-action=<a>   create|plan|destroy (default: create)
  --skip-provision         Skip VM provisioning step
  --skip-install           Skip dnsmasq install step
  --skip-setup             Skip dnsmasq setup step
  --show-values            Show effective project values (no changes)
  --help,-h                Show help

Any other arguments are forwarded to underlying scripts.
EOF_USAGE
}

for arg in "$@"; do
  case "${arg}" in
    --env=*) ENV_NAME="${arg#*=}" ;;
    --vars-file=*) VARS_FILE="${arg#*=}" ;;
    --provision-action=*) PROVISION_ACTION="${arg#*=}" ;;
    --skip-provision) SKIP_PROVISION="true" ;;
    --skip-install) SKIP_INSTALL="true" ;;
    --skip-setup) SKIP_SETUP="true" ;;
    --show-values) SHOW_VALUES="true" ;;
    -h|--help) usage; exit 0 ;;
    *) PASSTHROUGH_ARGS+=("${arg}") ;;
  esac
done

COMMON_ARGS=("--env=${ENV_NAME}")
if [[ -n "${VARS_FILE}" ]]; then
  COMMON_ARGS+=("--vars-file=${VARS_FILE}")
fi

if [[ "${SHOW_VALUES}" == "true" ]]; then
  echo "[INFO] DNS full flow values (env=${ENV_NAME})"
  if [[ "${SKIP_PROVISION}" != "true" ]]; then
    "${PROVISION_SCRIPT}" "${COMMON_ARGS[@]}" --show-values plan
  fi
  if [[ "${SKIP_INSTALL}" != "true" ]]; then
    "${INSTALL_SCRIPT}" "${COMMON_ARGS[@]}" --show-values
  fi
  if [[ "${SKIP_SETUP}" != "true" ]]; then
    "${SETUP_SCRIPT}" "${COMMON_ARGS[@]}" --show-values
  fi
  exit 0
fi

if [[ "${SKIP_PROVISION}" != "true" ]]; then
  "${PROVISION_SCRIPT}" "${COMMON_ARGS[@]}" "${PASSTHROUGH_ARGS[@]}" "${PROVISION_ACTION}"
fi

if [[ "${SKIP_INSTALL}" != "true" ]]; then
  "${INSTALL_SCRIPT}" "${COMMON_ARGS[@]}" "${PASSTHROUGH_ARGS[@]}"
fi

if [[ "${SKIP_SETUP}" != "true" ]]; then
  "${SETUP_SCRIPT}" "${COMMON_ARGS[@]}" "${PASSTHROUGH_ARGS[@]}"
fi

