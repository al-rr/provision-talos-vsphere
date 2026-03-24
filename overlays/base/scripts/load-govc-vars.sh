#!/usr/bin/env bash
set -euo pipefail

# @describe Export GOVC_* values from overlay vars.
# @option OVERLAY_ENV string Overlay environment to load before sourcing. Defaults to lab.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script must be sourced to persist environment variables."
  echo "Usage: OVERLAY_ENV=lab source ./load-govc-vars.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/functions.sh"
load_overlay_vars "${OVERLAY_ENV:-lab}"
export_common_tool_env

echo "[OK] GOVC_* variables exported for overlay ${OVERLAY_ENV:-lab}"
