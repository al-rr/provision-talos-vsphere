#!/usr/bin/env bash
# @file register-hosts.sh
# @brief Register or replace DNS records for a module owner.
# @description
#   Writes owner-scoped records to overlays/<env>/dns/records.d/<owner>.records
#   and reconciles dnsmasq via dns/reconcile-hosts.sh.

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
RECORDS_RAW=""
RECORDS_FILE=""
declare -a RECORD_LIST=()
PASSTHROUGH_ARGS=()

usage() {
  cat <<'EOF_USAGE'
Usage: register-hosts.sh [options]

Options:
  --env=<name>             Overlay environment (default: lab)
  --vars-file=<path>       Optional vars override file
  --owner=<name>           Owner id (example: talos, ha-proxy) [required]
  --record=<host=ip>       Host record (repeatable)
  --records=<list>         CSV/JSON-like list of host=ip
  --records-file=<path>    File with host=ip entries (one per line)
  --state-dir=<path>       Optional owner records directory override
  --no-apply               Save owner file only (do not call reconcile)
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
      --record=*) RECORD_LIST+=("${1#*=}"); shift ;;
      --records=*) RECORDS_RAW="${1#*=}"; shift ;;
      --records-file=*) RECORDS_FILE="${1#*=}"; shift ;;
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

normalize_csv_list() {
  local raw="$1"
  raw="${raw//[/}"
  raw="${raw//]/}"
  raw="${raw//\"/}"
  printf '%s\n' "${raw}"
}

parse_csv_to_list() {
  local raw="$1"
  printf '%s' "${raw}" | tr ',' '\n' | awk 'NF'
}

validate_record() {
  local raw="$1"
  local item host_name host_ip
  item="$(trim "${raw}")"
  [[ -n "${item}" ]] || return 1
  [[ "${item}" == \#* ]] && return 1
  [[ "${item}" == *"="* ]] || die "Invalid record '${raw}', expected host=ip"
  host_name="$(trim "${item%%=*}")"
  host_ip="$(trim "${item#*=}")"
  [[ -n "${host_name}" && -n "${host_ip}" ]] || die "Invalid record '${raw}'"
  is_ipv4 "${host_ip}" || die "Invalid IPv4 '${host_ip}' in record '${raw}'"
  printf '%s=%s\n' "${host_name}" "${host_ip}"
}

collect_records() {
  local raw_record=""
  local csv=""

  for raw_record in "${RECORD_LIST[@]}"; do
    validate_record "${raw_record}" >/dev/null
  done

  if [[ -n "${RECORDS_RAW}" ]]; then
    csv="$(normalize_csv_list "${RECORDS_RAW}")"
    while IFS= read -r raw_record; do
      raw_record="$(trim "${raw_record}")"
      [[ -n "${raw_record}" ]] || continue
      RECORD_LIST+=("${raw_record}")
      validate_record "${raw_record}" >/dev/null
    done < <(parse_csv_to_list "${csv}")
  fi

  if [[ -n "${RECORDS_FILE}" ]]; then
    [[ "${RECORDS_FILE}" = /* ]] || RECORDS_FILE="${REPO_ROOT}/${RECORDS_FILE}"
    require_file "${RECORDS_FILE}"
    while IFS= read -r raw_record || [[ -n "${raw_record}" ]]; do
      raw_record="$(trim "${raw_record}")"
      [[ -n "${raw_record}" ]] || continue
      [[ "${raw_record}" == \#* ]] && continue
      RECORD_LIST+=("${raw_record}")
      validate_record "${raw_record}" >/dev/null
    done < "${RECORDS_FILE}"
  fi

  (( ${#RECORD_LIST[@]} > 0 )) || die "At least one DNS record is required."
}

main() {
  local state_dir=""
  local owner_file=""
  local record=""
  local tmp_file=""
  local reconcile_script="${SCRIPT_DIR}/reconcile-hosts.sh"
  local reconcile_args=()

  parse_args "$@"
  [[ -n "${OWNER}" ]] || die "--owner is required."
  [[ "${OWNER}" =~ ^[a-zA-Z0-9._-]+$ ]] || die "--owner contains invalid characters."
  collect_records

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
    log_info "records=${#RECORD_LIST[@]}"
    exit 0
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] owner-file=${owner_file}"
    for record in "${RECORD_LIST[@]}"; do
      log_info "[DRY-RUN] record=$(validate_record "${record}")"
    done
  else
    mkdir -p "${state_dir}"
    tmp_file="$(mktemp)"
    for record in "${RECORD_LIST[@]}"; do
      validate_record "${record}" >> "${tmp_file}"
    done
    awk -F'=' '{ rec[$1]=$2 } END { for (h in rec) printf "%s=%s\n", h, rec[h] }' "${tmp_file}" | sort > "${owner_file}"
    rm -f "${tmp_file}"
  fi

  if [[ "${NO_APPLY}" == "true" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Owner records would be saved: ${owner_file}"
    else
      log_info "Owner records saved: ${owner_file}"
    fi
    exit 0
  fi

  reconcile_args+=("--env=${ENV_NAME}")
  [[ -n "${CUSTOM_VARS_FILE}" ]] && reconcile_args+=("--vars-file=${CUSTOM_VARS_FILE}")
  [[ -n "${STATE_DIR_OVERRIDE}" ]] && reconcile_args+=("--state-dir=${STATE_DIR_OVERRIDE}")
  reconcile_args+=("${PASSTHROUGH_ARGS[@]}")
  "${reconcile_script}" "${reconcile_args[@]}"
}

main "$@"
