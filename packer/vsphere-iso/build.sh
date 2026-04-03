#!/usr/bin/env bash
# @file build.sh
# @brief Orchestrator for Packer vSphere-ISO builds.
# @description
#   Loads module vars contract, exports PKR_VAR_* automatically, supports
#   temporary credential overrides via CLI/env, and runs init/validate/build
#   for the selected profile.
#
# @arg --profile string Profile name. Supported: oraclelinux-9, ubuntu-24.
# @arg --action string Action: init, validate, or build. Defaults to validate.
# @arg --vars-file string Additional .pkrvars.hcl file (repeatable, relative to cwd or profile dir).
# @arg --vsphere-env-file string Optional env file with vsphere_* keys.
# @arg --packer-bin string Packer binary override (default: packerio, then packer).
# @arg --vsphere-endpoint string Temporary vSphere endpoint override.
# @arg --vsphere-username string Temporary vSphere username override.
# @arg --vsphere-password string Temporary vSphere password override (avoid shell history in shared hosts).
# @arg --build-username string Temporary guest build username override.
# @arg --build-password string Temporary guest build password override.
# @flag --dry-run Print commands without executing.
# @flag --help,-h Show usage.
#
# @example
#   VSPHERE_PASSWORD='CHANGE_ME' ./packer/vsphere-iso/build.sh --vsphere-username=root --action=validate
# @example
#   ./packer/vsphere-iso/build.sh --action=build --vars-file=/tmp/custom.pkrvars.hcl

set -euo pipefail

PROFILE="oraclelinux-9"
ACTION="validate"
PACKER_BIN="${PACKER_BIN:-}"
DRY_RUN="false"
VSPHERE_ENV_FILE="${VSPHERE_ENV_FILE:-}"

VSPHERE_ENDPOINT_OVERRIDE=""
VSPHERE_USERNAME_OVERRIDE=""
VSPHERE_PASSWORD_OVERRIDE=""
BUILD_USERNAME_OVERRIDE=""
BUILD_PASSWORD_OVERRIDE=""

EXTRA_VAR_FILES=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PACKER_WORK_DIR=""
PACKER_TEMPLATE=""
PACKER_DEFAULT_VAR_FILES=()
RESOLVED_PACKER_BIN=""

# shellcheck disable=SC1091
source "${REPO_ROOT}/packer/lib/pkr-vars.sh"

log_info() {
  echo "[INFO] $*"
}

log_warn() {
  echo "[WARN] $*" >&2
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
      --profile=<name>          oraclelinux-9 (default) | ubuntu-24
      --action=<name>           init | validate | build (default: validate)
      --vars-file=<path>        Additional var file (repeatable; cwd or profile dir)
      --vsphere-env-file=<path> Optional env file with vsphere_* values
      --packer-bin=<name>       Packer binary override
      --vsphere-endpoint=<val>  Temporary endpoint override
      --vsphere-username=<val>  Temporary username override
      --vsphere-password=<val>  Temporary password override
      --build-username=<val>    Temporary guest build username override
      --build-password=<val>    Temporary guest build password override
      --dry-run                 Print commands without executing
  -h, --help                    Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile=*)
        PROFILE="${1#*=}"
        shift
        ;;
      --action=*)
        ACTION="${1#*=}"
        shift
        ;;
      --vars-file=*)
        EXTRA_VAR_FILES+=("${1#*=}")
        shift
        ;;
      --vsphere-env-file=*)
        VSPHERE_ENV_FILE="${1#*=}"
        shift
        ;;
      --packer-bin=*)
        PACKER_BIN="${1#*=}"
        shift
        ;;
      --vsphere-endpoint=*)
        VSPHERE_ENDPOINT_OVERRIDE="${1#*=}"
        shift
        ;;
      --vsphere-username=*)
        VSPHERE_USERNAME_OVERRIDE="${1#*=}"
        shift
        ;;
      --vsphere-password=*)
        VSPHERE_PASSWORD_OVERRIDE="${1#*=}"
        shift
        ;;
      --build-username=*)
        BUILD_USERNAME_OVERRIDE="${1#*=}"
        shift
        ;;
      --build-password=*)
        BUILD_PASSWORD_OVERRIDE="${1#*=}"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        die "Unknown argument: $1"
        ;;
    esac
  done
}

