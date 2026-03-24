#!/usr/bin/env bash
# @file env.sh
# @brief Source helper for repository Packer/GOVC environment.
# @description
#   Load overlay vars and export GOVC_* and PKR_VAR_* in the current shell.
#   Optionally sources packer/env.local.sh for local secret overrides.
#
# @option OVERLAY_ENV string Overlay to load. Defaults to lab.
# @flag PACKER_ENABLE_LOG Set to true to enable PACKER_LOG.
#
# @example
#   OVERLAY_ENV=lab source ./packer/env.sh

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script must be sourced to persist environment variables."
  echo "Usage: OVERLAY_ENV=lab source ./packer/env.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OVERLAY_ENV="${OVERLAY_ENV:-lab}"

LOCAL_ENV_FILE="${SCRIPT_DIR}/env.local.sh"
LOAD_GOVC_VARS="${REPO_ROOT}/overlays/base/scripts/load-govc-vars.sh"
LOAD_PACKER_VARS="${REPO_ROOT}/overlays/base/scripts/load-packer-vars.sh"

if [[ ! -f "${LOAD_GOVC_VARS}" || ! -f "${LOAD_PACKER_VARS}" ]]; then
  echo "[ERROR] Missing loader scripts under overlays/base/scripts."
  return 1
fi

if [[ -f "${LOCAL_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${LOCAL_ENV_FILE}"
fi

# shellcheck disable=SC1090
OVERLAY_ENV="${OVERLAY_ENV}" source "${LOAD_GOVC_VARS}"
# shellcheck disable=SC1090
OVERLAY_ENV="${OVERLAY_ENV}" source "${LOAD_PACKER_VARS}"

if [[ "${PACKER_ENABLE_LOG:-false}" == "true" ]]; then
  export PACKER_LOG=1
  export PACKER_LOG_PATH="${PACKER_LOG_PATH:-/tmp/packer/packer.log}"
  mkdir -p "$(dirname "${PACKER_LOG_PATH}")"
fi

echo "[OK] Environment loaded for overlay '${OVERLAY_ENV}'."
echo "[OK] GOVC_URL=${GOVC_URL:-<unset>}"
echo "[OK] PKR_VAR_vsphere_endpoint=${PKR_VAR_vsphere_endpoint:-<unset>}"
