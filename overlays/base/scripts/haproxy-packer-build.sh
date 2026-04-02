#!/usr/bin/env bash
set -euo pipefail

# @describe Compatibility wrapper for HAProxy image build on the canonical vsphere-iso module.
# @option --env Target overlay environment. Defaults to prod.
# @option --profile vSphere-ISO profile. Defaults to ubuntu-24.
# @flag --validate-only Only run init+validate through the canonical builder.

ENV_NAME="prod"
PROFILE_NAME="ubuntu-24"
VALIDATE_ONLY="false"
PASSTHROUGH_ARGS=()

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --env=<name>         Overlay environment (default: prod)
  --profile=<name>     vSphere-ISO profile (default: ubuntu-24)
  --validate-only      Run init+validate only
  -h, --help           Show this help

All unknown options are forwarded to:
  packer/vsphere-iso/build.sh
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
PACKER_VSPHERE_ISO_SCRIPT="${REPO_ROOT}/packer/vsphere-iso/build.sh"
ACTION_NAME="build"

[[ -x "${PACKER_VSPHERE_ISO_SCRIPT}" ]] || {
  echo "[ERROR] Missing executable script: ${PACKER_VSPHERE_ISO_SCRIPT}" >&2
  exit 1
}

if [[ "${VALIDATE_ONLY}" == "true" ]]; then
  ACTION_NAME="validate"
fi

CMD=(
  "${PACKER_VSPHERE_ISO_SCRIPT}"
  "--profile=${PROFILE_NAME}"
  "--env=${ENV_NAME}"
  "--action=${ACTION_NAME}"
)

CMD+=("${PASSTHROUGH_ARGS[@]}")

exec "${CMD[@]}"