resolve_profile() {
  case "${PROFILE}" in
    oraclelinux-9)
      PACKER_WORK_DIR="${SCRIPT_DIR}/oraclelinux/ol9"
      PACKER_TEMPLATE="oraclelinux9.pkr.hcl"
      PACKER_DEFAULT_VAR_FILES=(
        "oraclelinux.auto.pkrvars.hcl"
        "linux-storage.auto.pkrvars.hcl"
      )
      ;;
    ubuntu-24)
      PACKER_WORK_DIR="${SCRIPT_DIR}/ubuntu/24-04-lts"
      PACKER_TEMPLATE="linux-ubuntu.pkr.hcl"
      PACKER_DEFAULT_VAR_FILES=(
        "ubuntu.auto.pkrvars.hcl"
        "linux-storage.auto.pkrvars.hcl"
      )
      ;;
    *)
      die "Unsupported --profile '${PROFILE}'. Supported: oraclelinux-9, ubuntu-24."
      ;;
  esac
}

resolve_packer_bin() {
  if [[ -n "${PACKER_BIN}" ]]; then
    RESOLVED_PACKER_BIN="${PACKER_BIN}"
    return 0
  fi

  if command -v packerio >/dev/null 2>&1; then
    RESOLVED_PACKER_BIN="packerio"
    return 0
  fi
  if command -v packer >/dev/null 2>&1; then
    RESOLVED_PACKER_BIN="packer"
    return 0
  fi

  die "Could not find packer binary. Install 'packerio' or 'packer'."
}

