#!/usr/bin/env bash
# @file lib/pkr-vars.sh
# @description Internal library for loading module vars and exporting PKR_VAR_*.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This file is a library and must be sourced."
  exit 1
fi

pkr_log_info() {
  [[ "${PKR_EXPORT_SILENT:-false}" == "true" ]] || echo "[INFO] $*"
}

pkr_die() {
  echo "[ERROR] $*" >&2
  exit 1
}

pkr_to_bool() {
  local value="${1:-}"
  case "${value,,}" in
    1|true|yes|on) echo "true" ;;
    0|false|no|off|"") echo "false" ;;
    *) echo "${value}" ;;
  esac
}

pkr_normalize_values() {
  VSPHERE_ENDPOINT="${VSPHERE_ENDPOINT#https://}"
  VSPHERE_ENDPOINT="${VSPHERE_ENDPOINT#http://}"
  VSPHERE_ENDPOINT="${VSPHERE_ENDPOINT%%/}"

  VSPHERE_INSECURE_CONNECTION="$(pkr_to_bool "${VSPHERE_INSECURE_CONNECTION}")"
  VSPHERE_SET_HOST_FOR_DATASTORE_UPLOADS="$(pkr_to_bool "${VSPHERE_SET_HOST_FOR_DATASTORE_UPLOADS}")"
  COMMON_ISO_CONTENT_LIBRARY_ENABLED="$(pkr_to_bool "${COMMON_ISO_CONTENT_LIBRARY_ENABLED}")"
  COMMON_TOOLS_UPGRADE_POLICY="$(pkr_to_bool "${COMMON_TOOLS_UPGRADE_POLICY}")"
  COMMON_REMOVE_CDROM="$(pkr_to_bool "${COMMON_REMOVE_CDROM}")"
  COMMON_TEMPLATE_CONVERSION="$(pkr_to_bool "${COMMON_TEMPLATE_CONVERSION}")"
  COMMON_CONTENT_LIBRARY_ENABLED="$(pkr_to_bool "${COMMON_CONTENT_LIBRARY_ENABLED}")"
  COMMON_CONTENT_LIBRARY_OVF="$(pkr_to_bool "${COMMON_CONTENT_LIBRARY_OVF}")"
  COMMON_CONTENT_LIBRARY_DESTROY="$(pkr_to_bool "${COMMON_CONTENT_LIBRARY_DESTROY}")"
  COMMON_CONTENT_LIBRARY_SKIP_EXPORT="$(pkr_to_bool "${COMMON_CONTENT_LIBRARY_SKIP_EXPORT}")"
  COMMON_OVF_EXPORT_ENABLED="$(pkr_to_bool "${COMMON_OVF_EXPORT_ENABLED}")"
  COMMON_OVF_EXPORT_OVERWRITE="$(pkr_to_bool "${COMMON_OVF_EXPORT_OVERWRITE}")"
  COMMON_OVF_EXPORT_IMAGE_FILES="$(pkr_to_bool "${COMMON_OVF_EXPORT_IMAGE_FILES}")"
  COMMON_HCP_PACKER_REGISTRY_ENABLED="$(pkr_to_bool "${COMMON_HCP_PACKER_REGISTRY_ENABLED}")"
}

pkr_load_module_vars() {
  local script_dir repo_root base_vars local_vars
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "${script_dir}/.." && pwd)"
  base_vars="${repo_root}/vars.sh"
  local_vars="${repo_root}/vars.local.sh"

  [[ -f "${base_vars}" ]] || pkr_die "Required vars file not found: ${base_vars}"
  # shellcheck disable=SC1090
  source "${base_vars}"

  if [[ -f "${local_vars}" ]]; then
    # shellcheck disable=SC1090
    source "${local_vars}"
    pkr_log_info "Loaded local overrides from ${local_vars}"
  fi

  pkr_normalize_values
}

pkr_export_common_env() {
  export GOVC_URL="https://${VSPHERE_ENDPOINT}"
  export GOVC_USERNAME="${VSPHERE_USERNAME}"
  export GOVC_PASSWORD="${VSPHERE_PASSWORD}"
  export GOVC_INSECURE="${VSPHERE_INSECURE_CONNECTION}"
  export GOVC_DATASTORE="${VSPHERE_DATASTORE}"
  export GOVC_NETWORK="${VSPHERE_NETWORK}"
  export GOVC_FOLDER="${VSPHERE_FOLDER}"
  export GOVC_DATACENTER="${VSPHERE_DATACENTER}"
}

