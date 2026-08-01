#!/usr/bin/env bash
set -euo pipefail

# @describe Compatibility wrapper for HAProxy image build using infra-gitops/packer.
# @option --env Target overlay environment. Defaults to prod.
# @option --profile vSphere-ISO profile. Defaults to ubuntu-24.
# @option --infra-gitops-dir Path to infra-gitops repository root. Defaults to /home/vagrant/infra-gitops.
# @option --infra-packer-dir Path to canonical packer module. Overrides --infra-gitops-dir/packer.
# @flag --validate-only Only run init+validate through the canonical builder.

ENV_NAME="prod"
PROFILE_NAME="ubuntu-24"
VALIDATE_ONLY="false"
INFRA_GITOPS_DIR="${INFRA_GITOPS_DIR:-/home/vagrant/infra-gitops}"
INFRA_PACKER_DIR="${INFRA_PACKER_DIR:-}"
PASSTHROUGH_ARGS=()

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --env=<name>         Overlay environment (default: prod)
  --profile=<name>     vSphere-ISO profile (default: ubuntu-24)
  --infra-gitops-dir   Path to infra-gitops root (default: /home/vagrant/infra-gitops)
  --infra-packer-dir   Path to infra-gitops packer module (overrides infra-gitops-dir/packer)
  --validate-only      Run init+validate only
  -h, --help           Show this help

All unknown options are forwarded to:
  infra-gitops/packer/build.sh
EOF
}

for arg in "$@"; do
  case "$arg" in
    --env=*)
      ENV_NAME="${arg#*=}"
      ;;
    --profile=*)
      PROFILE_NAME="${arg#*=}"
      ;;
    --infra-gitops-dir=*)
      INFRA_GITOPS_DIR="${arg#*=}"
      ;;
    --infra-packer-dir=*)
      INFRA_PACKER_DIR="${arg#*=}"
      ;;
    --validate-only)
      VALIDATE_ONLY="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      PASSTHROUGH_ARGS+=("${arg}")
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
if [[ -n "${INFRA_PACKER_DIR}" ]]; then
  PACKER_MODULE_DIR="${INFRA_PACKER_DIR}"
else
  PACKER_MODULE_DIR="${INFRA_GITOPS_DIR}/packer"
fi
PACKER_BUILD_SCRIPT="${PACKER_MODULE_DIR}/build.sh"
ACTION_NAME="build"

[[ -x "${PACKER_BUILD_SCRIPT}" ]] || {
  echo "[ERROR] Missing executable script: ${PACKER_BUILD_SCRIPT}" >&2
  exit 1
}

if [[ "${VALIDATE_ONLY}" == "true" ]]; then
  ACTION_NAME="validate"
fi

# Load overlay vars and export PKR_VAR_* expected by canonical packer module.
# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"
load_overlay_vars "${ENV_NAME}"
export_common_tool_env
export_packer_vars

CMD=(
  "${PACKER_BUILD_SCRIPT}"
  "--builder=vsphere-iso"
  "--profile=${PROFILE_NAME}"
  "--action=${ACTION_NAME}"
)

if [[ -n "${HAPROXY_PACKER_OVERRIDE_FILE:-}" ]]; then
  override_file="${HAPROXY_PACKER_OVERRIDE_FILE}"
  if [[ "${override_file}" != /* ]]; then
    override_file="${REPO_ROOT}/${override_file}"
  fi
  if [[ -f "${override_file}" ]]; then
    CMD+=("--vars-file=${override_file}")
  else
    echo "[WARN] HAPROXY_PACKER_OVERRIDE_FILE not found: ${override_file}" >&2
  fi
fi

CMD+=("${PASSTHROUGH_ARGS[@]}")

exec "${CMD[@]}"
