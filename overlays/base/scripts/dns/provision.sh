#!/usr/bin/env bash
# @file provision.sh
# @brief Provision DNS VM(s) on vSphere/ESXi using GOVC defaults.
# @description
#   Thin wrapper over the generic GOVC provisioner with DNS-focused defaults.
#   Supports create, destroy, and plan actions.
#
# @arg action string Required action: create, destroy, or plan.
# @arg --env,-e string Overlay environment. Defaults to lab.
# @arg --vars-file string Optional vars file with overrides.
# @flag --help,-h Show usage.
#
# @example
#   ./overlays/base/scripts/dns/provision.sh --env=lab create
# @example
#   ./overlays/base/scripts/dns/provision.sh --env=lab --vars-file=overlays/base/scripts/govc/vars-esxi-prod.sh plan

set -euo pipefail

ENV_NAME="lab"
CUSTOM_VARS_FILE=""
ACTION=""
PASS_THROUGH_ARGS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SCRIPT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BASE_SCRIPT_DIR}/../../.." && pwd)"

# shellcheck disable=SC1091
source "${BASE_SCRIPT_DIR}/functions.sh"

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options] <create|destroy|plan> [extra govc args]

Options:
  -e, --env=<env>          Overlay environment (default: lab)
      --vars-file=<path>   Optional vars override file
  -h, --help               Show help
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--env)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        ENV_NAME="$2"
        shift 2
        ;;
      --env=*)
        ENV_NAME="${1#*=}"
        shift
        ;;
      --vars-file=*)
        CUSTOM_VARS_FILE="${1#*=}"
        shift
        ;;
      create|destroy|plan)
        ACTION="$1"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        PASS_THROUGH_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

validate_args() {
  [[ -n "${ACTION}" ]] || die "Action is required: create, destroy, or plan."
  [[ -n "${ENV_NAME}" ]] || die "--env cannot be empty."
}

load_context() {
  load_overlay_vars "${ENV_NAME}"
  export_common_tool_env

  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    if [[ "${CUSTOM_VARS_FILE}" != /* ]]; then
      CUSTOM_VARS_FILE="${REPO_ROOT}/${CUSTOM_VARS_FILE}"
    fi
    require_file "${CUSTOM_VARS_FILE}"
    # shellcheck disable=SC1090
    source "${CUSTOM_VARS_FILE}"
  fi
}

apply_dns_defaults_to_govc() {
  export GOVC_VM_COUNT="${DNS_VM_COUNT:-1}"
  export GOVC_VM_NAME_PREFIX="${DNS_VM_NAME_PREFIX:-talos-dns}"
  export GOVC_VM_START_INDEX="${DNS_VM_START_INDEX:-1}"
  export GOVC_VM_TEMPLATE_NAME="${DNS_VM_TEMPLATE_NAME:-${GOVC_VM_TEMPLATE_NAME:-}}"
  export GOVC_VM_OVA_PATH="${DNS_VM_OVA_PATH:-${GOVC_VM_OVA_PATH:-}}"
  export GOVC_VM_OVF_PATH="${DNS_VM_OVF_PATH:-${GOVC_VM_OVF_PATH:-}}"
  export GOVC_VM_CPUS="${DNS_VM_CPUS:-1}"
  export GOVC_VM_MEMORY_MB="${DNS_VM_MEMORY_MB:-1024}"
  export GOVC_VM_DISK_GB="${DNS_VM_DISK_GB:-20}"
  export GOVC_VM_NETMASK_PREFIX="${DNS_VM_NETMASK_PREFIX:-24}"
  export GOVC_VM_STATIC_INTERFACE="${DNS_VM_STATIC_INTERFACE:-ens160}"
  export GOVC_VM_GATEWAY="${DNS_VM_GATEWAY:-${TALOS_GATEWAY:-}}"
  export GOVC_VM_NAMESERVERS="${DNS_VM_BOOTSTRAP_NAMESERVERS:-1.1.1.1,8.8.8.8}"
  export GOVC_VM_GUEST_USERNAME="${DNS_VM_GUEST_USERNAME:-${GOVC_VM_GUEST_USERNAME:-}}"
  export GOVC_VM_GUEST_PASSWORD="${DNS_VM_GUEST_PASSWORD:-${GOVC_VM_GUEST_PASSWORD:-}}"
  export GOVC_VM_ENFORCE_GUEST_STATIC_NETWORK="${DNS_VM_GUEST_STATIC:-auto}"

  if [[ -n "${DNS_VM_STATIC_IP:-}" ]]; then
    export GOVC_VM_STATIC_IPS="${DNS_VM_STATIC_IP}"
  fi
}

main() {
  local -a cmd=()

  parse_args "$@"
  validate_args
  load_context
  apply_dns_defaults_to_govc

  cmd=("${BASE_SCRIPT_DIR}/govc/provision_haproxy.sh" "--env=${ENV_NAME}")
  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    cmd+=("--vars-file=${CUSTOM_VARS_FILE}")
  fi
  cmd+=("${PASS_THROUGH_ARGS[@]}")
  cmd+=("${ACTION}")

  exec "${cmd[@]}"
}

main "$@"