validate_inputs() {
  [[ "${ACTION}" == "init" || "${ACTION}" == "validate" || "${ACTION}" == "build" ]] || {
    die "--action must be init, validate, or build."
  }

  [[ -d "${PACKER_WORK_DIR}" ]] || die "Profile directory not found: ${PACKER_WORK_DIR}"
  [[ -f "${PACKER_WORK_DIR}/${PACKER_TEMPLATE}" ]] || die "Template file not found: ${PACKER_WORK_DIR}/${PACKER_TEMPLATE}"

  local vf
  for vf in "${PACKER_DEFAULT_VAR_FILES[@]}"; do
    local resolved_vf
    resolved_vf="$(resolve_var_file_path "${vf}")"
    [[ -f "${resolved_vf}" ]] || die "Default var file not found: ${resolved_vf}"
  done
  for vf in "${EXTRA_VAR_FILES[@]}"; do
    local resolved_vf
    resolved_vf="$(resolve_var_file_path "${vf}")"
    [[ -f "${resolved_vf}" ]] || die "Extra var file not found: ${resolved_vf}"
  done

  if [[ -n "${VSPHERE_ENV_FILE}" ]]; then
    if [[ "${VSPHERE_ENV_FILE}" != /* ]]; then
      VSPHERE_ENV_FILE="${PWD}/${VSPHERE_ENV_FILE}"
    fi
    [[ -f "${VSPHERE_ENV_FILE}" ]] || die "Env file not found: ${VSPHERE_ENV_FILE}"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

resolve_var_file_path() {
  local vf="$1"

  if [[ "${vf}" = /* ]]; then
    printf '%s\n' "${vf}"
    return 0
  fi

  if [[ -f "${vf}" ]]; then
    printf '%s\n' "${vf}"
    return 0
  fi

  if [[ -n "${PACKER_WORK_DIR}" && -f "${PACKER_WORK_DIR}/${vf}" ]]; then
    printf '%s\n' "${PACKER_WORK_DIR}/${vf}"
    return 0
  fi

  printf '%s\n' "${PWD}/${vf}"
}

load_vsphere_env_file() {
  local line="" key="" value=""
  [[ -n "${VSPHERE_ENV_FILE}" ]] || return 0

  log_info "Loading vSphere env file: ${VSPHERE_ENV_FILE}"
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="$(trim "${line}")"
    [[ -n "${line}" ]] || continue
    [[ "${line}" == *=* ]] || continue

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"

    if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi

    case "${key}" in
      vsphere_endpoint|VSPHERE_ENDPOINT)
        export VSPHERE_ENDPOINT="${value}"
        ;;
      vsphere_username|VSPHERE_USERNAME)
        export VSPHERE_USERNAME="${value}"
        ;;
      vsphere_password|VSPHERE_PASSWORD)
        export VSPHERE_PASSWORD="${value}"
        ;;
      vsphere_insecure_connection|VSPHERE_INSECURE_CONNECTION)
        export VSPHERE_INSECURE_CONNECTION="${value}"
        ;;
      vsphere_datacenter|VSPHERE_DATACENTER)
        export VSPHERE_DATACENTER="${value}"
        ;;
      vsphere_cluster|VSPHERE_CLUSTER)
        export VSPHERE_CLUSTER="${value}"
        ;;
      vsphere_host|VSPHERE_HOST)
        export VSPHERE_HOST="${value}"
        ;;
      vsphere_datastore|VSPHERE_DATASTORE)
        export VSPHERE_DATASTORE="${value}"
        ;;
      vsphere_network|VSPHERE_NETWORK)
        export VSPHERE_NETWORK="${value}"
        ;;
      vsphere_folder|VSPHERE_FOLDER)
        export VSPHERE_FOLDER="${value}"
        ;;
      vsphere_resource_pool|VSPHERE_RESOURCE_POOL)
        export VSPHERE_RESOURCE_POOL="${value}"
        ;;
      vsphere_set_host_for_datastore_uploads|VSPHERE_SET_HOST_FOR_DATASTORE_UPLOADS)
        export VSPHERE_SET_HOST_FOR_DATASTORE_UPLOADS="${value}"
        ;;
    esac
  done <"${VSPHERE_ENV_FILE}"
}

apply_overrides() {
  if [[ -n "${VSPHERE_ENDPOINT_OVERRIDE}" ]]; then
    VSPHERE_ENDPOINT="${VSPHERE_ENDPOINT_OVERRIDE#https://}"
    VSPHERE_ENDPOINT="${VSPHERE_ENDPOINT#http://}"
    VSPHERE_ENDPOINT="${VSPHERE_ENDPOINT%%/}"
    export VSPHERE_ENDPOINT
  fi
  if [[ -n "${VSPHERE_USERNAME_OVERRIDE}" ]]; then
    export VSPHERE_USERNAME="${VSPHERE_USERNAME_OVERRIDE}"
  fi
  if [[ -n "${VSPHERE_PASSWORD_OVERRIDE}" ]]; then
    export VSPHERE_PASSWORD="${VSPHERE_PASSWORD_OVERRIDE}"
  fi
  if [[ -n "${BUILD_USERNAME_OVERRIDE}" ]]; then
    export BUILD_USERNAME="${BUILD_USERNAME_OVERRIDE}"
  fi
  if [[ -n "${BUILD_PASSWORD_OVERRIDE}" ]]; then
    export BUILD_PASSWORD="${BUILD_PASSWORD_OVERRIDE}"
  fi
}

validate_runtime_vars() {
  [[ -n "${VSPHERE_ENDPOINT:-}" ]] || die "VSPHERE_ENDPOINT is empty. Set overlay vars, --vsphere-env-file, or --vsphere-endpoint."
  [[ -n "${VSPHERE_USERNAME:-}" ]] || die "VSPHERE_USERNAME is empty. Set overlay vars, --vsphere-env-file, or --vsphere-username."
  [[ -n "${VSPHERE_PASSWORD:-}" ]] || die "VSPHERE_PASSWORD is empty. Set overlay vars, --vsphere-env-file, env var, or --vsphere-password."
  [[ -n "${BUILD_USERNAME:-}" ]] || die "BUILD_USERNAME is empty. Set overlay vars or --build-username."
  [[ -n "${BUILD_PASSWORD:-}" ]] || {
    die "BUILD_PASSWORD is required for communicator SSH login."
  }
}

ensure_build_password_encrypted() {
  if [[ -n "${BUILD_PASSWORD_ENCRYPTED:-}" ]]; then
    return 0
  fi

  [[ -n "${BUILD_PASSWORD:-}" ]] || {
    die "BUILD_PASSWORD_ENCRYPTED is empty and BUILD_PASSWORD is not set."
  }

  command -v openssl >/dev/null 2>&1 || die "openssl is required to generate BUILD_PASSWORD_ENCRYPTED."
  export BUILD_PASSWORD_ENCRYPTED
  BUILD_PASSWORD_ENCRYPTED="$(openssl passwd -6 "${BUILD_PASSWORD}")"
  log_info "BUILD_PASSWORD_ENCRYPTED was empty; generated from BUILD_PASSWORD."
}

ensure_build_key() {
  local candidate=""

  if [[ -n "${BUILD_KEY:-}" ]]; then
    if [[ -r "${BUILD_KEY}" ]]; then
      BUILD_KEY="$(head -n 1 "${BUILD_KEY}" | tr -d '\r\n')"
      export BUILD_KEY
      log_info "BUILD_KEY provided as file path; loaded public key content from file."
    fi
    return 0
  fi

  for candidate in "${HOME}/.ssh/id_ed25519.pub" "${HOME}/.ssh/id_rsa.pub"; do
    if [[ -r "${candidate}" ]]; then
      BUILD_KEY="$(head -n 1 "${candidate}" | tr -d '\r\n')"
      if [[ -n "${BUILD_KEY}" ]]; then
        export BUILD_KEY
        log_info "BUILD_KEY was empty; using public key from ${candidate}."
        return 0
      fi
    fi
  done

  log_warn "BUILD_KEY is empty and no default public key was found under ~/.ssh; SSH key login may fail on guests."
}

run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

build_var_args() {
  local args=()
  local vf

  for vf in "${PACKER_DEFAULT_VAR_FILES[@]}"; do
    vf="$(resolve_var_file_path "${vf}")"
    args+=("-var-file=${vf}")
  done
  for vf in "${EXTRA_VAR_FILES[@]}"; do
    vf="$(resolve_var_file_path "${vf}")"
    args+=("-var-file=${vf}")
  done

  printf '%s\n' "${args[@]}"
}

sanitize_pkr_env() {
  # Optional numeric vars must be unset when empty; empty string is not a number.
  if [[ -z "${PKR_VAR_communicator_proxy_port:-}" ]]; then
    unset PKR_VAR_communicator_proxy_port
  fi

  # If a specific ISO datastore is not set, reuse primary datastore.
  if [[ -z "${PKR_VAR_common_iso_datastore:-}" ]]; then
    export PKR_VAR_common_iso_datastore="${PKR_VAR_vsphere_datastore:-}"
  fi
}

run_init() {
  (
    cd "${PACKER_WORK_DIR}"
    run_cmd "${RESOLVED_PACKER_BIN}" init .
  )
}

run_validate() {
  local var_args=()
  mapfile -t var_args < <(build_var_args)
  (
    cd "${PACKER_WORK_DIR}"
    run_cmd "${RESOLVED_PACKER_BIN}" validate "${var_args[@]}" .
  )
}

run_build() {
  local var_args=()
  mapfile -t var_args < <(build_var_args)
  (
    cd "${PACKER_WORK_DIR}"
    mkdir -p manifests artifacts
    run_cmd "${RESOLVED_PACKER_BIN}" build "${var_args[@]}" .
  )
}

main() {
  parse_args "$@"
  resolve_profile
  resolve_packer_bin
  validate_inputs

  PKR_EXPORT_SILENT="true"
  pkr_load_module_vars
  load_vsphere_env_file
  apply_overrides
  validate_runtime_vars
  ensure_build_password_encrypted
  ensure_build_key
  pkr_export_vars
  sanitize_pkr_env

  log_info "profile=${PROFILE} action=${ACTION} packer=${RESOLVED_PACKER_BIN}"
  log_info "endpoint=${VSPHERE_ENDPOINT} user=${VSPHERE_USERNAME:-<unset>}"
  log_info "template=${PACKER_WORK_DIR}/${PACKER_TEMPLATE}"

  run_init
  case "${ACTION}" in
    init)
      ;;
    validate)
      run_validate
      ;;
    build)
      run_validate
      run_build
      ;;
  esac
}

main "$@"
