#!/bin/bash
# @author: Ednil Libanio
# @date: 07-11-2025
# @description:
# ------------------------------------------------------------------------------
# Provision an Ansible Controller (production-ready) on Oracle Linux 9
# - create ansible user (if not exists)
# - install Python
# - create virtualenv and set permissions
# - setup SSH keys and SSH config for ansible user
# - setup sudoers for ansible user
# - enable EPEL repository
# - install pip/setuptools/wheel in venv
# ------------------------------------------------------------------------------

set -euo pipefail

# -------- Configurations ----------
ANSIBLE_USER="${ANSIBLE_USER:-$(whoami)}"
ANSIBLE_HOME=$(eval echo "~$ANSIBLE_USER")
PYTHON_PKG="python3.13"
PYTHON_BIN="/usr/bin/${PYTHON_PKG}"
VENV_PATH="${ANSIBLE_HOME}/ansible-venv"
SSH_KEY_TYPE="ed25519"
ANSIBLE_PROJECT_PATH="${ANSIBLE_PROJECT_PATH:-$(cd "$(dirname "$0")/../ansible" && pwd)}"
PYTHON_REQUIREMENTS_FILE="${ANSIBLE_PROJECT_PATH}/requirements.txt"
SUDOERS_FILE="/etc/sudoers.d/${ANSIBLE_USER}"

create_user_ansible() {
  echo "[ansible-controller] ### Create user '${ANSIBLE_USER}' if missing"

  if ! id -u "$ANSIBLE_USER" >/dev/null 2>&1; then
    echo "-> Creating user '$ANSIBLE_USER'..."
    sudo useradd -m -U -s /bin/bash "$ANSIBLE_USER"
    sudo chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "$ANSIBLE_HOME"

    if [ ! -f "${SUDOERS_FILE}" ]; then
      echo "-> Creating sudoers entry for ${ANSIBLE_USER} at ${SUDOERS_FILE}..."
      echo "${ANSIBLE_USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee "${SUDOERS_FILE}" >/dev/null
      sudo chmod 0440 "${SUDOERS_FILE}"
    fi
  else
    echo "-> User '${ANSIBLE_USER}' already exists - nothing to do."
  fi

  create_ssh_key
  echo "User '${ANSIBLE_USER}' configured with sudo and SSH."
}

install_epel_and_dependencies() {
  echo "[ansible-controller] ### Update metadata and ensure EPEL"
  if ! rpm -q --quiet oracle-epel-release-el9; then
    echo "-> Enabling oracle-epel-release-el9..."
    sudo dnf makecache
    sudo dnf -y update
    sudo dnf install -y oracle-epel-release-el9
  fi

  sudo dnf install -y git curl wget dnf-utils yum-utils sshpass
}

create_ssh_key() {
  echo "-> Ensuring SSH structure for ${ANSIBLE_USER}..."

  SSH_DIR="${ANSIBLE_HOME}/.ssh"
  KEY_PATH="${SSH_DIR}/id_${SSH_KEY_TYPE}"

  sudo -u "${ANSIBLE_USER}" mkdir -p "${SSH_DIR}"
  sudo chmod 700 "${SSH_DIR}"

  if ! sudo -u "${ANSIBLE_USER}" test -f "${KEY_PATH}"; then
    echo "-> Generating SSH key (${SSH_KEY_TYPE}) for ${ANSIBLE_USER}..."
    sudo -u "${ANSIBLE_USER}" ssh-keygen -t "${SSH_KEY_TYPE}" -N "" -f "${KEY_PATH}" -C "${ANSIBLE_USER}@$(hostname)" >/dev/null

    chmod 600 "${SSH_DIR}/id_${SSH_KEY_TYPE}"
    chmod 644 "${SSH_DIR}/id_${SSH_KEY_TYPE}.pub"
  fi

  SSH_CONFIG_FILE="${SSH_DIR}/config"
  if ! sudo -u "${ANSIBLE_USER}" test -f "${SSH_CONFIG_FILE}"; then
    echo "-> Creating SSH config file..."
    sudo -u "${ANSIBLE_USER}" tee "${SSH_CONFIG_FILE}" >/dev/null <<'EOF'
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
  LogLevel=ERROR
EOF
    sudo chmod 600 "${SSH_CONFIG_FILE}"
  fi
}

