#!/usr/bin/env bash
# @file reconcile-hosts.sh
# @brief Reconcile DNS owner records into dnsmasq hosts file and apply.
# @description
#   Aggregates owner-scoped record files from overlays/<env>/dns/records.d and
#   applies the merged host list through dns/setup.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BASE_SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=/dev/null
source "${BASE_SCRIPT_DIR}/functions.sh"

ENV_NAME="lab"
CUSTOM_VARS_FILE=""
STATE_DIR_OVERRIDE=""
SHOW_VALUES="false"
DRY_RUN="false"
SETUP_PASSTHROUGH=()

usage() {
  cat <<'EOF_USAGE'
Usage: reconcile-hosts.sh [options]

Options:
  --env=<name>             Overlay environment (default: lab)
  --vars-file=<path>       Optional vars override file
  --state-dir=<path>       Optional owner records directory override
  --show-values            Print resolved values and exit
  --dry-run,-n             Print actions without applying changes
  --help,-h                Show help

All unknown args are forwarded to dns/setup.sh.
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --vars-file=*) CUSTOM_VARS_FILE="${1#*=}"; shift ;;
      --state-dir=*) STATE_DIR_OVERRIDE="${1#*=}"; shift ;;
      --show-values) SHOW_VALUES="true"; shift ;;
      --dry-run|-n) DRY_RUN="true"; SETUP_PASSTHROUGH+=("--dry-run"); shift ;;
      --help|-h) usage; exit 0 ;;
      *) SETUP_PASSTHROUGH+=("$1"); shift ;;
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

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "${value}"
}

is_ipv4() {
  local ip="$1"
  [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local o1 o2 o3 o4
  IFS='.' read -r o1 o2 o3 o4 <<<"${ip}"
  (( o1 <= 255 && o2 <= 255 && o3 <= 255 && o4 <= 255 ))
}

parse_record() {
  local raw="$1"
  local item host_name host_ip
  item="$(trim "${raw}")"
  [[ -n "${item}" ]] || return 1
  [[ "${item}" == \#* ]] && return 1

  if [[ "${item}" != *"="* ]]; then
    die "Invalid record format '${raw}'. Expected host=ip"
  fi

  host_name="$(trim "${item%%=*}")"
  host_ip="$(trim "${item#*=}")"
  [[ -n "${host_name}" && -n "${host_ip}" ]] || die "Invalid record: ${raw}"
  is_ipv4 "${host_ip}" || die "Invalid IPv4 '${host_ip}' for host '${host_name}'"
  printf '%s=%s\n' "${host_name}" "${host_ip}"
}

build_merged_hosts_file() {
  local state_dir="$1"
  local merged_file="$2"
  local owner_file=""
  local record=""

  : > "${merged_file}"
  [[ -d "${state_dir}" ]] || return 0

  while IFS= read -r owner_file; do
    [[ -f "${owner_file}" ]] || continue
    while IFS= read -r record || [[ -n "${record}" ]]; do
      record="$(trim "${record}")"
      [[ -n "${record}" ]] || continue
      [[ "${record}" == \#* ]] && continue
      parse_record "${record}" >> "${merged_file}"
    done < "${owner_file}"
  done < <(find "${state_dir}" -maxdepth 1 -type f -name '*.records' | sort)

  if [[ -s "${merged_file}" ]]; then
    awk -F'=' '{ rec[$1]=$2 } END { for (h in rec) printf "%s=%s\n", h, rec[h] }' "${merged_file}" | sort > "${merged_file}.tmp"
    mv "${merged_file}.tmp" "${merged_file}"
  fi
}

main() {
  local state_dir=""
  local setup_script="${SCRIPT_DIR}/setup.sh"
  local merged_records=""
  local setup_args=()
  local file_count="0"

  parse_args "$@"
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
  mkdir -p "${state_dir}"
  file_count="$(find "${state_dir}" -maxdepth 1 -type f -name '*.records' | wc -l | tr -d ' ')"

  if [[ "${SHOW_VALUES}" == "true" ]]; then
    log_info "env=${ENV_NAME}"
    log_info "dns-state-dir=${state_dir}"
    log_info "owner-files=${file_count}"
    exit 0
  fi

  merged_records="$(mktemp)"
  build_merged_hosts_file "${state_dir}" "${merged_records}"

  setup_args+=("--env=${ENV_NAME}")
  [[ -n "${CUSTOM_VARS_FILE}" ]] && setup_args+=("--vars-file=${CUSTOM_VARS_FILE}")
  setup_args+=("--hosts-file=${merged_records}")
  setup_args+=("${SETUP_PASSTHROUGH[@]}")

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] merged-records-file=${merged_records}"
  fi

  "${setup_script}" "${setup_args[@]}"
  rm -f "${merged_records}"
}

main "$@"

