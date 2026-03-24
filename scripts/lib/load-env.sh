#!/usr/bin/env bash

# @describe Legacy compatibility shim for the overlay-based variable model.
# @option $1 string Optional legacy env file path. Defaults to .env.
# @exitcode 0 If the shim is sourced successfully.
# @exitcode 1 If executed directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This file is a compatibility library and must be sourced by another script."
  exit 1
fi

_shim_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_shim_dir}/../../overlays/base/scripts/functions.sh"

load_project_env() {
  local env_file="${1:-.env}"

  if [[ ! -f "${env_file}" ]]; then
    echo "[ERROR] Legacy env file not found: ${env_file}" >&2
    return 1
  fi

  echo "[WARN] scripts/lib/load-env.sh is deprecated. Prefer overlays/base/scripts/vars.sh and overlays/<env>/scripts/vars.sh." >&2
  set -a
  # shellcheck disable=SC1090
  source "${env_file}"
  set +a
  normalize_global_env
}

export_terraform_vars() {
  export_haproxy_terraform_vars
}