install_python() {
  echo "[ansible-controller] ### Installing Python ${PYTHON_PKG} if missing"

  echo "-> Installing Python ${PYTHON_PKG} and dependencies..."
  sudo dnf install -y "$PYTHON_PKG"

  if [ ! -x "$PYTHON_BIN" ]; then
    echo "[ansible-controller ERROR] Python ${PYTHON_PKG} not found at ${PYTHON_BIN}."
    exit 1
  fi

  echo "Python installed: $PYTHON_BIN"
}

create_venv() {
  echo "[ansible-controller] INFO: Creating virtualenv at ${VENV_PATH}"

  if [ -z "${PYTHON_BIN:-}" ]; then
    echo "[ansible-controller] ERROR: PYTHON_BIN not set. Run install_python before create_venv."
    return 1
  fi

  sudo dnf install -y python3-venv python3-pip >/dev/null 2>&1 || true

  if ! sudo -u "${ANSIBLE_USER}" test -d "${VENV_PATH}"; then
    echo "-> Creating virtualenv with ${PYTHON_BIN}..."
    if sudo -u "${ANSIBLE_USER}" "${PYTHON_BIN}" -m venv --upgrade-deps "${VENV_PATH}" >/dev/null 2>&1; then
      echo "-> venv created (with --upgrade-deps)."
    else
      echo "-> venv created (fallback). Ensuring pip with ensurepip..."
      sudo -u "${ANSIBLE_USER}" "${PYTHON_BIN}" -m venv "${VENV_PATH}"
      if ! sudo -u "${ANSIBLE_USER}" "${VENV_PATH}/bin/python" -m pip --version >/dev/null 2>&1; then
        echo "-> Installing pip in venv via ensurepip..."
        sudo -u "${ANSIBLE_USER}" "${VENV_PATH}/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
      fi
    fi
  fi

  sudo chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "${VENV_PATH}"
  sudo chmod -R u+rwX "${VENV_PATH}"
}

install_ansible() {
  echo "[ansible-controller] ### Installing/updating Ansible in venv"

  if [ ! -x "${VENV_PATH}/bin/python" ]; then
    echo "Python in venv not found at ${VENV_PATH}/bin/python"
    return 1
  fi

  echo "-> Updating setuptools/wheel..."
  sudo -u "${ANSIBLE_USER}" "${VENV_PATH}/bin/python" -m pip install --upgrade setuptools wheel >/dev/null

  echo "-> Installing Ansible dependencies from requirements.txt..."
  if [ -f "${PYTHON_REQUIREMENTS_FILE}" ]; then
    echo "-> Installing project Python requirements: ${PYTHON_REQUIREMENTS_FILE}"
    sudo -u "${ANSIBLE_USER}" env HOME="${ANSIBLE_HOME}" PATH="${VENV_PATH}/bin:$PATH" \
      "${VENV_PATH}/bin/python" -m pip install --upgrade -r "${PYTHON_REQUIREMENTS_FILE}"
  else
    echo "No requirements.txt found, installing default ansible package"
    sudo -u "${ANSIBLE_USER}" "${VENV_PATH}/bin/python" -m pip install ansible >/dev/null
  fi

  echo "-> Verifying Ansible installation:"
  sudo -u "${ANSIBLE_USER}" "${VENV_PATH}/bin/ansible" --version || true

  sudo chown -R "${ANSIBLE_USER}:${ANSIBLE_USER}" "${VENV_PATH}"
  echo "Ansible installed/updated in ${ANSIBLE_USER} venv"
}

setup() {
  echo "===== Provision Ansible Controller (Oracle Linux 9) ====="
  install_epel_and_dependencies
  install_python
  create_user_ansible
  create_venv
  install_ansible
}

setup "$@"
echo "====================================================="
echo "Ansible Controller installed successfully"
echo "====================================================="
