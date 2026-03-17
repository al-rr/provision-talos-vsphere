#!/usr/bin/env bash
# @describe Run the active HAProxy Ansible playbook from the lab controller virtualenv.
# @env ANSIBLE_CONFIG_FILE Absolute path to overlays/base/ansible/ansible.cfg.
# @env ANSIBLE_INVENTORY_FILE Absolute path to the HAProxy inventory file.
# @env ANSIBLE_PLAYBOOK_FILE Absolute path to the HAProxy playbook file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BASE_FUNCTIONS="${REPO_ROOT}/overlays/base/scripts/functions.sh"

# shellcheck source=/dev/null
source "${BASE_FUNCTIONS}"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/vars.sh"

validate_environment() {
  require_controller_paths || die "Unable to resolve controller paths from the synced repository."
  ensure_venv_exists || die "The controller virtualenv is missing."
  ensure_file_exists "${ANSIBLE_CONFIG_FILE}" || die "Ansible config file is missing."
  ensure_file_exists "${ANSIBLE_INVENTORY_FILE}" || die "Ansible inventory file is missing."
  ensure_file_exists "${ANSIBLE_PLAYBOOK_FILE}" || die "Ansible playbook file is missing."

  if [[ ! -x "${VENV_BIN_PATH}/ansible-playbook" ]]; then
    die "ansible-playbook is not available in ${VENV_BIN_PATH}. Run install-collections.sh first."
  fi
}

run_playbook() {
  export ANSIBLE_CONFIG="${ANSIBLE_CONFIG_FILE}"
  export ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY_FILE}"

  log_info "Running playbook ${ANSIBLE_PLAYBOOK_FILE}"
  log_info "Using inventory ${ANSIBLE_INVENTORY_FILE}"

  cd "${ANSIBLE_WORKSPACE_PATH}"
  run_as_ansible "${VENV_BIN_PATH}/ansible-playbook" "${ANSIBLE_PLAYBOOK_FILE}" -i "${ANSIBLE_INVENTORY_FILE}" "$@"
}

main() {
  validate_environment
  run_playbook "$@"
}

main "$@"
