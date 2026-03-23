#!/usr/bin/env bash
set -euo pipefail

# @file provision.sh
# @brief VMware GOVC provisioner for DNS-owned VM workflows.
# @description
#   Creates or destroys virtual machines using GOVC. In create mode, it can deploy
#   from an OVA/OVF artifact, clone from a source VM/template, or create an empty VM,
#   depending on --mode.
#   The script provisions VMs for the DNS module using VMware GOVC.
#
# @arg action string Required action: create, destroy, or plan.
# @arg --env,-e string Overlay environment to load. Defaults to lab.
# @arg --vars-file string Optional shell vars file with overrides.
# @arg --count int Number of guests to process.
# @arg --prefix string Prefix for VM names (suffix -<index> is appended).
# @arg --start-index int First numeric suffix for generated names.
# @arg --template string Source template/VM name for clone operations.
# @arg --ova-path string OVA artifact path or directory.
# @arg --ovf-path string OVF artifact path or directory.
# @arg --mode string Provision mode: auto (default), ova, ovf, clone, or empty.
# @arg --cpu int VM vCPU count.
# @arg --memory-mb int VM memory in MiB.
# @arg --disk-gb int Primary disk size in GiB.
# @arg --disk-name string Primary disk device name. Default disk-1000-0.
# @arg --network string Portgroup/network name.
# @arg --folder string vSphere folder path.
# @arg --resource-pool string vSphere resource pool path.
# @arg --datastore string Datastore name.
# @flag --power-on Power on guests after create (default true).
# @flag --no-power-on Do not power on after create.
# @flag --overwrite Destroy existing VM with same name before create.
# @flag --help,-h Show usage.
#
# @example
#   ./overlays/base/scripts/dns/govc/provision.sh --env=lab --count=1 --prefix=talos-dns --template=ubuntu-template create
# @example
#   ./overlays/base/scripts/dns/govc/provision.sh --env=lab --count=1 --prefix=talos-dns destroy

ENV_NAME="lab"
ACTION=""
CUSTOM_VARS_FILE=""
SELECTED_VARS_FILE=""
SHOW_VALUES="false"
VM_COUNT=""
VM_PREFIX=""
VM_START_INDEX=""
VM_TEMPLATE_NAME=""
VM_OVA_PATH=""
VM_OVF_PATH=""
VM_MODE="auto"
VM_CREATE_STRATEGY=""
VM_AUTO_FALLBACK_EMPTY=""
VM_SOURCE_KIND=""
VM_SOURCE_PATH=""
VM_CPUS=""
VM_MEMORY_MB=""
VM_DISK_GB=""
VM_DISK_NAME=""
VM_NETWORK=""
VM_FOLDER=""
VM_RESOURCE_POOL=""
VM_DATASTORE=""
VM_GUEST_OS_TYPE=""
VM_FIRMWARE=""
VM_NET_ADAPTER=""
VM_DISK_CONTROLLER=""
VM_POWER_ON=""
VM_POWER_ON_EXPLICIT="false"
VM_OVERWRITE=""
VM_STATIC_IPS=""
VM_GATEWAY=""
VM_NETMASK_PREFIX=""
VM_NAMESERVERS=""
VM_STATIC_INTERFACE=""
VM_GUEST_USERNAME=""
VM_GUEST_PASSWORD=""
VM_ENFORCE_GUEST_STATIC_NETWORK=""
VM_APPLY_GUEST_STATIC_NETWORK="false"
VM_CLOUDINIT_PUBLIC_KEY=""
VM_CLOUDINIT_PASSWORD=""

declare -a VM_STATIC_IP_ARRAY=()
declare -a VM_NAMESERVER_ARRAY=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options] <create|destroy|plan>

Options:
  -e, --env=<env>              Overlay environment (default: lab)
      --vars-file=<path>       Optional shell file with overrides
      --count=<n>              Number of VMs
      --prefix=<name>          VM name prefix
      --start-index=<n>        Starting VM index (default 1)
      --template=<name>        Source template/VM for clone
      --mode=<name>            auto | ova | ovf | clone | empty (default: auto)
      --cpu=<n>                VM CPUs
      --memory-mb=<n>          VM memory in MiB
      --disk-gb=<n>            VM disk size in GiB
      --disk-name=<name>       VM disk name (default disk-1000-0)
      --ova-path=<path>        OVA artifact file or directory
      --ovf-path=<path>        OVF artifact file or directory
      --network=<name>         Network/portgroup
      --folder=<path>          VM folder
      --resource-pool=<path>   Resource pool
      --datastore=<name>       Datastore
      --guest-user=<name>      Guest OS username for in-guest static network enforcement
      --guest-pass=<pass>      Guest OS password for in-guest static network enforcement
      --guest-static=<mode>    auto | true | false (default: auto)
      --power-on               Power on after create
      --no-power-on            Do not power on after create
      --overwrite              Destroy VM with same name before create
      --auto-fallback-empty    In mode=auto, fallback to empty VM if all sources fail
      --no-auto-fallback-empty In mode=auto, do not fallback to empty (default)
      --show-values            Print selected project vars and resolved values, then exit
  -h, --help                   Show this help
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
      --count=*)
        VM_COUNT="${1#*=}"
        shift
        ;;
      --prefix=*)
        VM_PREFIX="${1#*=}"
        shift
        ;;
      --start-index=*)
        VM_START_INDEX="${1#*=}"
        shift
        ;;
      --template=*)
        VM_TEMPLATE_NAME="${1#*=}"
        shift
        ;;
      --ova-path=*)
        VM_OVA_PATH="${1#*=}"
        shift
        ;;
      --ovf-path=*)
        VM_OVF_PATH="${1#*=}"
        shift
        ;;
      --mode=*)
        VM_MODE="${1#*=}"
        shift
        ;;
      --cpu=*)
        VM_CPUS="${1#*=}"
        shift
        ;;
      --memory-mb=*)
        VM_MEMORY_MB="${1#*=}"
        shift
        ;;
      --disk-gb=*)
        VM_DISK_GB="${1#*=}"
        shift
        ;;
      --disk-name=*)
        VM_DISK_NAME="${1#*=}"
        shift
        ;;
      --network=*)
        VM_NETWORK="${1#*=}"
        shift
        ;;
      --folder=*)
        VM_FOLDER="${1#*=}"
        shift
        ;;
      --resource-pool=*)
        VM_RESOURCE_POOL="${1#*=}"
        shift
        ;;
      --datastore=*)
        VM_DATASTORE="${1#*=}"
        shift
        ;;
      --guest-user=*)
        VM_GUEST_USERNAME="${1#*=}"
        shift
        ;;
      --guest-pass=*)
        VM_GUEST_PASSWORD="${1#*=}"
        shift
        ;;
      --guest-static=*)
        VM_ENFORCE_GUEST_STATIC_NETWORK="${1#*=}"
        shift
        ;;
      --power-on)
        VM_POWER_ON="true"
        VM_POWER_ON_EXPLICIT="true"
        shift
        ;;
      --no-power-on)
        VM_POWER_ON="false"
        VM_POWER_ON_EXPLICIT="true"
        shift
        ;;
      --overwrite)
        VM_OVERWRITE="true"
        shift
        ;;
      --auto-fallback-empty)
        VM_AUTO_FALLBACK_EMPTY="true"
        shift
        ;;
      --no-auto-fallback-empty)
        VM_AUTO_FALLBACK_EMPTY="false"
        shift
        ;;
      --show-values)
        SHOW_VALUES="true"
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
        usage
        die "Unknown argument: $1"
        ;;
    esac
  done
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "${value}"
}

