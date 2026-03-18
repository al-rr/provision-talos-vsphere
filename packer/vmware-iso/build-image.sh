#!/usr/bin/env bash
# @file build-image.sh
# @brief Generic Packer runner for vmware-iso images (Ubuntu and Oracle Linux).
# @description
#   Initializes, validates, or builds vmware-iso templates using a unified CLI.
#   Supports profile-based defaults and optional extra var files.
#
# @arg --profile string Build profile: ubuntu-24, oraclelinux-9, or custom.
# @arg --action string Action: init, validate, or build. Defaults to build.
# @arg --vars-file string Additional pkrvars file (repeatable).
# @arg --work-dir string Custom profile directory (required when profile=custom).
# @arg --template string Override template file.
# @arg --default-var-file string Override default var file.
# @arg --packer-bin string Packer binary to use. Defaults to packerio or packer.
# @flag --dry-run Print commands without executing.
# @flag --help,-h Show usage information.
#
# @example
#   ./packer/vmware-iso/build-image.sh --profile=ubuntu-24 --action=validate
# @example
#   ./packer/vmware-iso/build-image.sh --profile=oraclelinux-9 --vars-file=/tmp/custom.pkrvars.hcl --action=build
# @example
#   ./packer/vmware-iso/build-image.sh --profile=custom --work-dir=./packer/vsphere-iso/oraclelinux/ol9 --template=oraclelinux9.pkr.hcl --default-var-file=oraclelinux.auto.pkrvars.hcl --action=build

set -euo pipefail

PROFILE=""
ACTION="build"
PACKER_BIN="${PACKER_BIN:-}"
CUSTOM_WORK_DIR=""
TEMPLATE_FILE=""
DEFAULT_VAR_FILE=""
DRY_RUN="false"

EXTRA_VAR_FILES=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR=""
RESOLVED_TEMPLATE=""
RESOLVED_DEFAULT_VARS=""
RESOLVED_PACKER_BIN=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
      --profile=<name>           Build profile: ubuntu-24 | oraclelinux-9 | custom
      --action=<name>            init | validate | build (default: build)
      --vars-file=<path>         Additional var file (repeatable)
      --work-dir=<path>          Custom profile dir (required for profile=custom)
      --template=<file>          Override template file
      --default-var-file=<file>  Override default profile var file
      --packer-bin=<name>        Packer binary (default: packerio or packer)
      --dry-run                  Print commands without executing
  -h, --help                     Show this help
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
      --work-dir=*)
        CUSTOM_WORK_DIR="${1#*=}"
        shift
        ;;
      --template=*)
        TEMPLATE_FILE="${1#*=}"
        shift
        ;;
      --default-var-file=*)
        DEFAULT_VAR_FILE="${1#*=}"
        shift
        ;;
      --packer-bin=*)
        PACKER_BIN="${1#*=}"
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
        echo "[ERROR] Unknown argument: $1" >&2
        exit 1
        ;;
    esac
  done
}

