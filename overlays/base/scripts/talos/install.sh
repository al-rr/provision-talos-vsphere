#!/usr/bin/env bash
# Compatibility wrapper: delegates talosctl install lifecycle to infra-gitops module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"
INFRA_GITOPS_ROOT="${INFRA_GITOPS_ROOT:-${REPO_ROOT}/../infra-gitops}"
TARGET_SCRIPT="${INFRA_GITOPS_ROOT}/scripts/talos/install.sh"

if [[ ! -x "${TARGET_SCRIPT}" ]]; then
  echo "[ERROR] Missing executable script: ${TARGET_SCRIPT}" >&2
  echo "[INFO] Set INFRA_GITOPS_ROOT or install module in /home/vagrant/infra-gitops." >&2
  exit 1
fi

exec "${TARGET_SCRIPT}" "$@"
