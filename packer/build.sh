#!/usr/bin/env bash
# @file build.sh
# @brief Unified image build entrypoint for the packer module.
# @description
#   Dispatches build requests to either the vsphere-iso or vmware-iso modules.
#
# @arg --target string Build backend: vsphere-iso or vmware-iso. Defaults to vsphere-iso.
# @arg --profile string Profile name. For vsphere-iso: oraclelinux-9|ubuntu-24. For vmware-iso this is mapped to --os.
# @arg --os string VMware-ISO target OS: ubuntu|oraclelinux|all. Overrides --profile mapping in vmware-iso mode.
# @arg --action string Action: init|validate|build. Defaults to validate.
# @arg --env string Overlay env for vsphere-iso. Defaults to lab.
# @arg --vars-file string Extra var file (repeatable).
# @arg --packer-bin string Optional packer binary override.
# @flag --dry-run Print commands without executing.
# @flag --help,-h Show usage.
#
# @example
#   ./packer/build.sh --target=vsphere-iso --profile=ubuntu-24 --env=lab --action=validate
# @example
#   ./packer/build.sh --target=vmware-iso --os=all --action=validate

set -euo pipefail

TARGET="vsphere-iso"
PROFILE=""
TARGET_OS=""
ACTION="validate"
ENV_NAME="lab"
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
  --profile=<name>      oraclelinux-9 | ubuntu-24
  --os=<name>           ubuntu | oraclelinux | all (vmware-iso only)
  --action=<name>       init | validate | build (default: validate)
  --env=<name>          Overlay env (vsphere-iso only, default: lab)
  --vars-file=<path>    Extra var file (repeatable)
  --packer-bin=<name>   Optional packer binary override
  --dry-run             Print commands without executing
  -h, --help            Show this help

Examples:
  # Validate Ubuntu profile on vSphere/ESXi
  ./packer/build.sh --target=vsphere-iso --profile=ubuntu-24 --env=lab --action=validate

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
      --action=*)
        ACTION="${1#*=}"
        shift
        ;;
      --env=*)
        ENV_NAME="${1#*=}"
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

run_vsphere_iso() {
  local profile="${PROFILE:-oraclelinux-9}"
  local cmd=(
    "${VSPHERE_ENTRYPOINT}"
    "--profile=${profile}"
    "--action=${ACTION}"
    "--env=${ENV_NAME}"
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

run_vmware_iso() {
  local os_name="${TARGET_OS}"
  if [[ -z "${os_name}" ]]; then
    os_name="$(map_profile_to_os "${PROFILE}")"
  fi
  [[ -n "${os_name}" ]] || os_name="all"

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

