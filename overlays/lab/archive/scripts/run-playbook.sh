#!/bin/bash
# provision-vault.sh
# Runs an Ansible playbook locally inside the VM
# Author: Ednil Libanio da Costa Junior

set -euo pipefail

# -------- CONFIGURATION ----------
ANSIBLE_USER="${ANSIBLE_USER:-$(whoami)}"
ANSIBLE_HOME=$(eval echo "~$ANSIBLE_USER")

# Virtual environment path
export VENV_PATH="${ANSIBLE_HOME}/ansible-venv"
VENV_BIN_PATH="${VENV_PATH}/bin"
VENV_ANSIBLE_PLAYBOOK="${VENV_BIN_PATH}/ansible-playbook"

# Ansible project path
ANSIBLE_PROJECT_PATH="${ANSIBLE_PROJECT_PATH:-$(cd "$(dirname "$0")/../ansible" && pwd)}"
ANSIBLE_PLAYBOOK_FILE="${ANSIBLE_PLAYBOOK_FILE:-playbook.yml}"

if [[ -z "${DEFAULT_ANSIBLE_CONFIG:-}" ]]; then
  echo "Copying ${ANSIBLE_PROJECT_PATH}/ansible.cfg to ${ANSIBLE_HOME}/.ansible.cfg ..."
  cp "${ANSIBLE_PROJECT_PATH}"/ansible.cfg "${ANSIBLE_HOME}"/.ansible.cfg
  chown "${ANSIBLE_USER}:${ANSIBLE_USER}" "${ANSIBLE_HOME}"/.ansible.cfg
  DEFAULT_ANSIBLE_CONFIG="${ANSIBLE_HOME}/.ansible.cfg"
fi

# Absolute paths ensure Ansible uses the expected files
export ANSIBLE_CONFIG="${DEFAULT_ANSIBLE_CONFIG}"
ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY:-inventory}"

# -------- FUNCTIONS ----------
check_environment() {
  echo "Checking environment..."

  if [[ ! -d "${VENV_PATH}" ]]; then
    echo "Ansible virtualenv not found at ${VENV_PATH}."
    echo "Run first: scripts/install-ansible.sh"
    exit 1
  fi

  echo "Environment check completed successfully."
}

test_playbook() {
  echo "Testing SSH connectivity with host"
  sudo -u "${ANSIBLE_USER}" \
    "${VENV_BIN_PATH}/ansible" hashivault -m ping -vvv -i "${ANSIBLE_INVENTORY}"

  echo "Showing parsed Ansible inventory"
  sudo -u "${ANSIBLE_USER}" \
    "${VENV_BIN_PATH}/ansible-inventory" --list -i "${ANSIBLE_INVENTORY}"
}

run_playbook() {
  echo "Running: sudo -u ${ANSIBLE_USER} ${VENV_ANSIBLE_PLAYBOOK} ${ANSIBLE_PLAYBOOK_FILE} -i ${ANSIBLE_INVENTORY}"
  sleep 2

  cd "${ANSIBLE_PROJECT_PATH}" || exit 1

  sudo -u "${ANSIBLE_USER}" \
    "${VENV_ANSIBLE_PLAYBOOK}" "${ANSIBLE_PLAYBOOK_FILE}" -i "${ANSIBLE_INVENTORY}"
}

# -------- Execution ----------
check_environment
run_playbook
