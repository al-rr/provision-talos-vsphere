#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

ACTION=""
ENV_NAME="lab"
VARS_FILE=""
LOCAL_VARS_FILE=""
CLUSTER_NAME=""
GENERATED_DIR=""
WORKER_COUNT=""
ADDON_NAME=""
ADDONS_LIST=""
DRY_RUN="false"

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") <action> [options]

Actions:
  generate        Generate Talos configs and rendered patches
  provision       Provision Talos VMs (create)
  apply-config    Apply machine configuration to nodes
  bootstrap       Bootstrap Talos control plane
  apply-cluster-config  Apply mandatory post-bootstrap baseline (for example cilium, longhorn)
  install-addons  Install one addon (via Helm phase wrapper)
  sync-access     Sync local kubectl and talosctl access

Options:
  --env=<env>                     Overlay environment (default: lab)
  --vars-file=<path>              Explicit vars file (env-agnostic mode)
  --bootstrap-vars-file=<path>    Alias of --vars-file
  --local-vars-file=<path>        Optional local overrides file
  --cluster-name=<name>           Cluster name override
  --generated-dir=<path>          Generated output dir override
  --worker-count=<n>              Worker count override (provision only)
  --addons=<list>                 Addon list for apply-cluster-config (CSV/JSON-like)
  --addon=<name>                  Addon name (install-addons only)
  -n, --dry-run                   Print actions without executing
  -h, --help                      Show this help

Examples:
  $(basename "$0") generate --env=lab
  $(basename "$0") provision --vars-file=overlays/lab/scripts/vars.sh
  $(basename "$0") apply-config --cluster-name=talos
  $(basename "$0") bootstrap
  $(basename "$0") apply-cluster-config --addons='[\"cilium\",\"longhorn\"]'
  $(basename "$0") install-addons --addon=cilium
  $(basename "$0") sync-access
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      generate|provision|apply-config|bootstrap|apply-cluster-config|install-addons|sync-access)
        [[ -z "${ACTION}" ]] || die "Action already set: ${ACTION}"
        ACTION="$1"
        shift
        ;;
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --vars-file=*) VARS_FILE="${1#*=}"; shift ;;
      --bootstrap-vars-file=*) VARS_FILE="${1#*=}"; shift ;;
      --local-vars-file=*) LOCAL_VARS_FILE="${1#*=}"; shift ;;
      --cluster-name=*) CLUSTER_NAME="${1#*=}"; shift ;;
      --generated-dir=*) GENERATED_DIR="${1#*=}"; shift ;;
      --worker-count=*) WORKER_COUNT="${1#*=}"; shift ;;
      --addons=*) ADDONS_LIST="${1#*=}"; shift ;;
      --addon=*) ADDON_NAME="${1#*=}"; shift ;;
      -n|--dry-run) DRY_RUN="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done

  [[ -n "${ACTION}" ]] || { usage; die "Action is required."; }
}

run_or_echo() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

main() {
  local -a cmd=()

  parse_args "$@"

  if [[ -n "${VARS_FILE}" ]]; then
    export OVERLAY_VARS_FILE="${VARS_FILE}"
  fi
  if [[ -n "${LOCAL_VARS_FILE}" ]]; then
    export OVERLAY_LOCAL_VARS_FILE="${LOCAL_VARS_FILE}"
  fi

  case "${ACTION}" in
    generate)
      cmd=("${SCRIPT_DIR}/cluster-bootstrap.sh" "--env=${ENV_NAME}" "--mode=generate")
      [[ -n "${CLUSTER_NAME}" ]] && cmd+=("--cluster-name=${CLUSTER_NAME}")
      [[ -n "${GENERATED_DIR}" ]] && cmd+=("--generated-dir=${GENERATED_DIR}")
      [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
      ;;
    provision)
      cmd=("${SCRIPT_DIR}/provision-cluster.sh" "--env=${ENV_NAME}")
      [[ -n "${WORKER_COUNT}" ]] && cmd+=("--worker-count=${WORKER_COUNT}")
      cmd+=("create")
      ;;
    apply-config)
      cmd=("${SCRIPT_DIR}/cluster-bootstrap.sh" "--env=${ENV_NAME}" "--mode=apply")
      [[ -n "${CLUSTER_NAME}" ]] && cmd+=("--cluster-name=${CLUSTER_NAME}")
      [[ -n "${GENERATED_DIR}" ]] && cmd+=("--generated-dir=${GENERATED_DIR}")
      [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
      ;;
    bootstrap)
      cmd=("${SCRIPT_DIR}/cluster-bootstrap.sh" "--env=${ENV_NAME}" "--mode=bootstrap")
      [[ -n "${CLUSTER_NAME}" ]] && cmd+=("--cluster-name=${CLUSTER_NAME}")
      [[ -n "${GENERATED_DIR}" ]] && cmd+=("--generated-dir=${GENERATED_DIR}")
      [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
      ;;
    apply-cluster-config)
      cmd=("${SCRIPT_DIR}/apply-cluster-config.sh" "--env=${ENV_NAME}")
      [[ -n "${CLUSTER_NAME}" ]] && cmd+=("--cluster-name=${CLUSTER_NAME}")
      [[ -n "${ADDONS_LIST}" ]] && cmd+=("--addons=${ADDONS_LIST}")
      [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
      ;;
    install-addons)
      [[ -n "${ADDON_NAME}" ]] || die "--addon is required for install-addons."
      cmd=("${SCRIPT_DIR}/phase-network-bringup.sh" "--env=${ENV_NAME}" "--addon=${ADDON_NAME}")
      [[ -n "${CLUSTER_NAME}" ]] && cmd+=("--cluster-name=${CLUSTER_NAME}")
      [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
      ;;
    sync-access)
      cmd=("${SCRIPT_DIR}/sync-kubectl.sh" "--env=${ENV_NAME}")
      [[ -n "${CLUSTER_NAME}" ]] && cmd+=("--cluster-name=${CLUSTER_NAME}")
      [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
      run_or_echo "${cmd[@]}"

      cmd=("${SCRIPT_DIR}/sync-talosctl.sh" "--env=${ENV_NAME}")
      [[ -n "${CLUSTER_NAME}" ]] && cmd+=("--cluster-name=${CLUSTER_NAME}")
      [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
      ;;
  esac

  run_or_echo "${cmd[@]}"
}

main "$@"
