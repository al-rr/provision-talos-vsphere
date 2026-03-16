#!/bin/bash
# @author: Ednil Libanio da Costa Junior
# @date: 28.10.2025
# @description:
set -euo pipefail

# -------- CONFIGURATION ----------
ANSIBLE_USER="${ANSIBLE_USER:-$(whoami)}"
ANSIBLE_HOME="/home/${ANSIBLE_USER}"
VENV_PATH="${ANSIBLE_HOME}/ansible-venv"

# Project directory
ANSIBLE_PROJECT_PATH="${ANSIBLE_PROJECT_PATH:-$(cd "$(dirname "$0")/../ansible" && pwd)}"

# Requirements files
GALAXY_REQUIREMENTS_FILE="${ANSIBLE_PROJECT_PATH}/requirements.yml"
PYTHON_REQUIREMENTS_FILE="${ANSIBLE_PROJECT_PATH}/requirements.txt"

# Install Python dependencies
install_python_requirements() {
  echo "[ansible-controller] Installing Python dependencies..."

  if [ -f "${PYTHON_REQUIREMENTS_FILE}" ]; then
    echo "-> Installing project Python requirements: ${PYTHON_REQUIREMENTS_FILE}"
    sudo -u "${ANSIBLE_USER}" env HOME="${ANSIBLE_HOME}" PATH="${VENV_PATH}/bin:$PATH" \
      "${VENV_PATH}/bin/python" -m pip install --upgrade -r "${PYTHON_REQUIREMENTS_FILE}"
  fi
}

# Install Ansible Galaxy collections and roles
install_galaxy_requirements() {
  if [ -f "${GALAXY_REQUIREMENTS_FILE}" ]; then
    echo "-> Installing collections from ${GALAXY_REQUIREMENTS_FILE}"
    sudo -u "${ANSIBLE_USER}" env HOME="${ANSIBLE_HOME}" PATH="${VENV_PATH}/bin:$PATH" \
      "${VENV_PATH}/bin/ansible-galaxy" collection install -r "${GALAXY_REQUIREMENTS_FILE}" --force
    sudo -u "${ANSIBLE_USER}" env HOME="${ANSIBLE_HOME}" PATH="${VENV_PATH}/bin:$PATH" \
      "${VENV_PATH}/bin/ansible-galaxy" role install -r "${GALAXY_REQUIREMENTS_FILE}" --force
  else
    echo "-> File ${GALAXY_REQUIREMENTS_FILE} not found, skipping..."
  fi
}

# Execution
install_galaxy_requirements
sleep 1
install_python_requirements

echo "Collections and Python dependencies installed successfully!"
