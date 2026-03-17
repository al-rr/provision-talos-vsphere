#!/usr/bin/env bash
# @describe Install Python dependencies and Ansible Galaxy collections for the lab controller.
# @env PYTHON_REQUIREMENTS_FILE Python requirements file under overlays/base/ansible.
# @env GALAXY_REQUIREMENTS_FILE Galaxy requirements file under overlays/base/ansible.

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
}

install_python_requirements() {
  if [[ ! -f "${PYTHON_REQUIREMENTS_FILE}" ]]; then
    log_warn "Python requirements file not found: ${PYTHON_REQUIREMENTS_FILE}. Skipping pip install."
    return 0
  fi

  log_info "Installing Python dependencies from ${PYTHON_REQUIREMENTS_FILE}"
  run_as_ansible "${VENV_BIN_PATH}/python" -m pip install --upgrade -r "${PYTHON_REQUIREMENTS_FILE}"

  if ! grep -Eq '^[[:space:]]*ansible([[:space:]]|[=<>~!].*)?$' "${PYTHON_REQUIREMENTS_FILE}"; then
    run_as_ansible "${VENV_BIN_PATH}/python" -m pip uninstall -y ansible >/dev/null 2>&1 || true
  fi
}

install_galaxy_requirements() {
  if [[ ! -f "${GALAXY_REQUIREMENTS_FILE}" ]]; then
    log_warn "Galaxy requirements file not found: ${GALAXY_REQUIREMENTS_FILE}. Skipping collection install."
    return 0
  fi

  if ! grep -q '^[[:space:]]*collections:' "${GALAXY_REQUIREMENTS_FILE}"; then
    log_warn "No collections key found in ${GALAXY_REQUIREMENTS_FILE}. Skipping collection install."
    return 0
  fi

  if [[ ! -x "${VENV_BIN_PATH}/ansible-galaxy" ]]; then
    die "ansible-galaxy is not available in ${VENV_BIN_PATH}. Install Python requirements first."
  fi

  log_info "Installing Ansible Galaxy collections from ${GALAXY_REQUIREMENTS_FILE}"
  run_as_ansible "${VENV_BIN_PATH}/ansible-galaxy" collection install -r "${GALAXY_REQUIREMENTS_FILE}" --force
}

main() {
  validate_environment
  install_python_requirements
  install_galaxy_requirements
  log_info "Controller dependencies and collections are installed."
}

main "$@"