parse_list_to_array() {
  local raw="$1"
  printf '%s' "${raw}" \
    | tr -d '[]"' \
    | tr ',' '\n' \
    | tr ' ' '\n' \
    | tr '\t' '\n' \
    | awk 'NF'
}

is_ipv4() {
  local ip="$1"
  [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local o1 o2 o3 o4
  IFS='.' read -r o1 o2 o3 o4 <<<"${ip}"
  (( o1 <= 255 && o2 <= 255 && o3 <= 255 && o4 <= 255 ))
}

validate_base_inputs() {
  if [[ "${SHOW_VALUES}" == "false" ]]; then
    [[ -n "${ACTION}" ]] || die "Action is required: create, destroy, or plan."
  fi
  [[ -n "${ENV_NAME}" ]] || die "--env cannot be empty."

  if [[ "${SHOW_VALUES}" == "false" ]]; then
    command -v govc >/dev/null 2>&1 || die "govc is not installed or not in PATH."
  fi
}

load_context() {
  SELECTED_VARS_FILE="${REPO_ROOT}/overlays/${ENV_NAME}/scripts/vars.sh"
  load_overlay_vars "${ENV_NAME}"
  export_common_tool_env

  if [[ -n "${CUSTOM_VARS_FILE}" ]]; then
    if [[ "${CUSTOM_VARS_FILE}" != /* ]]; then
      CUSTOM_VARS_FILE="${REPO_ROOT}/${CUSTOM_VARS_FILE}"
    fi
    require_file "${CUSTOM_VARS_FILE}"
    SELECTED_VARS_FILE="${CUSTOM_VARS_FILE}"
    # shellcheck disable=SC1090
    source "${CUSTOM_VARS_FILE}"
  fi
}

print_var_line() {
  local key="$1"
  local value="${2:-}"
  if [[ "${key}" =~ (PASSWORD|PASS|TOKEN|SECRET|PRIVATE_KEY|_KEY$) ]] && [[ -n "${value}" ]]; then
    value="***"
  fi
  printf '%s=%s\n' "${key}" "${value}"
}

print_selected_vars() {
  local vars_file="$1"
  local var_name
  [[ -f "${vars_file}" ]] || return 0
  log_info "Project vars from: ${vars_file}"
  while IFS= read -r var_name; do
    [[ -n "${var_name}" ]] || continue
    # shellcheck disable=SC2154
    print_var_line "${var_name}" "${!var_name:-}"
  done < <(awk 'match($0,/^export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)=/,m){print m[1]}' "${vars_file}")
}

print_show_values() {
  log_info "Showing effective DNS provisioning values for env='${ENV_NAME}'"
  print_selected_vars "${SELECTED_VARS_FILE}"
  log_info "Resolved provisioning settings:"
  print_var_line "DNS_ACTION" "${ACTION:-plan}"
  print_var_line "DNS_VM_COUNT" "${VM_COUNT}"
  print_var_line "DNS_VM_PREFIX" "${VM_PREFIX}"
  print_var_line "DNS_VM_START_INDEX" "${VM_START_INDEX}"
  print_var_line "DNS_VM_MODE" "${VM_MODE}"
  print_var_line "DNS_VM_CREATE_STRATEGY" "${VM_CREATE_STRATEGY:-n/a}"
  print_var_line "DNS_VM_SOURCE_KIND" "${VM_SOURCE_KIND:-n/a}"
  print_var_line "DNS_VM_SOURCE_PATH" "${VM_SOURCE_PATH:-${VM_TEMPLATE_NAME:-n/a}}"
  print_var_line "DNS_VM_CPUS" "${VM_CPUS}"
  print_var_line "DNS_VM_MEMORY_MB" "${VM_MEMORY_MB}"
  print_var_line "DNS_VM_DISK_GB" "${VM_DISK_GB}"
  print_var_line "DNS_VM_NETWORK" "${VM_NETWORK:-}"
  print_var_line "DNS_VM_DATASTORE" "${VM_DATASTORE:-}"
  print_var_line "DNS_VM_GATEWAY" "${VM_GATEWAY:-}"
  print_var_line "DNS_VM_NETMASK_PREFIX" "${VM_NETMASK_PREFIX:-}"
  print_var_line "DNS_VM_STATIC_INTERFACE" "${VM_STATIC_INTERFACE:-}"
  print_var_line "DNS_VM_GUEST_USERNAME" "${VM_GUEST_USERNAME:-}"
  print_var_line "DNS_VM_GUEST_PASSWORD" "${VM_GUEST_PASSWORD:-}"
}

resolve_settings() {
  VM_COUNT="${VM_COUNT:-${DNS_VM_COUNT:-${GOVC_VM_COUNT:-1}}}"
  VM_PREFIX="${VM_PREFIX:-${DNS_VM_NAME_PREFIX:-${GOVC_VM_NAME_PREFIX:-talos-dns}}}"
  VM_START_INDEX="${VM_START_INDEX:-${DNS_VM_START_INDEX:-${GOVC_VM_START_INDEX:-1}}}"
  VM_TEMPLATE_NAME="${VM_TEMPLATE_NAME:-${DNS_VM_TEMPLATE_NAME:-${GOVC_VM_TEMPLATE_NAME:-${TF_TEMPLATE_NAME:-}}}}"
  VM_OVA_PATH="${VM_OVA_PATH:-${DNS_VM_OVA_PATH:-${GOVC_VM_OVA_PATH:-}}}"
  VM_OVF_PATH="${VM_OVF_PATH:-${DNS_VM_OVF_PATH:-${GOVC_VM_OVF_PATH:-}}}"
  VM_MODE="${VM_MODE:-${GOVC_VM_MODE:-auto}}"
  VM_CPUS="${VM_CPUS:-${DNS_VM_CPUS:-${GOVC_VM_CPUS:-${TF_VM_CPUS:-1}}}}"
  VM_MEMORY_MB="${VM_MEMORY_MB:-${DNS_VM_MEMORY_MB:-${GOVC_VM_MEMORY_MB:-${TF_VM_MEMORY_MB:-1024}}}}"
  VM_DISK_GB="${VM_DISK_GB:-${DNS_VM_DISK_GB:-${GOVC_VM_DISK_GB:-${TF_VM_DISK_GB:-20}}}}"
  VM_DISK_NAME="${VM_DISK_NAME:-${GOVC_VM_DISK_NAME:-disk-1000-0}}"
  VM_NETWORK="${VM_NETWORK:-${GOVC_NETWORK:-${VSPHERE_NETWORK:-}}}"
  VM_FOLDER="${VM_FOLDER:-${GOVC_FOLDER:-${VSPHERE_FOLDER:-}}}"
  VM_RESOURCE_POOL="${VM_RESOURCE_POOL:-${VSPHERE_RESOURCE_POOL:-}}"
  VM_DATASTORE="${VM_DATASTORE:-${GOVC_DATASTORE:-${VSPHERE_DATASTORE:-}}}"
  VM_GUEST_OS_TYPE="${VM_GUEST_OS_TYPE:-${GOVC_VM_GUEST_OS_TYPE:-ubuntu64Guest}}"
  VM_FIRMWARE="${VM_FIRMWARE:-${GOVC_VM_FIRMWARE:-efi}}"
  VM_NET_ADAPTER="${VM_NET_ADAPTER:-${GOVC_VM_NET_ADAPTER:-e1000e}}"
  VM_DISK_CONTROLLER="${VM_DISK_CONTROLLER:-${GOVC_VM_DISK_CONTROLLER:-scsi}}"
  VM_POWER_ON="${VM_POWER_ON:-${GOVC_VM_POWER_ON:-true}}"
  VM_OVERWRITE="${VM_OVERWRITE:-${GOVC_VM_OVERWRITE:-false}}"
  VM_AUTO_FALLBACK_EMPTY="${VM_AUTO_FALLBACK_EMPTY:-${GOVC_VM_AUTO_FALLBACK_EMPTY:-false}}"
  VM_STATIC_IPS="${VM_STATIC_IPS:-${DNS_VM_STATIC_IP:-${GOVC_VM_STATIC_IPS:-}}}"
  VM_GATEWAY="${VM_GATEWAY:-${DNS_VM_GATEWAY:-${GOVC_VM_GATEWAY:-${TALOS_GATEWAY:-}}}}"
  VM_NETMASK_PREFIX="${VM_NETMASK_PREFIX:-${DNS_VM_NETMASK_PREFIX:-${GOVC_VM_NETMASK_PREFIX:-24}}}"
  VM_NAMESERVERS="${VM_NAMESERVERS:-${DNS_VM_BOOTSTRAP_NAMESERVERS:-${GOVC_VM_NAMESERVERS:-${TALOS_NAMESERVERS:-}}}}"
  VM_STATIC_INTERFACE="${DNS_VM_STATIC_INTERFACE:-${VM_STATIC_INTERFACE:-${GOVC_VM_STATIC_INTERFACE:-auto}}}"
  VM_GUEST_USERNAME="${VM_GUEST_USERNAME:-${DNS_VM_GUEST_USERNAME:-${GOVC_VM_GUEST_USERNAME:-${BUILD_USERNAME:-}}}}"
  VM_GUEST_PASSWORD="${VM_GUEST_PASSWORD:-${DNS_VM_GUEST_PASSWORD:-${GOVC_VM_GUEST_PASSWORD:-${BUILD_PASSWORD:-}}}}"
  VM_ENFORCE_GUEST_STATIC_NETWORK="${VM_ENFORCE_GUEST_STATIC_NETWORK:-${DNS_VM_GUEST_STATIC:-${GOVC_VM_ENFORCE_GUEST_STATIC_NETWORK:-auto}}}"
  VM_CLOUDINIT_PUBLIC_KEY="${DNS_CLOUDINIT_PUBLIC_KEY:-${BUILD_KEY:-${ANSIBLE_KEY:-}}}"
  VM_CLOUDINIT_PASSWORD="${DNS_CLOUDINIT_PASSWORD:-${VM_GUEST_PASSWORD:-${BUILD_PASSWORD:-}}}"

  VM_STATIC_IP_ARRAY=()
  VM_NAMESERVER_ARRAY=()

  if [[ -n "${VM_STATIC_IPS}" ]]; then
    while IFS= read -r item; do
      item="$(trim_value "${item}")"
      [[ -n "${item}" ]] || continue
      VM_STATIC_IP_ARRAY+=("${item}")
    done < <(parse_list_to_array "${VM_STATIC_IPS}")
  fi

  if [[ -n "${VM_NAMESERVERS}" ]]; then
    while IFS= read -r item; do
      item="$(trim_value "${item}")"
      [[ -n "${item}" ]] || continue
      VM_NAMESERVER_ARRAY+=("${item}")
    done < <(parse_list_to_array "${VM_NAMESERVERS}")
  fi

  case "${VM_ENFORCE_GUEST_STATIC_NETWORK}" in
    auto)
      if (( ${#VM_STATIC_IP_ARRAY[@]} > 0 )) && [[ -n "${VM_GUEST_USERNAME}" ]] && [[ -n "${VM_GUEST_PASSWORD}" ]]; then
        VM_APPLY_GUEST_STATIC_NETWORK="true"
      else
        VM_APPLY_GUEST_STATIC_NETWORK="false"
      fi
      ;;
    true)
      VM_APPLY_GUEST_STATIC_NETWORK="true"
      ;;
    false)
      VM_APPLY_GUEST_STATIC_NETWORK="false"
      ;;
    *)
      die "--guest-static must be one of: auto, true, false."
      ;;
  esac
}

validate_resolved_settings() {
  [[ "${VM_COUNT}" =~ ^[0-9]+$ ]] || die "--count must be numeric."
  [[ "${VM_START_INDEX}" =~ ^[0-9]+$ ]] || die "--start-index must be numeric."
  [[ "${VM_CPUS}" =~ ^[0-9]+$ ]] || die "--cpu must be numeric."
  [[ "${VM_MEMORY_MB}" =~ ^[0-9]+$ ]] || die "--memory-mb must be numeric."
  [[ "${VM_DISK_GB}" =~ ^[0-9]+$ ]] || die "--disk-gb must be numeric."
  [[ "${VM_COUNT}" -ge 1 ]] || die "--count must be at least 1."
  [[ "${VM_MODE}" == "auto" || "${VM_MODE}" == "ova" || "${VM_MODE}" == "ovf" || "${VM_MODE}" == "clone" || "${VM_MODE}" == "empty" ]] || {
    die "--mode must be one of: auto, ova, ovf, clone, empty."
  }
  [[ "${VM_AUTO_FALLBACK_EMPTY}" == "true" || "${VM_AUTO_FALLBACK_EMPTY}" == "false" ]] || {
    die "--auto-fallback-empty expects true/false."
  }

  [[ -n "${VM_PREFIX}" ]] || die "VM prefix cannot be empty."
  [[ -n "${VM_DISK_NAME}" ]] || die "VM disk name cannot be empty."
  [[ "${VM_NETMASK_PREFIX}" =~ ^[0-9]+$ ]] || die "VM netmask prefix must be numeric."
  [[ "${VM_NETMASK_PREFIX}" -ge 1 && "${VM_NETMASK_PREFIX}" -le 32 ]] || die "VM netmask prefix must be between 1 and 32."
  [[ "${VM_ENFORCE_GUEST_STATIC_NETWORK}" == "auto" || "${VM_ENFORCE_GUEST_STATIC_NETWORK}" == "true" || "${VM_ENFORCE_GUEST_STATIC_NETWORK}" == "false" ]] || {
    die "--guest-static must be one of: auto, true, false."
  }

  if [[ "${ACTION}" == "create" ]]; then
    [[ -n "${VM_DATASTORE}" ]] || die "Datastore is required for create. Set --datastore or GOVC_DATASTORE/VSPHERE_DATASTORE."
    if (( ${#VM_STATIC_IP_ARRAY[@]} > 0 )); then
      (( ${#VM_STATIC_IP_ARRAY[@]} >= VM_COUNT )) || die "Not enough static IPs for count=${VM_COUNT}. Set GOVC_VM_STATIC_IPS with at least ${VM_COUNT} entries."
      [[ -n "${VM_GATEWAY}" ]] || die "VM gateway is required when static IPs are enabled."
      [[ ${#VM_NAMESERVER_ARRAY[@]} -gt 0 ]] || die "At least one nameserver is required when static IPs are enabled."
      for ip in "${VM_STATIC_IP_ARRAY[@]}"; do
        is_ipv4 "${ip}" || die "Invalid static IP: ${ip}"
      done
      is_ipv4 "${VM_GATEWAY}" || die "Invalid VM gateway: ${VM_GATEWAY}"
      for ip in "${VM_NAMESERVER_ARRAY[@]}"; do
        is_ipv4 "${ip}" || die "Invalid nameserver IP: ${ip}"
      done
      if [[ "${VM_APPLY_GUEST_STATIC_NETWORK}" == "true" ]]; then
        [[ -n "${VM_GUEST_USERNAME}" ]] || die "Guest username is required when guest static enforcement is enabled."
        [[ -n "${VM_GUEST_PASSWORD}" ]] || die "Guest password is required when guest static enforcement is enabled."
      fi
    fi
  fi

  [[ -n "${GOVC_URL:-}" ]] || die "GOVC_URL is empty. Set VSPHERE_ENDPOINT in overlays/<env>/scripts/vars.sh or export GOVC_URL."
  [[ -n "${GOVC_USERNAME:-}" ]] || die "GOVC_USERNAME is empty. Set VSPHERE_USERNAME in overlays/<env>/scripts/vars.sh or export GOVC_USERNAME."
  [[ -n "${GOVC_PASSWORD:-}" ]] || die "GOVC_PASSWORD is empty. Set VSPHERE_PASSWORD in overlays/<env>/scripts/vars.sh or export GOVC_PASSWORD."
}

vm_name_at() {
  local index="$1"
  printf '%s-%s\n' "${VM_PREFIX}" "${index}"
}

resolve_artifact_path() {
  local artifact_type="$1"
  local artifact_value="$2"
  local -a search_paths=()
  local candidate=""
  local resolved=""

  [[ -n "${artifact_value}" ]] || return 1

  case "${artifact_value}" in
    http://*|https://*)
      printf '%s\n' "${artifact_value}"
      return 0
      ;;
    *)
      ;;
  esac

  if [[ "${artifact_value}" = /* ]]; then
    search_paths+=("${artifact_value}")
  else
    search_paths+=("${artifact_value}")
    search_paths+=("${REPO_ROOT}/${artifact_value}")
    search_paths+=("${PWD}/${artifact_value}")
  fi

  for candidate in "${search_paths[@]}"; do
    if [[ -f "${candidate}" ]]; then
      resolved="${candidate}"
      break
    fi

    if [[ -d "${candidate}" ]]; then
      case "${artifact_type}" in
        ova)
          resolved="$(find "${candidate}" -maxdepth 1 -type f -name '*.ova' | sort | head -n 1 || true)"
          ;;
        ovf)
          resolved="$(find "${candidate}" -maxdepth 1 -type f -name '*.ovf' | sort | head -n 1 || true)"
          ;;
        *)
          die "Unsupported artifact type: ${artifact_type}"
          ;;
      esac
      [[ -n "${resolved}" ]] && break
    fi
  done

  [[ -n "${resolved}" ]] || return 1
  printf '%s\n' "${resolved}"
}

vm_exists() {
  local vm_name="$1"
  govc find / -type m -name "${vm_name}" 2>/dev/null | grep -qx ".*/${vm_name}"
}

resolve_ova_source() {
  local resolved=""

  resolved="$(resolve_artifact_path "ova" "${VM_OVA_PATH}")" || return 1
  VM_SOURCE_KIND="ova"
  VM_SOURCE_PATH="${resolved}"
  return 0
}

resolve_ovf_source() {
  local resolved=""

  resolved="$(resolve_artifact_path "ovf" "${VM_OVF_PATH}")" || return 1
  VM_SOURCE_KIND="ovf"
  VM_SOURCE_PATH="${resolved}"
  return 0
}

resolve_clone_source() {
  local candidates=()
  local fallback_list=""
  local item=""
  local -a extra_candidates=()

  if [[ -n "${VM_TEMPLATE_NAME}" ]]; then
    candidates+=("${VM_TEMPLATE_NAME}")
  fi

  fallback_list="${GOVC_VM_SOURCE_CANDIDATES:-${GOVC_VM_TEMPLATE_FALLBACKS:-}}"
  if [[ -n "${fallback_list}" ]]; then
    IFS=',' read -r -a extra_candidates <<<"${fallback_list}"
    for item in "${extra_candidates[@]}"; do
      item="${item#"${item%%[![:space:]]*}"}"
      item="${item%"${item##*[![:space:]]}"}"
      [[ -n "${item}" ]] && candidates+=("${item}")
    done
  fi

  if [[ ${#candidates[@]} -eq 0 ]]; then
    return 1
  fi

  for item in "${candidates[@]}"; do
    if vm_exists "${item}"; then
      VM_TEMPLATE_NAME="${item}"
      return 0
    fi
  done

  return 1
}

resolve_create_strategy() {
  [[ "${ACTION}" == "create" ]] || return 0

  case "${VM_MODE}" in
    clone)
      resolve_clone_source || die "Clone mode requested, but no source VM/template was found. Set --template or GOVC_VM_SOURCE_CANDIDATES."
      VM_SOURCE_KIND="clone"
      VM_SOURCE_PATH="${VM_TEMPLATE_NAME}"
      VM_CREATE_STRATEGY="clone"
      ;;
    empty)
      VM_SOURCE_KIND="empty"
      VM_SOURCE_PATH=""
      VM_CREATE_STRATEGY="empty"
      if [[ "${VM_POWER_ON_EXPLICIT}" != "true" ]]; then
        VM_POWER_ON="false"
      fi
      ;;
    ova)
      resolve_ova_source || die "OVA mode requested, but no artifact was found. Set --ova-path or GOVC_VM_OVA_PATH."
      VM_CREATE_STRATEGY="ova"
      ;;
    ovf)
      resolve_ovf_source || die "OVF mode requested, but no artifact was found. Set --ovf-path or GOVC_VM_OVF_PATH."
      VM_CREATE_STRATEGY="ovf"
      ;;
    auto)
      if resolve_ova_source; then
        VM_CREATE_STRATEGY="ova"
      elif resolve_ovf_source; then
        VM_CREATE_STRATEGY="ovf"
      elif resolve_clone_source; then
        VM_SOURCE_KIND="clone"
        VM_SOURCE_PATH="${VM_TEMPLATE_NAME}"
        VM_CREATE_STRATEGY="clone"
      else
        if [[ "${VM_AUTO_FALLBACK_EMPTY}" == "true" ]]; then
          VM_SOURCE_KIND="empty"
          VM_SOURCE_PATH=""
          VM_CREATE_STRATEGY="empty"
          if [[ "${VM_POWER_ON_EXPLICIT}" != "true" ]]; then
            VM_POWER_ON="false"
          fi
        else
          die "No OVA/OVF artifact or clone source found. Set --ova-path, --ovf-path, --template, or use --auto-fallback-empty explicitly."
        fi
      fi
      ;;
    *)
      die "Unsupported mode: ${VM_MODE}"
      ;;
  esac
}

print_plan() {
  local index vm_name
  log_info "Plan for action '${ACTION}' in env '${ENV_NAME}'"
  log_info "count=${VM_COUNT} prefix=${VM_PREFIX} start-index=${VM_START_INDEX}"
  log_info "mode=${VM_MODE} strategy=${VM_CREATE_STRATEGY:-n/a} source-kind=${VM_SOURCE_KIND:-<n/a>} source=${VM_SOURCE_PATH:-${VM_TEMPLATE_NAME:-<n/a>}} cpu=${VM_CPUS} memory-mb=${VM_MEMORY_MB} disk-gb=${VM_DISK_GB}"
  log_info "network=${VM_NETWORK:-<current>} datastore=${VM_DATASTORE:-<unset>} folder=${VM_FOLDER:-<current>} pool=${VM_RESOURCE_POOL:-<current>}"
  log_info "power-on=${VM_POWER_ON} overwrite=${VM_OVERWRITE} auto-fallback-empty=${VM_AUTO_FALLBACK_EMPTY}"
  if (( ${#VM_STATIC_IP_ARRAY[@]} > 0 )); then
    log_info "static-network=true interface=${VM_STATIC_INTERFACE} gateway=${VM_GATEWAY} prefix=${VM_NETMASK_PREFIX} nameservers=${VM_NAMESERVER_ARRAY[*]}"
    log_info "guest-static-enforcement=${VM_APPLY_GUEST_STATIC_NETWORK} mode=${VM_ENFORCE_GUEST_STATIC_NETWORK}"
  else
    log_info "static-network=false (DHCP/guest default)"
  fi

  for ((index = VM_START_INDEX; index < VM_START_INDEX + VM_COUNT; index++)); do
    vm_name="$(vm_name_at "${index}")"
    if vm_exists "${vm_name}"; then
      log_info "- ${vm_name}: exists"
    else
      log_info "- ${vm_name}: missing"
    fi
  done
}

build_cloud_init_metadata() {
  local vm_name="$1"
  local static_ip="$2"
  local dns_inline=""
  local ns=""
  local iface_block=""

  for ns in "${VM_NAMESERVER_ARRAY[@]}"; do
    if [[ -n "${dns_inline}" ]]; then
      dns_inline+=", "
    fi
    dns_inline+="${ns}"
  done

  if [[ "${VM_STATIC_INTERFACE}" == "auto" ]]; then
    iface_block=$(cat <<'EOF_IFACE'
    primary:
      match:
        name: "e*"
EOF_IFACE
)
  else
    iface_block=$(cat <<EOF_IFACE
    ${VM_STATIC_INTERFACE}:
EOF_IFACE
)
  fi

  cat <<EOF_META
instance-id: ${vm_name}
local-hostname: ${vm_name}
network:
  version: 2
  ethernets:
${iface_block}
      dhcp4: false
      addresses:
        - ${static_ip}/${VM_NETMASK_PREFIX}
      routes:
        - to: default
          via: ${VM_GATEWAY}
      nameservers:
        addresses: [${dns_inline}]
EOF_META
}

build_cloud_init_user_data() {
  local vm_name="$1"
  local user_name="$2"
  local user_pass="$3"
  local user_key="$4"

  cat <<EOF_USERDATA
#cloud-config
preserve_hostname: false
hostname: ${vm_name}
manage_etc_hosts: true
users:
  - default
EOF_USERDATA

  if [[ -n "${user_name}" ]]; then
    cat <<EOF_USERDATA
  - name: ${user_name}
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
EOF_USERDATA
    if [[ -n "${user_key}" ]]; then
      cat <<EOF_USERDATA
    ssh_authorized_keys:
      - ${user_key}
EOF_USERDATA
    fi
  fi

  if [[ -n "${user_pass}" && -n "${user_name}" ]]; then
    cat <<EOF_USERDATA
chpasswd:
  expire: false
  list: |
    ${user_name}:${user_pass}
ssh_pwauth: true
EOF_USERDATA
  fi
}

wait_for_guest_login() {
  local vm_name="$1"
  local attempt=0

  while (( attempt < 30 )); do
    if govc guest.run -vm "${vm_name}" -l "${VM_GUEST_USERNAME}:${VM_GUEST_PASSWORD}" /usr/bin/true >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  return 1
}

build_guest_static_network_script() {
  local vm_name="$1"
  local static_ip="$2"
  local dns_lines=""
  local ns=""
  local iface_script=""

  for ns in "${VM_NAMESERVER_ARRAY[@]}"; do
    dns_lines+="          - ${ns}"$'\n'
  done

  if [[ "${VM_STATIC_INTERFACE}" == "auto" ]]; then
    iface_script=$(cat <<'EOF_IFACE'
IFACE="$(ip -o route show to default 2>/dev/null | awk '{print $5; exit}')"
if [[ -z "${IFACE}" ]]; then
  IFACE="$(ip -o link show | awk -F': ' '/^[0-9]+: e/ {print $2; exit}')"
fi
if [[ -z "${IFACE}" ]]; then
  echo "Could not auto-detect network interface" >&2
  exit 1
fi
EOF_IFACE
)
  else
    iface_script=$(cat <<EOF_IFACE
IFACE="${VM_STATIC_INTERFACE}"
EOF_IFACE
)
  fi

  cat <<EOF_GUEST
set -euo pipefail
${iface_script}
cat >/tmp/99-govc-static.yaml <<NET
network:
  version: 2
  ethernets:
    \${IFACE}:
      dhcp4: false
      addresses:
        - ${static_ip}/${VM_NETMASK_PREFIX}
      routes:
        - to: default
          via: ${VM_GATEWAY}
      nameservers:
        addresses:
${dns_lines}NET
sudo install -m 0600 /tmp/99-govc-static.yaml /etc/netplan/99-govc-static.yaml
sudo install -d -m 0755 /etc/cloud/cloud.cfg.d
cat >/tmp/99-disable-network-config.cfg <<'CLOUD'
network: {config: disabled}
CLOUD
sudo install -m 0644 /tmp/99-disable-network-config.cfg /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
if [[ -f /etc/netplan/50-cloud-init.yaml ]]; then
  sudo rm -f /etc/netplan/50-cloud-init.yaml
fi
sudo hostnamectl set-hostname ${vm_name} || true
sudo netplan generate
sudo netplan apply
EOF_GUEST
}

apply_guest_static_network() {
  local vm_name="$1"
  local static_ip="$2"
  local script_data=""

  if ! wait_for_guest_login "${vm_name}"; then
    log_warn "Guest operations not ready on ${vm_name}; skipping in-guest static network enforcement."
    return 1
  fi

  script_data="$(build_guest_static_network_script "${vm_name}" "${static_ip}")"
  govc guest.run -vm "${vm_name}" -l "${VM_GUEST_USERNAME}:${VM_GUEST_PASSWORD}" -d "${script_data}" /bin/bash -s
}

clone_vm() {
  local vm_name="$1"
  local clone_args=(vm.clone)

  if [[ -n "${VM_FOLDER}" ]]; then
    clone_args+=(-folder "${VM_FOLDER}")
  fi
  if [[ -n "${VM_RESOURCE_POOL}" ]]; then
    clone_args+=(-pool "${VM_RESOURCE_POOL}")
  fi
  if [[ -n "${VM_DATASTORE}" ]]; then
    clone_args+=(-ds "${VM_DATASTORE}")
  fi

  clone_args+=(-vm "${VM_TEMPLATE_NAME}" "${vm_name}")
  govc "${clone_args[@]}"
}

import_vm_from_artifact() {
  local vm_name="$1"
  local artifact_type="$2"
  local import_args=()

  case "${artifact_type}" in
    ova)
      import_args=(import.ova)
      ;;
    ovf)
      import_args=(import.ovf)
      ;;
    *)
      die "Invalid artifact type: ${artifact_type}"
      ;;
  esac

  if [[ -n "${VM_FOLDER}" ]]; then
    import_args+=(-folder "${VM_FOLDER}")
  fi
  if [[ -n "${VM_RESOURCE_POOL}" ]]; then
    import_args+=(-pool "${VM_RESOURCE_POOL}")
  fi
  if [[ -n "${VM_DATASTORE}" ]]; then
    import_args+=(-ds "${VM_DATASTORE}")
  fi
  if [[ -n "${VM_NETWORK}" ]]; then
    import_args+=(-net "${VM_NETWORK}")
  fi

  import_args+=(-name "${vm_name}" "${VM_SOURCE_PATH}")
  govc "${import_args[@]}"
}

create_empty_vm() {
  local vm_name="$1"
  local create_args=(vm.create)

  if [[ -n "${VM_FOLDER}" ]]; then
    create_args+=(-folder "${VM_FOLDER}")
  fi
  if [[ -n "${VM_RESOURCE_POOL}" ]]; then
    create_args+=(-pool "${VM_RESOURCE_POOL}")
  fi
  if [[ -n "${VM_DATASTORE}" ]]; then
    create_args+=(-ds "${VM_DATASTORE}")
  fi
  if [[ -n "${VM_NETWORK}" ]]; then
    create_args+=(-net "${VM_NETWORK}")
  fi

  create_args+=(-on=false -c "${VM_CPUS}" -m "${VM_MEMORY_MB}" -g "${VM_GUEST_OS_TYPE}" -firmware "${VM_FIRMWARE}" -disk "${VM_DISK_GB}G" -disk.controller "${VM_DISK_CONTROLLER}" -net.adapter "${VM_NET_ADAPTER}" "${vm_name}")
  govc "${create_args[@]}"
}

create_vm() {
  local vm_name="$1"
  local ordinal="$2"
  local source_failed="false"
  local static_ip=""
  local metadata=""
  local metadata_b64=""
  local user_data=""
  local user_data_b64=""

  if vm_exists "${vm_name}"; then
    if [[ "${VM_OVERWRITE}" == "true" ]]; then
      log_warn "VM ${vm_name} already exists. Destroying because overwrite=true."
      govc vm.destroy "${vm_name}"
    else
      log_warn "VM ${vm_name} already exists. Skipping create."
      return 0
    fi
  fi

  case "${VM_CREATE_STRATEGY}" in
    clone)
      log_info "Cloning VM ${vm_name} from source ${VM_TEMPLATE_NAME}"
      if ! clone_vm "${vm_name}"; then
        source_failed="true"
      fi
      if [[ "${source_failed}" == "true" ]]; then
        if [[ "${VM_MODE}" == "auto" ]]; then
          if [[ "${VM_AUTO_FALLBACK_EMPTY}" == "true" ]]; then
            log_warn "Clone failed on this environment. Falling back to empty VM create for ${vm_name}."
            VM_CREATE_STRATEGY="empty"
            create_empty_vm "${vm_name}"
          else
            die "Clone failed for ${vm_name} and auto fallback is disabled. Use --mode=empty explicitly or --auto-fallback-empty."
          fi
        else
          die "Clone failed for ${vm_name} in mode=clone."
        fi
      fi
      ;;
    ova|ovf)
      log_info "Importing ${VM_CREATE_STRATEGY^^} artifact ${VM_SOURCE_PATH} for VM ${vm_name}"
      if ! import_vm_from_artifact "${vm_name}" "${VM_CREATE_STRATEGY}"; then
        source_failed="true"
      fi
      if [[ "${source_failed}" == "true" ]]; then
        if [[ "${VM_MODE}" == "auto" && "${VM_AUTO_FALLBACK_EMPTY}" == "true" ]]; then
          log_warn "Artifact import failed on this environment. Falling back to empty VM create for ${vm_name}."
          VM_CREATE_STRATEGY="empty"
          create_empty_vm "${vm_name}"
        else
          die "Artifact import failed for ${vm_name} in mode=${VM_CREATE_STRATEGY}."
        fi
      fi
      ;;
    empty)
      log_info "Creating empty VM ${vm_name} (no clone source found/selected)"
      create_empty_vm "${vm_name}"
      ;;
    *)
      die "Invalid create strategy: ${VM_CREATE_STRATEGY}"
      ;;
  esac

  govc vm.change \
    -c "${VM_CPUS}" \
    -m "${VM_MEMORY_MB}" \
    -e "disk.enableUUID=1" \
    -vm "${vm_name}"

  if (( ${#VM_STATIC_IP_ARRAY[@]} > 0 )); then
    static_ip="${VM_STATIC_IP_ARRAY[$((ordinal - 1))]}"
    metadata="$(build_cloud_init_metadata "${vm_name}" "${static_ip}")"
    metadata_b64="$(printf '%s' "${metadata}" | base64 | tr -d '\n')"
    govc vm.change \
      -vm "${vm_name}" \
      -e "guestinfo.metadata=${metadata_b64}" \
      -e "guestinfo.metadata.encoding=base64"
  fi

  if [[ -n "${VM_GUEST_USERNAME}" || -n "${VM_CLOUDINIT_PUBLIC_KEY}" || -n "${VM_CLOUDINIT_PASSWORD}" ]]; then
    user_data="$(build_cloud_init_user_data "${vm_name}" "${VM_GUEST_USERNAME}" "${VM_CLOUDINIT_PASSWORD}" "${VM_CLOUDINIT_PUBLIC_KEY}")"
    user_data_b64="$(printf '%s' "${user_data}" | base64 | tr -d '\n')"
    govc vm.change \
      -vm "${vm_name}" \
      -e "guestinfo.userdata=${user_data_b64}" \
      -e "guestinfo.userdata.encoding=base64"
  fi

  if [[ "${VM_CREATE_STRATEGY}" == "clone" ]]; then
    govc vm.disk.change -vm "${vm_name}" -disk.name "${VM_DISK_NAME}" -size "${VM_DISK_GB}G"
  elif [[ "${VM_CREATE_STRATEGY}" == "ova" || "${VM_CREATE_STRATEGY}" == "ovf" ]]; then
    log_warn "Disk resize skipped for ${VM_CREATE_STRATEGY} imports; disk name mapping is artifact-dependent."
  elif [[ "${VM_DISK_NAME}" != "disk-1000-0" ]]; then
    log_warn "Disk name override is ignored in empty mode; GOVC assigns the default disk device."
  fi

  if [[ -n "${VM_NETWORK}" ]]; then
    govc vm.network.change -vm "${vm_name}" -net "${VM_NETWORK}" ethernet-0
  else
    log_warn "No network override set. Keeping default NIC network for ${vm_name}."
  fi

  if [[ "${VM_CREATE_STRATEGY}" == "empty" && "${VM_POWER_ON}" == "true" && "${VM_POWER_ON_EXPLICIT}" != "true" ]]; then
    log_warn "Empty VM has no bootable OS disk. Skipping power on to avoid EFI boot failure. Use --power-on only if you will boot from ISO/PXE."
    VM_POWER_ON="false"
  fi

  if [[ "${VM_POWER_ON}" == "true" ]]; then
    govc vm.power -on "${vm_name}"
  fi

  if (( ${#VM_STATIC_IP_ARRAY[@]} > 0 )) && [[ "${VM_APPLY_GUEST_STATIC_NETWORK}" == "true" ]]; then
    if [[ "${VM_POWER_ON}" == "true" ]]; then
      if ! apply_guest_static_network "${vm_name}" "${static_ip}"; then
        log_warn "In-guest static enforcement failed for ${vm_name}. Guest may still rely on cloud-init metadata."
      fi
    else
      log_warn "In-guest static enforcement skipped for ${vm_name} because VM is powered off."
    fi
  fi
}

destroy_vm() {
  local vm_name="$1"
  if vm_exists "${vm_name}"; then
    log_info "Destroying VM ${vm_name}"
    govc vm.destroy "${vm_name}"
  else
    log_warn "VM ${vm_name} not found. Skipping destroy."
  fi
}

execute_action() {
  local index vm_name
  local ordinal
  for ((index = VM_START_INDEX; index < VM_START_INDEX + VM_COUNT; index++)); do
    vm_name="$(vm_name_at "${index}")"
    ordinal=$((index - VM_START_INDEX + 1))
    case "${ACTION}" in
      create)
        create_vm "${vm_name}" "${ordinal}"
        ;;
      destroy)
        destroy_vm "${vm_name}"
        ;;
      *)
        die "Unsupported action: ${ACTION}"
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  if [[ "${SHOW_VALUES}" == "true" && -z "${ACTION}" ]]; then
    ACTION="plan"
  fi
  validate_base_inputs
  load_context
  resolve_settings

  if [[ "${SHOW_VALUES}" == "true" ]]; then
    print_show_values
    return 0
  fi

  validate_resolved_settings
  resolve_create_strategy

  print_plan

  if [[ "${ACTION}" == "plan" ]]; then
    return 0
  fi

  execute_action
  log_info "Action '${ACTION}' completed successfully."
}

main "$@"
