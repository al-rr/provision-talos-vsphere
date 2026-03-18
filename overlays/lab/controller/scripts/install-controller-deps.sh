#!/usr/bin/env bash
# @describe Install baseline dependencies for the lab controller.
# @description Installs `make` (package manager) and `govc` (via base installer), idempotently.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
GOVC_INSTALL_SCRIPT="${REPO_ROOT}/overlays/base/scripts/govc/install.sh"

install_make() {
  if command -v make >/dev/null 2>&1; then
    echo "[INFO] make already installed."
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    echo "[INFO] Installing make via dnf."
    sudo dnf install -y make >/dev/null
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "[INFO] Installing make via apt."
    sudo apt-get update -y >/dev/null
    sudo apt-get install -y make >/dev/null
    return 0
  fi

  echo "[ERROR] Could not install make: unsupported package manager." >&2
  exit 1
}

install_govc() {
  if [[ ! -x "${GOVC_INSTALL_SCRIPT}" ]]; then
    echo "[ERROR] Missing govc installer: ${GOVC_INSTALL_SCRIPT}" >&2
    exit 1
  fi

  echo "[INFO] Ensuring govc is installed."
  "${GOVC_INSTALL_SCRIPT}"
}

main() {
  install_make
  install_govc
  echo "[INFO] Controller dependencies are ready."
}

main "$@"
