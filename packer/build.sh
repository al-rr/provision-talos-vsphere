#!/usr/bin/env bash
# @file build.sh
# @brief Unified image build entrypoint for the packer module.
# @description
#   Dispatches build requests to either the vsphere-iso or vmware-iso modules.
#
# @arg --target string Build backend: vsphere-iso or vmware-iso. Defaults to vsphere-iso.
# @arg --profile string Legacy profile selector (for compatibility): oraclelinux-9|ubuntu-24.
# @arg --os string Target OS selector: ubuntu|oraclelinux|all.
# @arg --version string Target OS version selector (for example: 24, 9, 8).
# @arg --action string Action: init|validate|build. Defaults to validate.
# @arg --vars-file string Extra var file (repeatable).
# @arg --packer-bin string Optional packer binary override.
# @flag --dry-run Print commands without executing.
# @flag --help,-h Show usage.
#
# @example
#   ./packer/build.sh --target=vsphere-iso --os=ubuntu --version=24 --action=validate
# @example
#   ./packer/build.sh --target=vmware-iso --os=all --action=validate

set -euo pipefail

TARGET="vsphere-iso"
PROFILE=""
TARGET_OS=""
TARGET_VERSION=""
ACTION="validate"
PACKER_BIN="${PACKER_BIN:-}"
DRY_RUN="false"
EXTRA_VAR_FILES=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSPHERE_ENTRYPOINT="${SCRIPT_DIR}/vsphere-iso/build.sh"
VMWARE_ENTRYPOINT="${SCRIPT_DIR}/vmware-iso/build.sh"

usage() {
  cat <<'EOF'
Usage: ./packer/build.sh [options]

Description:
  Unified Packer dispatcher for vsphere-iso and vmware-iso modules.

Options:
  --target=<name>       vsphere-iso | vmware-iso (default: vsphere-iso)
  --profile=<name>      Legacy profile selector: oraclelinux-9 | ubuntu-24
  --os=<name>           ubuntu | oraclelinux | all
  --version=<value>     OS version selector (example: 24, 9, 8)
  --action=<name>       init | validate | build (default: validate)
  --vars-file=<path>    Extra var file (repeatable)
  --packer-bin=<name>   Optional packer binary override
  --dry-run             Print commands without executing
  -h, --help            Show this help

Examples:
  # Validate Ubuntu profile on vSphere/ESXi
  ./packer/build.sh --target=vsphere-iso --os=ubuntu --version=24 --action=validate

  # Validate all vmware-iso profiles locally
  ./packer/build.sh --target=vmware-iso --os=all --action=validate
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target=*)
        TARGET="${1#*=}"
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
      echo "[ERROR] oraclelinux/8 is defined in the canonical layout scaffold, but the vsphere template is not implemented yet." >&2
      echo "[ERROR] Current supported selector: --os=oraclelinux --version=9" >&2
      exit 1
      ;;
    :|:*)
      printf '%s\n' "oraclelinux-9"
      return 0
      ;;
    *)
      echo "[ERROR] Unsupported vsphere selector --os=${TARGET_OS} --version=${TARGET_VERSION}" >&2
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
  [[ -n "${PACKER_BIN}" ]] && cmd+=("--packer-bin=${PACKER_BIN}")
  [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
  exec "${cmd[@]}"
}

map_profile_to_os() {
  case "$1" in
    ubuntu-24)
      echo "ubuntu"
      ;;
    oraclelinux-9)
      echo "oraclelinux"
      ;;
    all)
      echo "all"
      ;;
    *)
      echo ""
      ;;
  esac
}

resolve_vmware_os() {
  if [[ -n "${TARGET_OS}" ]]; then
    printf '%s\n' "${TARGET_OS}"
    return 0
  fi
  printf '%s\n' "$(map_profile_to_os "${PROFILE}")"
}

run_vmware_iso() {
  local os_name
  os_name="$(resolve_vmware_os)"
  [[ -n "${os_name}" ]] || os_name="all"

  if [[ -n "${TARGET_VERSION}" ]]; then
    case "${os_name}:${TARGET_VERSION}" in
      ubuntu:24|oraclelinux:9|all:*)
        ;;
      oraclelinux:8)
        echo "[ERROR] oraclelinux/8 is scaffolded in canonical layout but vmware-iso template is not implemented yet." >&2
        echo "[ERROR] Current supported selector: --os=oraclelinux --version=9" >&2
        exit 1
        ;;
      *)
        echo "[ERROR] Unsupported vmware selector --os=${os_name} --version=${TARGET_VERSION}" >&2
        exit 1
        ;;
    esac
  fi

  local cmd=(
    "${VMWARE_ENTRYPOINT}"
    "--os=${os_name}"
    "--action=${ACTION}"
  )
  local vf
  for vf in "${EXTRA_VAR_FILES[@]}"; do
    cmd+=("--vars-file=${vf}")
  done
  [[ -n "${PACKER_BIN}" ]] && cmd+=("--packer-bin=${PACKER_BIN}")
  [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
  exec "${cmd[@]}"
}

main() {
  parse_args "$@"
  case "${TARGET}" in
    vsphere-iso)
      [[ -x "${VSPHERE_ENTRYPOINT}" ]] || { echo "[ERROR] Missing ${VSPHERE_ENTRYPOINT}" >&2; exit 1; }
      run_vsphere_iso
      ;;
    vmware-iso)
      [[ -x "${VMWARE_ENTRYPOINT}" ]] || { echo "[ERROR] Missing ${VMWARE_ENTRYPOINT}" >&2; exit 1; }
      run_vmware_iso
      ;;
    *)
      echo "[ERROR] --target must be vsphere-iso or vmware-iso." >&2
      exit 1
      ;;
  esac
}

main "$@"

