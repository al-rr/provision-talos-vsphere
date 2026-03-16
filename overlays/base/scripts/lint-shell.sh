#!/usr/bin/env bash
set -euo pipefail

# @describe Run shell validation for base scripts and a selected overlay.
# @option --env Target overlay environment. Defaults to prod.

ENV_NAME="prod"

for arg in "$@"; do
  case "$arg" in
    --env=*)
      ENV_NAME="${arg#*=}"
      ;;
    *)
      echo "Usage: $0 [--env=<env>]"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

mapfile -t FILES < <(find "${REPO_ROOT}/overlays/base" "${REPO_ROOT}/overlays/${ENV_NAME}" -type f -name "*.sh" | sort)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "[WARN] No shell files found for overlays/base and overlays/${ENV_NAME}"
  exit 0
fi

for f in "${FILES[@]}"; do
  echo "[INFO] bash -n ${f}"
  bash -n "${f}"
done
