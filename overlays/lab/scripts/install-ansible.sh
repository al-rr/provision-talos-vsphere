#!/usr/bin/env bash
# @describe Install Python and create the Ansible virtualenv for the lab controller.
# @env ANSIBLE_USER Controller user that owns the virtualenv. Defaults to vagrant.
# @env VENV_PATH Target virtualenv path. Defaults to /home/vagrant/venv.
# @env ANSIBLE_TOOLING_PATH Shared Ansible tooling root under overlays/base/ansible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BASE_FUNCTIONS="${REPO_ROOT}/overlays/base/scripts/functions.sh"

# shellcheck source=/dev/null
source "${BASE_FUNCTIONS}"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/vars.sh"

PYTHON_CANDIDATES=("python3.13" "python3.12" "python3.11" "python3.10" "python3")
PYTHON_BIN=""

validate_controller_context() {
  local current_user

  current_user="$(id -un)"
  id -u "${ANSIBLE_USER}" >/dev/null 2>&1 || die "Controller user does not exist: ${ANSIBLE_USER}"

  if [[ "${current_user}" != "${ANSIBLE_USER}" && "${current_user}" != "root" ]]; then
    die "Run this bootstrap as ${ANSIBLE_USER} or root. Current user: ${current_user}"
  fi

  if [[ "${ANSIBLE_USER}" != "vagrant" ]]; then
    log_warn "This lab controller bootstrap is optimized for ANSIBLE_USER=vagrant."
  fi

  require_controller_paths || die "Unable to resolve controller paths from the synced repository."
}

install_epel() {
  log_info "Ensuring Oracle Linux EPEL is available"

  if ! rpm -q --quiet oracle-epel-release-el9; then
    sudo dnf install -y oracle-epel-release-el9 >/dev/null
    sudo dnf makecache >/dev/null
  fi
}

install_python() {
  local candidate

  log_info "Installing Python for the controller"

  for candidate in "${PYTHON_CANDIDATES[@]}"; do
    if sudo dnf install -y "${candidate}" python3-pip >/dev/null 2>&1; then
      PYTHON_BIN="$(command -v "${candidate}" || true)"
      if [[ -x "${PYTHON_BIN}" ]]; then
        log_info "Using Python interpreter: ${PYTHON_BIN}"
        return 0
      fi
    fi
  done

  die "Could not install a supported Python interpreter."
}

create_venv() {
  log_info "Ensuring virtualenv exists at ${VENV_PATH}"

  if [[ ! -x "${PYTHON_BIN}" ]]; then
    die "PYTHON_BIN is not set. Install Python before creating the virtualenv."
  fi

  if [[ ! -x "${VENV_BIN_PATH}/python" ]]; then
    run_as_ansible "${PYTHON_BIN}" -m venv "${VENV_PATH}"
  fi

  if [[ ! -x "${VENV_BIN_PATH}/pip" ]]; then
    run_as_ansible "${VENV_BIN_PATH}/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
  fi

  sudo chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "${VENV_PATH}"
  sudo chmod -R u+rwX "${VENV_PATH}"
}

prepare_venv_pip_tooling() {
  log_info "Upgrading pip, setuptools, and wheel in ${VENV_PATH}"

  ensure_venv_exists || die "The controller virtualenv is missing."
  run_as_ansible "${VENV_BIN_PATH}/python" -m pip install --upgrade pip setuptools wheel >/dev/null
}

ensure_ssh_assets() {
  local ssh_dir="${ANSIBLE_HOME}/.ssh"
  local ssh_config_file="${ssh_dir}/config"
  local temp_config

  log_info "Ensuring SSH key material for ${ANSIBLE_USER}"

  sudo install -d -m 700 -o "${ANSIBLE_USER}" -g "${ANSIBLE_USER}" "${ssh_dir}"

  if [[ ! -f "${ANSIBLE_PRIVATE_KEY_FILE}" ]]; then
    run_as_ansible ssh-keygen -t "${SSH_KEY_TYPE}" -N "" -f "${ANSIBLE_PRIVATE_KEY_FILE}" -C "${ANSIBLE_USER}@$(hostname)" >/dev/null
  fi

  sudo chmod 600 "${ANSIBLE_PRIVATE_KEY_FILE}"
  sudo chmod 644 "${ANSIBLE_PRIVATE_KEY_FILE}.pub"

  if [[ ! -f "${ssh_config_file}" ]]; then
    temp_config="$(mktemp)"
    cat >"${temp_config}" <<'EOF'
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
  LogLevel ERROR
EOF
    sudo install -m 600 -o "${ANSIBLE_USER}" -g "${ANSIBLE_USER}" "${temp_config}" "${ssh_config_file}"
    rm -f "${temp_config}"
  fi
}

main() {
  log_info "Bootstrapping the lab controller Ansible virtualenv"
  validate_controller_context
  install_epel
  install_python
  create_venv
  prepare_venv_pip_tooling
  ensure_ssh_assets
  log_info "Bootstrap completed. Next step: overlays/lab/scripts/install-collections.sh"
}

main "$@"
