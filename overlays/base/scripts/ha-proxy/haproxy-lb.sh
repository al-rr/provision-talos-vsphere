#!/usr/bin/env bash
# Compatibility wrapper: delegates HAProxy LB actions to infra-gitops module.

set -euo pipefail

usage() {
  cat <<'EOF_USAGE'
Usage: haproxy-lb.sh [action] [options]

Actions:
  validate             Validate LB module prerequisites and resolved values
  configure-vip        Lab orchestration: run-full.sh (provision + configure + hardening + keepalived)
  reconcile-backends   Reconcile HAProxy backends/frontends only
  status               Check HAProxy service/listeners on LB hosts

Compatibility mode:
  If called only with options (no action), defaults to:
    reconcile-backends

Options:
  --env=<name>         Overlay environment name (default: lab)
  --vars-file=<path>   Optional vars file; if omitted uses overlays/<env>/scripts/vars.sh
  --help, -h           Show help

All other arguments are forwarded to infra-gitops/scripts/ha-proxy/haproxy-lb.sh
or to overlays/base/scripts/ha-proxy/run-full.sh for configure-vip.
EOF_USAGE
}

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"
INFRA_GITOPS_ROOT="${INFRA_GITOPS_ROOT:-${REPO_ROOT}/../infra-gitops}"

TARGET_SCRIPT="${INFRA_GITOPS_ROOT}/scripts/ha-proxy/haproxy-lb.sh"
RUN_FULL_SCRIPT="${SCRIPT_DIR}/run-full.sh"

ENV_NAME="lab"
ACTION=""
ARGS=()
HAS_ACTION="false"

if [[ ! -x "${TARGET_SCRIPT}" ]]; then
  echo "[ERROR] Missing executable script: ${TARGET_SCRIPT}" >&2
  echo "[INFO] Set INFRA_GITOPS_ROOT or install module in /home/vagrant/infra-gitops." >&2
  exit 1
fi

if [[ ! -x "${RUN_FULL_SCRIPT}" ]]; then
  echo "[ERROR] Missing executable script: ${RUN_FULL_SCRIPT}" >&2
  exit 1
fi

for arg in "$@"; do
  case "${arg}" in
    -h|--help)
      usage
      exit 0
      ;;
    validate|configure-vip|reconcile-backends|status)
      if [[ "${HAS_ACTION}" == "false" ]]; then
        ACTION="${arg}"
        HAS_ACTION="true"
      else
        ARGS+=("${arg}")
      fi
      ;;
    --env=*)
      ENV_NAME="${arg#*=}"
      ARGS+=("${arg}")
      ;;
    *)
      ARGS+=("${arg}")
      ;;
  esac
done

if [[ "${HAS_ACTION}" == "false" ]]; then
  ACTION="reconcile-backends"
fi

if [[ "${ACTION}" == "configure-vip" ]]; then
  cd "${REPO_ROOT}"
  exec "${RUN_FULL_SCRIPT}" "${ARGS[@]}"
fi

cd "${REPO_ROOT}"
exec "${TARGET_SCRIPT}" "${ACTION}" "${ARGS[@]}"
