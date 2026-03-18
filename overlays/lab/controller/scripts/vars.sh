#!/usr/bin/env bash
# @file vars.sh
# @description Controller-specific variables and helper functions for lab bootstrap scripts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
LAB_VARS="${REPO_ROOT}/overlays/lab/scripts/vars.sh"

if [[ ! -f "${LAB_VARS}" ]]; then
  echo "[ERROR] Missing lab vars file: ${LAB_VARS}" >&2
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    exit 1
  fi
  return 1
fi

# shellcheck source=/dev/null
source "${LAB_VARS}"

resolve_path() {
  local base_dir="${1}"
  local path_value="${2}"

  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
  else
    printf '%s\n' "${base_dir}/${path_value}"
  fi
}

default_home_for_user() {
  local user_name="${1}"
  local home_dir=""

  if command -v getent >/dev/null 2>&1; then
    home_dir="$(getent passwd "${user_name}" | cut -d: -f6 || true)"
  fi

  if [[ -z "${home_dir}" ]]; then
    home_dir="$(eval echo "~${user_name}")"
  fi

  printf '%s\n' "${home_dir}"
}

export ANSIBLE_USER="${ANSIBLE_USER:-vagrant}"
export ANSIBLE_HOME="${ANSIBLE_HOME:-$(default_home_for_user "${ANSIBLE_USER}")}"
export VENV_PATH="${VENV_PATH:-${ANSIBLE_HOME}/venv}"
export VENV_BIN_PATH="${VENV_PATH}/bin"
export SSH_KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"
export ANSIBLE_PRIVATE_KEY_FILE="${ANSIBLE_PRIVATE_KEY_FILE:-${ANSIBLE_HOME}/.ssh/id_${SSH_KEY_TYPE}}"

export ANSIBLE_TOOLING_PATH="$(resolve_path "${REPO_ROOT}" "${ANSIBLE_TOOLING_PATH:-overlays/base/ansible}")"
export ANSIBLE_WORKSPACE_PATH="$(resolve_path "${REPO_ROOT}" "${ANSIBLE_WORKSPACE_PATH:-${ANSIBLE_TOOLING_PATH}/haproxy}")"
export ANSIBLE_CONFIG_FILE="$(resolve_path "${ANSIBLE_TOOLING_PATH}" "${ANSIBLE_CONFIG_FILE:-ansible.cfg}")"
export ANSIBLE_INVENTORY_FILE="$(resolve_path "${ANSIBLE_WORKSPACE_PATH}" "${ANSIBLE_INVENTORY_FILE:-inventory}")"
export ANSIBLE_PLAYBOOK_FILE="$(resolve_path "${ANSIBLE_WORKSPACE_PATH}" "${ANSIBLE_PLAYBOOK_FILE:-playbooks/provision_haproxy.yml}")"
export PYTHON_REQUIREMENTS_FILE="$(resolve_path "${ANSIBLE_TOOLING_PATH}" "${PYTHON_REQUIREMENTS_FILE:-requirements.txt}")"
export GALAXY_REQUIREMENTS_FILE="$(resolve_path "${ANSIBLE_TOOLING_PATH}" "${GALAXY_REQUIREMENTS_FILE:-requirements.yml}")"
export ANSIBLE_PROJECT_PATH="${ANSIBLE_PROJECT_PATH:-${ANSIBLE_WORKSPACE_PATH}}"

run_as_ansible() {
  if [[ "$(id -un)" == "${ANSIBLE_USER}" ]]; then
    env HOME="${ANSIBLE_HOME}" PATH="${VENV_BIN_PATH}:$PATH" "$@"
  else
    sudo -u "${ANSIBLE_USER}" env HOME="${ANSIBLE_HOME}" PATH="${VENV_BIN_PATH}:$PATH" "$@"
  fi
}

ensure_venv_exists() {
  if [[ ! -x "${VENV_BIN_PATH}/python" ]]; then
    echo "[ERROR] Virtualenv not found at ${VENV_PATH}." >&2
    echo "Run overlays/lab/controller/scripts/install-ansible.sh first." >&2
    return 1
  fi
}

ensure_file_exists() {
  local path_value="${1}"

  if [[ ! -f "${path_value}" ]]; then
    echo "[ERROR] Required file not found: ${path_value}" >&2
    return 1
  fi
}

ensure_directory_exists() {
  local path_value="${1}"

  if [[ ! -d "${path_value}" ]]; then
    echo "[ERROR] Required directory not found: ${path_value}" >&2
    return 1
  fi
}

require_controller_paths() {
  ensure_directory_exists "${ANSIBLE_TOOLING_PATH}" &&
    ensure_directory_exists "${ANSIBLE_WORKSPACE_PATH}" &&
    ensure_file_exists "${ANSIBLE_CONFIG_FILE}" &&
    ensure_file_exists "${ANSIBLE_INVENTORY_FILE}" &&
    ensure_file_exists "${ANSIBLE_PLAYBOOK_FILE}"
}
