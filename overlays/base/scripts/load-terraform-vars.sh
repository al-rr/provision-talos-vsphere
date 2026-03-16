#!/usr/bin/env bash
set -euo pipefail

# @describe Export Terraform variables from overlay vars.
# @option OVERLAY_ENV string Overlay environment to load before sourcing. Defaults to prod.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script must be sourced to persist environment variables."
  echo "Usage: OVERLAY_ENV=prod source ./load-terraform-vars.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/functions.sh"
load_overlay_vars "${OVERLAY_ENV:-prod}"
export_haproxy_terraform_vars

echo "[OK] TF_VAR_* variables exported for overlay ${OVERLAY_ENV:-prod}"