pkr_export_vars() {
  local ansible_username="${ANSIBLE_USERNAME:-${BUILD_USERNAME:-}}"
  local ansible_key="${ANSIBLE_KEY:-${BUILD_KEY:-}}"

  export PKR_VAR_vsphere_endpoint="${VSPHERE_ENDPOINT}"
  export PKR_VAR_vsphere_username="${VSPHERE_USERNAME}"
  export PKR_VAR_vsphere_password="${VSPHERE_PASSWORD}"
  export PKR_VAR_vsphere_insecure_connection="${VSPHERE_INSECURE_CONNECTION}"
  export PKR_VAR_vsphere_datacenter="${VSPHERE_DATACENTER}"
  export PKR_VAR_vsphere_cluster="${VSPHERE_CLUSTER}"
  export PKR_VAR_vsphere_host="${VSPHERE_HOST}"
  export PKR_VAR_vsphere_datastore="${VSPHERE_DATASTORE}"
  export PKR_VAR_vsphere_network="${VSPHERE_NETWORK}"
  export PKR_VAR_vsphere_folder="${VSPHERE_FOLDER}"
  export PKR_VAR_vsphere_resource_pool="${VSPHERE_RESOURCE_POOL}"
  export PKR_VAR_vsphere_set_host_for_datastore_uploads="${VSPHERE_SET_HOST_FOR_DATASTORE_UPLOADS}"
  export PKR_VAR_common_iso_datastore="${COMMON_ISO_DATASTORE}"
  export PKR_VAR_common_iso_content_library="${COMMON_ISO_CONTENT_LIBRARY}"
  export PKR_VAR_common_iso_content_library_enabled="${COMMON_ISO_CONTENT_LIBRARY_ENABLED}"
  export PKR_VAR_common_vm_version="${COMMON_VM_VERSION}"
  export PKR_VAR_common_tools_upgrade_policy="${COMMON_TOOLS_UPGRADE_POLICY}"
  export PKR_VAR_common_remove_cdrom="${COMMON_REMOVE_CDROM}"
  export PKR_VAR_common_template_conversion="${COMMON_TEMPLATE_CONVERSION}"
  export PKR_VAR_common_content_library="${COMMON_CONTENT_LIBRARY}"
  export PKR_VAR_common_content_library_enabled="${COMMON_CONTENT_LIBRARY_ENABLED}"
  export PKR_VAR_common_content_library_ovf="${COMMON_CONTENT_LIBRARY_OVF}"
  export PKR_VAR_common_content_library_destroy="${COMMON_CONTENT_LIBRARY_DESTROY}"
  export PKR_VAR_common_content_library_skip_export="${COMMON_CONTENT_LIBRARY_SKIP_EXPORT}"
  export PKR_VAR_common_ovf_export_enabled="${COMMON_OVF_EXPORT_ENABLED}"
  export PKR_VAR_common_ovf_export_overwrite="${COMMON_OVF_EXPORT_OVERWRITE}"
  export PKR_VAR_common_ovf_export_image_files="${COMMON_OVF_EXPORT_IMAGE_FILES}"
  export PKR_VAR_common_data_source="${COMMON_DATA_SOURCE}"
  export PKR_VAR_common_http_ip="${COMMON_HTTP_IP}"
  export PKR_VAR_common_http_port_min="${COMMON_HTTP_PORT_MIN}"
  export PKR_VAR_common_http_port_max="${COMMON_HTTP_PORT_MAX}"
  export PKR_VAR_common_ip_wait_timeout="${COMMON_IP_WAIT_TIMEOUT}"
  export PKR_VAR_common_ip_settle_timeout="${COMMON_IP_SETTLE_TIMEOUT}"
  export PKR_VAR_common_shutdown_timeout="${COMMON_SHUTDOWN_TIMEOUT}"
  export PKR_VAR_build_username="${BUILD_USERNAME}"
  export PKR_VAR_build_password="${BUILD_PASSWORD}"
  export PKR_VAR_build_password_encrypted="${BUILD_PASSWORD_ENCRYPTED}"
  export PKR_VAR_build_key="${BUILD_KEY}"
  export PKR_VAR_ansible_username="${ansible_username}"
  export PKR_VAR_ansible_key="${ansible_key}"
  export PKR_VAR_communicator_proxy_host="${COMMUNICATOR_PROXY_HOST}"
  export PKR_VAR_communicator_proxy_port="${COMMUNICATOR_PROXY_PORT}"
  export PKR_VAR_communicator_proxy_username="${COMMUNICATOR_PROXY_USERNAME}"
  export PKR_VAR_communicator_proxy_password="${COMMUNICATOR_PROXY_PASSWORD}"
  export PKR_VAR_common_hcp_packer_registry_enabled="${COMMON_HCP_PACKER_REGISTRY_ENABLED}"

  if [[ "${PACKER_ENABLE_LOG:-false}" == "true" ]]; then
    export PACKER_LOG=1
    export PACKER_LOG_PATH="${PACKER_LOG_PATH}"
    mkdir -p "$(dirname "${PACKER_LOG_PATH}")"
  else
    unset PACKER_LOG || true
    unset PACKER_LOG_PATH || true
  fi
}
