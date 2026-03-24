#!/usr/bin/env bash
# @file build.sh
# @brief Orchestrator for vmware-iso Packer profiles.
# @description
#   Runs init/validate/build for one or multiple operating system profiles
#   using a single command.
#
# @arg --os string Target OS: ubuntu, oraclelinux, or all. Defaults to all.
# @arg --action string Action: init, validate, or build. Defaults to validate.
# @arg --packer-bin string Optional packer binary override.
# @arg --vars-file string Extra var file passed to each selected profile (repeatable).
# @flag --dry-run Print commands without executing.
# @flag --help,-h Show usage information.
#
# @example
#   ./packer/vmware-iso/build.sh --os=all --action=validate
# @example
#   ./packer/vmware-iso/build.sh --os=oraclelinux --action=build --vars-file=/tmp/common.pkrvars.hcl

set -euo pipefail

TARGET_OS="all"
ACTION="validate"
PACKER_BIN="${PACKER_BIN:-}"
DRY_RUN="false"

EXTRA_VAR_FILES=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/build-image.sh"

log_info() {
  echo "[INFO] $*"
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
      --os=<name>          ubuntu | oraclelinux | all (default: all)
      --action=<name>      init | validate | build (default: validate)
      --packer-bin=<name>  Override packer binary (packer or packerio)
      --vars-file=<path>   Extra var file passed to each profile (repeatable)
      --dry-run            Print commands without executing
  -h, --help               Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --os=*)
        TARGET_OS="${1#*=}"
        shift
        ;;
      --action=*)
        ACTION="${1#*=}"
        shift
        ;;
      --packer-bin=*)
        PACKER_BIN="${1#*=}"
        shift
        ;;
      --vars-file=*)
        EXTRA_VAR_FILES+=("${1#*=}")
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

validate_args() {
  [[ -x "${RUNNER}" ]] || die "Runner not found or not executable: ${RUNNER}"
  [[ "${ACTION}" == "init" || "${ACTION}" == "validate" || "${ACTION}" == "build" ]] || {
    die "--action must be init, validate, or build."
  }
  [[ "${TARGET_OS}" == "ubuntu" || "${TARGET_OS}" == "oraclelinux" || "${TARGET_OS}" == "all" ]] || {
    die "--os must be ubuntu, oraclelinux, or all."
  }
}

profile_for_os() {
  local os_name="$1"
  case "${os_name}" in
    ubuntu)
      echo "ubuntu-24"
      ;;
    oraclelinux)
      echo "oraclelinux-9"
      ;;
    *)
      die "Unsupported os mapping: ${os_name}"
      ;;
  esac
}

build_runner_args() {
  local profile="$1"
  local args=("--profile=${profile}" "--action=${ACTION}")
  local vf

  if [[ -n "${PACKER_BIN}" ]]; then
    args+=("--packer-bin=${PACKER_BIN}")
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    args+=("--dry-run")
  fi

  for vf in "${EXTRA_VAR_FILES[@]}"; do
    args+=("--vars-file=${vf}")
  done

  printf '%s\n' "${args[@]}"
}

run_profile() {
  local os_name="$1"
  local profile=""
  local args=()

  profile="$(profile_for_os "${os_name}")"
  mapfile -t args < <(build_runner_args "${profile}")

  log_info "Running ${ACTION} for ${os_name} (${profile})"
  "${RUNNER}" "${args[@]}"
}

main() {
  parse_args "$@"
  validate_args

  if [[ "${TARGET_OS}" == "all" ]]; then
    run_profile "oraclelinux"
    run_profile "ubuntu"
  else
    run_profile "${TARGET_OS}"
  fi
}

main "$@"
