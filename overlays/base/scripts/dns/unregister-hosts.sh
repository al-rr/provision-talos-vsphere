#!/usr/bin/env bash
# @file unregister-hosts.sh
# @brief Remove all DNS records for a module owner.
# @description
#   Deletes overlays/<env>/dns/records.d/<owner>.records and reconciles dnsmasq.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BASE_SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=/dev/null
source "${BASE_SCRIPT_DIR}/functions.sh"

ENV_NAME="lab"
CUSTOM_VARS_FILE=""
OWNER=""
STATE_DIR_OVERRIDE=""
SHOW_VALUES="false"
NO_APPLY="false"
DRY_RUN="false"
PASSTHROUGH_ARGS=()

usage() {
  cat <<'EOF_USAGE'
Usage: unregister-hosts.sh [options]

Options:
  --env=<name>             Overlay environment (default: lab)
  --vars-file=<path>       Optional vars override file
  --owner=<name>           Owner id (required)
  --state-dir=<path>       Optional owner records directory override
  --no-apply               Remove owner file only (do not call reconcile)
  --show-values            Print resolved values and exit
  --dry-run,-n             Print actions without changing files
  --help,-h                Show help
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --vars-file=*) CUSTOM_VARS_FILE="${1#*=}"; shift ;;
      --owner=*) OWNER="${1#*=}"; shift ;;
      --state-dir=*) STATE_DIR_OVERRIDE="${1#*=}"; shift ;;
      --no-apply) NO_APPLY="true"; shift ;;
      --show-values) SHOW_VALUES="true"; shift ;;
      --dry-run|-n) DRY_RUN="true"; PASSTHROUGH_ARGS+=("--dry-run"); shift ;;
      --help|-h) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done
}

resolve_state_dir() {
  if [[ -n "${STATE_DIR_OVERRIDE}" ]]; then
    if [[ "${STATE_DIR_OVERRIDE}" = /* ]]; then
      printf '%s\n' "${STATE_DIR_OVERRIDE}"
    else
      printf '%s\n' "${REPO_ROOT}/${STATE_DIR_OVERRIDE}"
    fi
    return 0
  fi
  printf '%s\n' "${REPO_ROOT}/overlays/${ENV_NAME}/dns/records.d"
}

main() {
  local state_dir=""
  local owner_file=""
  local reconcile_script="${SCRIPT_DIR}/reconcile-hosts.sh"
  local reconcile_args=()

  parse_args "$@"
  [[ -n "${OWNER}" ]] || die "--owner is required."
  [[ "${OWNER}" =~ ^[a-zA-Z0-9._-]+$ ]] || die "--owner contains invalid characters."

  load_overlay_vars "${ENV_NAME}"
  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    if [[ "${CUSTOM_VARS_FILE}" != /* ]]; then
      CUSTOM_VARS_FILE="${REPO_ROOT}/${CUSTOM_VARS_FILE}"
    fi
    require_file "${CUSTOM_VARS_FILE}"
    # shellcheck disable=SC1090
    source "${CUSTOM_VARS_FILE}"
  fi

  state_dir="$(resolve_state_dir)"
  owner_file="${state_dir}/${OWNER}.records"

  if [[ "${SHOW_VALUES}" == "true" ]]; then
    log_info "env=${ENV_NAME}"
    log_info "owner=${OWNER}"
    log_info "state-dir=${state_dir}"
    log_info "owner-file=${owner_file}"
    exit 0
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] rm -f ${owner_file}"
  else
    rm -f "${owner_file}"
  fi

  if [[ "${NO_APPLY}" == "true" ]]; then
    log_info "Owner records removed: ${owner_file}"
    exit 0
  fi

  reconcile_args+=("--env=${ENV_NAME}")
  [[ -n "${CUSTOM_VARS_FILE}" ]] && reconcile_args+=("--vars-file=${CUSTOM_VARS_FILE}")
  [[ -n "${STATE_DIR_OVERRIDE}" ]] && reconcile_args+=("--state-dir=${STATE_DIR_OVERRIDE}")
  reconcile_args+=("${PASSTHROUGH_ARGS[@]}")
  "${reconcile_script}" "${reconcile_args[@]}"
}

main "$@"

