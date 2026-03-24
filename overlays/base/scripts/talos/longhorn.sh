#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Longhorn chart is currently distributed via Helm repository.
helm repo add longhorn https://charts.longhorn.io --force-update >/dev/null
helm repo update longhorn >/dev/null

exec "${SCRIPT_DIR}/phase-network-bringup.sh" --addon=longhorn "$@"
