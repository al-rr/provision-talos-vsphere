#!/usr/bin/env bash
# @file build.sh
# @brief Unified image build entrypoint for the packer module.
# @description
#   Dispatches image builds by builder type. Current implementation supports
#   only vsphere-iso.
#
# @arg --builder string Builder backend. Default: vsphere-iso.
# @arg --profile string Legacy profile selector (for compatibility): oraclelinux-9|ubuntu-24.
# @arg --os string Target OS selector: ubuntu|oraclelinux.
# @arg --version string Target OS version selector (for example: 24, 9, 8).
# @arg --action string Action: init|validate|build. Defaults to validate.
# @arg --vars-file string Extra var file (repeatable).
# @arg --vsphere-env-file string Optional env file with vsphere_* keys.
# @arg --vsphere-endpoint string Temporary vSphere endpoint override.
# @arg --vsphere-username string Temporary vSphere username override.
# @arg --vsphere-password string Temporary vSphere password override.
# @arg --build-username string Temporary guest build username override.
# @arg --build-password string Temporary guest build password override.
# @arg --packer-bin string Optional packer binary override.
# @flag --dry-run Print commands without executing.
# @flag --help,-h Show usage.
#
# @example
#   ./packer/build.sh --builder=vsphere-iso --os=ubuntu --version=24 --action=validate
# @example
#   ./packer/build.sh --os=oraclelinux --version=9 --action=build
# @example
#   ./packer/build.sh --os=ubuntu --version=24 --action=init

set -euo pipefail

BUILDER="vsphere-iso"
PROFILE=""
TARGET_OS=""
TARGET_VERSION=""
ACTION="validate"
PACKER_BIN="${PACKER_BIN:-}"
DRY_RUN="false"
EXTRA_VAR_FILES=()
FORWARD_ARGS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSPHERE_ENTRYPOINT="${SCRIPT_DIR}/vsphere-iso/build.sh"

usage() {
  cat <<'EOF'
Usage: ./packer/build.sh [options]

Description:
  Unified Packer dispatcher. Current builder support: vsphere-iso.

Options:
  --builder=<name>      vsphere-iso (default: vsphere-iso)
  --profile=<name>      Legacy profile selector: oraclelinux-9 | ubuntu-24
  --os=<name>           ubuntu | oraclelinux
  --version=<value>     OS version selector (example: 24, 9, 8)
  --action=<name>       init | validate | build (default: validate)
  --vars-file=<path>    Extra var file (repeatable)
  --vsphere-env-file    Optional env file with vsphere_* keys
  --vsphere-endpoint    Temporary vSphere endpoint override
  --vsphere-username    Temporary vSphere username override
  --vsphere-password    Temporary vSphere password override
  --build-username      Temporary guest build username override
  --build-password      Temporary guest build password override
  --packer-bin=<name>   Optional packer binary override
  --dry-run             Print commands without executing
  -h, --help            Show this help

Examples:
  # Initialize plugins/modules for Ubuntu 24 template
  ./packer/build.sh --os=ubuntu --version=24 --action=init

  # Validate Ubuntu 24 using vsphere-iso
  ./packer/build.sh --builder=vsphere-iso --os=ubuntu --version=24 --action=validate

  # Build Oracle Linux 9 using default builder
  ./packer/build.sh --os=oraclelinux --version=9 --action=build
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --builder=*)
        BUILDER="${1#*=}"
        shift
        ;;
      --profile=*)
        PROFILE="${1#*=}"
        shift
        ;;
      --os=*)
        TARGET_OS="${1#*=}"
        shift
        ;;
      --version=*)
        TARGET_VERSION="${1#*=}"
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
      --vsphere-env-file=*|--vsphere-endpoint=*|--vsphere-username=*|--vsphere-password=*|--build-username=*|--build-password=*)
        FORWARD_ARGS+=("${1}")
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

resolve_vsphere_profile() {
  if [[ -n "${PROFILE}" ]]; then
    printf '%s\n' "${PROFILE}"
    return 0
  fi

  case "${TARGET_OS}:${TARGET_VERSION}" in
    ubuntu:24)
      printf '%s\n' "ubuntu-24"
      return 0
      ;;
    oraclelinux:9)
      printf '%s\n' "oraclelinux-9"
      return 0
      ;;
    oraclelinux:8)
      echo "[ERROR] oraclelinux/8 is not implemented yet for vsphere-iso." >&2
      echo "[ERROR] Current supported selector: --os=oraclelinux --version=9" >&2
      exit 1
      ;;
    :|:*)
      printf '%s\n' "oraclelinux-9"
      return 0
      ;;
    *)
      echo "[ERROR] Unsupported selector --os=${TARGET_OS} --version=${TARGET_VERSION}" >&2
      echo "[ERROR] Supported combinations: ubuntu/24, oraclelinux/9" >&2
      exit 1
      ;;
  esac
}

run_vsphere_iso() {
  local profile
  profile="$(resolve_vsphere_profile)"
  local cmd=(
    "${VSPHERE_ENTRYPOINT}"
    "--profile=${profile}"
    "--action=${ACTION}"
  )
  local vf
  for vf in "${EXTRA_VAR_FILES[@]}"; do
    cmd+=("--vars-file=${vf}")
  done
  cmd+=("${FORWARD_ARGS[@]}")
  [[ -n "${PACKER_BIN}" ]] && cmd+=("--packer-bin=${PACKER_BIN}")
  [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
  exec "${cmd[@]}"
}

main() {
  parse_args "$@"

  case "${BUILDER}" in
    vsphere-iso)
      [[ -x "${VSPHERE_ENTRYPOINT}" ]] || { echo "[ERROR] Missing ${VSPHERE_ENTRYPOINT}" >&2; exit 1; }
      run_vsphere_iso
      ;;
    *)
      echo "[ERROR] Unsupported --builder '${BUILDER}'." >&2
      echo "[ERROR] Current supported builder: vsphere-iso" >&2
      exit 1
      ;;
  esac
}

main "$@"
