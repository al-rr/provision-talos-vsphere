#!/usr/bin/env bash
# @file cluster-toolchain.sh
# @brief Canonical day-1 entrypoint: run actions using external talos-toolchain.
# @description
#   Thin wrapper that forwards all arguments to talos-toolchain cluster.sh.
#   This is the active, canonical day-1 entrypoint for this repository;
#   the local cluster.sh is a deprecated compatibility shim for it.
#
# @arg action string Any action supported by toolchain cluster.sh.
# @arg options string Any options supported by toolchain cluster.sh.
# @arg --toolchain-dir path Optional talos-toolchain repository dir override.
# @flag --help,-h Show usage information.
# @example
#   ./cluster-toolchain.sh create-project --project-dir=overlays/lab/talos/talos-dev
# @example
#   ./cluster-toolchain.sh generate --project-dir=overlays/lab/talos/talos-dev
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

TOOLCHAIN_DIR="${TALOS_TOOLCHAIN_DIR:-${REPO_ROOT}/../talos-toolchain}"

upsert_export_var() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped_value=""
  local tmp_file=""

  escaped_value="${value//\\/\\\\}"
  escaped_value="${escaped_value//\"/\\\"}"
  tmp_file="$(mktemp)"

  if grep -qE "^export ${key}=" "${file}"; then
    awk -v k="${key}" -v v="${escaped_value}" '
      BEGIN { done=0 }
      $0 ~ "^export " k "=" {
        print "export " k "=\"" v "\""
        done=1
        next
      }
      { print }
      END {
        if (!done) print "export " k "=\"" v "\""
      }
    ' "${file}" > "${tmp_file}"
  else
    cat "${file}" > "${tmp_file}"
    printf '\nexport %s="%s"\n' "${key}" "${escaped_value}" >> "${tmp_file}"
  fi

  mv "${tmp_file}" "${file}"
}

patch_project_vars_for_lab_defaults() {
  local project_dir="$1"
  local project_abs=""
  local vars_file=""

  if [[ "${project_dir}" = /* ]]; then
    project_abs="${project_dir}"
  else
    project_abs="${REPO_ROOT}/${project_dir}"
  fi

  vars_file="${project_abs}/vars.sh"
  [[ -f "${vars_file}" ]] || return 0

  if ! grep -q '^LAB_REPO_ROOT=' "${vars_file}"; then
    local tmp_file=""
    tmp_file="$(mktemp)"
    awk '
      { print }
      /^PROJECT_DIR=/ && !done {
        print "LAB_REPO_ROOT=\"$(cd \"${PROJECT_DIR}/../../../..\" && pwd)\""
        print "WORKSPACE_ROOT=\"$(dirname \"${LAB_REPO_ROOT}\")\""
        done=1
      }
    ' "${vars_file}" > "${tmp_file}"
    mv "${tmp_file}" "${vars_file}"
  fi

  upsert_export_var "${vars_file}" "VSPHERE_ENDPOINT" "192.168.0.233"
  upsert_export_var "${vars_file}" "VSPHERE_USERNAME" "root"
  upsert_export_var "${vars_file}" "VSPHERE_PASSWORD" "CHANGE_ME"
  upsert_export_var "${vars_file}" "VSPHERE_INSECURE_CONNECTION" "true"
  upsert_export_var "${vars_file}" "VSPHERE_DATASTORE" "DATASTORE_02"
  upsert_export_var "${vars_file}" "VSPHERE_NETWORK" "VM Network"
  upsert_export_var "${vars_file}" "VSPHERE_FOLDER" ""
  upsert_export_var "${vars_file}" "VSPHERE_RESOURCE_POOL" ""
  upsert_export_var "${vars_file}" "SSH_USER" "vagrant"
  upsert_export_var "${vars_file}" "HAPROXY_SSH_USER" "vagrant"
  upsert_export_var "${vars_file}" "HAPROXY_NODE_1_NAME" "talos-lb-1"
  upsert_export_var "${vars_file}" "HAPROXY_NODE_1_IP" "192.168.0.31"
  upsert_export_var "${vars_file}" "HAPROXY_NODE_2_NAME" "talos-lb-2"
  upsert_export_var "${vars_file}" "HAPROXY_NODE_2_IP" "192.168.0.32"
  upsert_export_var "${vars_file}" "TALOS_LOAD_BALANCER_RECONCILE_SCRIPT" "${REPO_ROOT}/overlays/base/scripts/ha-proxy/haproxy-lb.sh"
  upsert_export_var "${vars_file}" "TALOS_DNS_SYNC_REQUIRED" "true"
  upsert_export_var "${vars_file}" "TALOS_DNS_REGISTER_SCRIPT" "${REPO_ROOT}/overlays/base/scripts/dns/register-hosts.sh"
  upsert_export_var "${vars_file}" "TALOS_DNS_UNREGISTER_SCRIPT" "${REPO_ROOT}/overlays/base/scripts/dns/unregister-hosts.sh"
  upsert_export_var "${vars_file}" "TALOS_POST_BOOTSTRAP_HELM_SOURCE_PATH" "\${WORKSPACE_ROOT}/talos-vsphere-gitops/environments/lab/helm"
}

usage() {
  cat <<'EOF_USAGE'
Usage: cluster-toolchain.sh [--toolchain-dir=<path>] <action> [options]

Forwards all arguments to:
  <toolchain-dir>/scripts/talos/cluster.sh

Options:
  --toolchain-dir=<path>   Override talos-toolchain repository location
  -h, --help               Show help
EOF_USAGE
}

ARGS=()
ACTION=""
PROJECT_DIR_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --toolchain-dir=*) TOOLCHAIN_DIR="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ -z "${ACTION}" ]]; then
        ACTION="$1"
      fi
      if [[ "$1" == --project-dir=* ]]; then
        PROJECT_DIR_ARG="${1#*=}"
      fi
      ARGS+=("$1")
      shift
      ;;
  esac
done

[[ ${#ARGS[@]} -gt 0 ]] || { usage; exit 1; }

TOOLCHAIN_DIR="$(cd "${TOOLCHAIN_DIR}" && pwd)"
TARGET_SCRIPT="${TOOLCHAIN_DIR}/scripts/talos/cluster.sh"
[[ -x "${TARGET_SCRIPT}" ]] || {
  echo "[ERROR] Toolchain cluster.sh not found or not executable: ${TARGET_SCRIPT}" >&2
  echo "[INFO] Set TALOS_TOOLCHAIN_DIR or pass --toolchain-dir=<path>." >&2
  exit 1
}

"${TARGET_SCRIPT}" "${ARGS[@]}"

if [[ "${ACTION}" == "create-project" && -n "${PROJECT_DIR_ARG}" ]]; then
  patch_project_vars_for_lab_defaults "${PROJECT_DIR_ARG}"
fi