resolve_profile() {
  case "${PROFILE}" in
    ubuntu-24)
      WORK_DIR="${SCRIPT_DIR}/ubuntu/24"
      RESOLVED_TEMPLATE="${TEMPLATE_FILE:-ubuntu24.pkr.hcl}"
      RESOLVED_DEFAULT_VARS="${DEFAULT_VAR_FILE:-ubuntu.auto.pkrvars.hcl}"
      ;;
    oraclelinux-9)
      WORK_DIR="${SCRIPT_DIR}/oraclelinux/ol9"
      RESOLVED_TEMPLATE="${TEMPLATE_FILE:-build.oraclelinux9.pkr.hcl}"
      RESOLVED_DEFAULT_VARS="${DEFAULT_VAR_FILE:-oraclelinux.auto.pkrvars.hcl}"
      ;;
    custom)
      [[ -n "${CUSTOM_WORK_DIR}" ]] || {
        echo "[ERROR] --work-dir is required when --profile=custom." >&2
        exit 1
      }
      if [[ "${CUSTOM_WORK_DIR}" != /* ]]; then
        WORK_DIR="${PWD}/${CUSTOM_WORK_DIR}"
      else
        WORK_DIR="${CUSTOM_WORK_DIR}"
      fi
      RESOLVED_TEMPLATE="${TEMPLATE_FILE}"
      RESOLVED_DEFAULT_VARS="${DEFAULT_VAR_FILE}"
      ;;
    *)
      echo "[ERROR] Invalid --profile '${PROFILE}'. Use ubuntu-24, oraclelinux-9, or custom." >&2
      exit 1
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

  echo "[ERROR] Could not find packer binary. Install 'packerio' or 'packer'." >&2
  exit 1
}

validate_inputs() {
  [[ -n "${PROFILE}" ]] || { echo "[ERROR] --profile is required." >&2; exit 1; }
  [[ "${ACTION}" == "init" || "${ACTION}" == "validate" || "${ACTION}" == "build" ]] || {
    echo "[ERROR] --action must be init, validate, or build." >&2
    exit 1
  }

  [[ -d "${WORK_DIR}" ]] || { echo "[ERROR] Profile directory not found: ${WORK_DIR}" >&2; exit 1; }
  [[ -n "${RESOLVED_TEMPLATE}" ]] || { echo "[ERROR] --template is required for this profile." >&2; exit 1; }
  [[ -f "${WORK_DIR}/${RESOLVED_TEMPLATE}" ]] || { echo "[ERROR] Template file not found: ${WORK_DIR}/${RESOLVED_TEMPLATE}" >&2; exit 1; }
  if [[ -n "${RESOLVED_DEFAULT_VARS}" ]]; then
    [[ -f "${WORK_DIR}/${RESOLVED_DEFAULT_VARS}" ]] || { echo "[ERROR] Default var file not found: ${WORK_DIR}/${RESOLVED_DEFAULT_VARS}" >&2; exit 1; }
  fi

  local vf
  for vf in "${EXTRA_VAR_FILES[@]}"; do
    if [[ "${vf}" != /* ]]; then
      vf="${PWD}/${vf}"
    fi
    [[ -f "${vf}" ]] || { echo "[ERROR] Extra var file not found: ${vf}" >&2; exit 1; }
  done
}

run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

build_var_args() {
  local vf
  local args=()

  if [[ -n "${RESOLVED_DEFAULT_VARS}" ]]; then
    args+=("-var-file=${RESOLVED_DEFAULT_VARS}")
  fi

  for vf in "${EXTRA_VAR_FILES[@]}"; do
    if [[ "${vf}" != /* ]]; then
      vf="${PWD}/${vf}"
    fi
    args+=("-var-file=${vf}")
  done

  printf '%s\n' "${args[@]}"
}

run_init() {
  (
    cd "${WORK_DIR}"
    run_cmd "${RESOLVED_PACKER_BIN}" init .
  )
}

run_validate() {
  local var_args=()
  mapfile -t var_args < <(build_var_args)
  (
    cd "${WORK_DIR}"
    run_cmd "${RESOLVED_PACKER_BIN}" validate "${var_args[@]}" .
  )
}

run_build() {
  local var_args=()
  mapfile -t var_args < <(build_var_args)
  (
    cd "${WORK_DIR}"
    run_cmd "${RESOLVED_PACKER_BIN}" build "${var_args[@]}" .
  )
}

main() {
  parse_args "$@"
  resolve_profile
  resolve_packer_bin
  validate_inputs

  echo "[INFO] profile=${PROFILE} action=${ACTION} packer=${RESOLVED_PACKER_BIN}"
  echo "[INFO] template=${WORK_DIR}/${RESOLVED_TEMPLATE}"
  echo "[INFO] vars=${WORK_DIR}/${RESOLVED_DEFAULT_VARS}"

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
