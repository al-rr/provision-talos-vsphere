#!/usr/bin/env bash
# @file export-pkr-vars.sh
# @brief Source-only loader that exports PKR_VAR_* from module vars.
# @description
#   Loading order:
#   1) packer/vars.sh
#   2) packer/vars.local.sh (optional)
#
# @example
#   source ./packer/export-pkr-vars.sh

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script must be sourced to persist environment variables."
  echo "Usage: source ./packer/export-pkr-vars.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/pkr-vars.sh"
pkr_load_module_vars
pkr_export_common_env
pkr_export_vars

if [[ "${PKR_EXPORT_SILENT:-false}" != "true" ]]; then
  echo "[OK] Packer vars exported from module contract."
  echo "[OK] VSPHERE_ENDPOINT=${VSPHERE_ENDPOINT:-<unset>}"
  echo "[OK] PKR_VAR_vsphere_endpoint=${PKR_VAR_vsphere_endpoint:-<unset>}"
fi
