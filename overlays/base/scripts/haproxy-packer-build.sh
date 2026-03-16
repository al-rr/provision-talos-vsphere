#!/usr/bin/env bash
set -euo pipefail

# @describe Validate or build the HAProxy template from the base Packer tree.
# @option --env Target overlay environment. Defaults to prod.
# @flag --validate-only Only run packer init and validate.

ENV_NAME="prod"
VALIDATE_ONLY="false"

for arg in "$@"; do
  case "$arg" in
    --env=*)
      ENV_NAME="${arg#*=}"
      ;;
    --validate-only)
      VALIDATE_ONLY="true"
      ;;
    *)
      echo "Usage: $0 [--env=<env>] [--validate-only]"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/functions.sh"
load_overlay_vars "${ENV_NAME}"
export_common_tool_env
export_packer_vars

PACKER_TEMPLATE_PATH="${REPO_ROOT}/${HAPROXY_PACKER_TEMPLATE_PATH}"
ISO_VARS_FILE="${PACKER_TEMPLATE_PATH}/ubuntu.auto.pkrvars.hcl"
ISO_DATASTORE_PATH="$(sed -n 's/^iso_datastore_path\\s*=\\s*\"\\(.*\\)\"/\\1/p' "${ISO_VARS_FILE}")"
ISO_FILE_NAME="$(sed -n 's/^iso_file\\s*=\\s*\"\\(.*\\)\"/\\1/p' "${ISO_VARS_FILE}")"
ISO_REMOTE_PATH="${ISO_DATASTORE_PATH}/${ISO_FILE_NAME}"

VAR_FILES=(
  "${REPO_ROOT}/overlays/base/packer/common.auto.pkrvars.hcl"
  "${REPO_ROOT}/overlays/base/packer/ubuntu.auto.pkrvars.hcl"
  "${REPO_ROOT}/overlays/base/packer/network.auto.pkrvars.hcl"
  "${REPO_ROOT}/overlays/base/packer/linux-storage.auto.pkrvars.hcl"
)

if [[ -n "${HAPROXY_PACKER_OVERRIDE_FILE:-}" && -f "${REPO_ROOT}/${HAPROXY_PACKER_OVERRIDE_FILE}" ]]; then
  VAR_FILES+=("${REPO_ROOT}/${HAPROXY_PACKER_OVERRIDE_FILE}")
fi

log_info "Pre-check: host/datacenter and ISO"

if [[ -n "${PKR_VAR_vsphere_host:-}" ]]; then
  if ! govc find / -type h | grep -F "/${PKR_VAR_vsphere_host}" >/dev/null; then
    die "Host ${PKR_VAR_vsphere_host} not found in ESXi/vSphere inventory"
  fi
fi

if [[ -n "${PKR_VAR_vsphere_datacenter:-}" ]]; then
  if ! govc find / -type d | grep -F "/${PKR_VAR_vsphere_datacenter}" >/dev/null; then
    die "Datacenter ${PKR_VAR_vsphere_datacenter} not found"
  fi
fi

if ! govc datastore.ls "${ISO_REMOTE_PATH}" >/dev/null 2>&1; then
  log_warn "ISO not found in datastore: ${ISO_REMOTE_PATH}"

  if [[ -n "${ISO_LOCAL_PATH:-}" ]]; then
    [[ -f "${ISO_LOCAL_PATH}" ]] || die "ISO_LOCAL_PATH does not exist: ${ISO_LOCAL_PATH}"
    log_info "Uploading local ISO to datastore"
    govc datastore.mkdir -p "${ISO_DATASTORE_PATH}" >/dev/null 2>&1 || true
    govc datastore.upload "${ISO_LOCAL_PATH}" "${ISO_REMOTE_PATH}"
  else
    die "Set ISO_LOCAL_PATH or upload the ISO manually to ${ISO_REMOTE_PATH}"
  fi
fi

log_info "ISO confirmed at [${GOVC_DATASTORE}] ${ISO_REMOTE_PATH}"
log_info "packer init ${PACKER_TEMPLATE_PATH}"
packer init "${PACKER_TEMPLATE_PATH}"

PACKER_VALIDATE_ARGS=(validate)
for vf in "${VAR_FILES[@]}"; do
  PACKER_VALIDATE_ARGS+=(-var-file "${vf}")
done
PACKER_VALIDATE_ARGS+=("${PACKER_TEMPLATE_PATH}")

log_info "packer validate"
packer "${PACKER_VALIDATE_ARGS[@]}"

if [[ "${VALIDATE_ONLY}" == "false" ]]; then
  PACKER_BUILD_ARGS=(build -force)
  for vf in "${VAR_FILES[@]}"; do
    PACKER_BUILD_ARGS+=(-var-file "${vf}")
  done
  PACKER_BUILD_ARGS+=("${PACKER_TEMPLATE_PATH}")

  log_info "packer build"
  packer "${PACKER_BUILD_ARGS[@]}"
fi
