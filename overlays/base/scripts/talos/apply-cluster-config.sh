#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

ENV_NAME="lab"
CLUSTER_NAME=""
KUBECONFIG_PATH=""
ADDONS_RAW=""
DRY_RUN="false"

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options]

Apply mandatory post-bootstrap baseline configuration for a functional cluster.

Options:
  --env=<env>            Overlay environment (default: lab)
  --cluster-name=<name>  Cluster name override
  --kubeconfig=<path>    Kubeconfig path override
  --addons=<list>        CSV/JSON-like addons order (default: TALOS_CLUSTER_BASELINE_ADDONS or cilium)
  -n, --dry-run          Print actions without executing
  -h, --help             Show help

Examples:
  $(basename "$0") --env=lab
  $(basename "$0") --addons=cilium,longhorn
  $(basename "$0") --addons='["cilium","longhorn"]'
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --cluster-name=*) CLUSTER_NAME="${1#*=}"; shift ;;
      --kubeconfig=*) KUBECONFIG_PATH="${1#*=}"; shift ;;
      --addons=*) ADDONS_RAW="${1#*=}"; shift ;;
      -n|--dry-run) DRY_RUN="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done
}

normalize_csv_list() {
  local raw="$1"
  raw="${raw//[/}"
  raw="${raw//]/}"
  raw="${raw//\"/}"
  raw="${raw// /}"
  printf '%s\n' "${raw}"
}

csv_to_array() {
  local csv="$1"
  [[ -n "${csv}" ]] || return 0
  local IFS=','
  local -a _arr=()
  read -r -a _arr <<<"${csv}"
  printf '%s\n' "${_arr[@]}"
}

run_or_echo() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

contains_addon() {
  local target="$1"
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${target}" ]] && return 0
  done
  return 1
}

main() {
  local baseline_raw=""
  local baseline_csv=""
  local addon=""
  local kubeconfig_file=""
  local -a addons=()
  local -a cmd=()

  parse_args "$@"
  load_overlay_vars "${ENV_NAME}"

  CLUSTER_NAME="${CLUSTER_NAME:-${TALOS_CLUSTER_NAME:-talos}}"
  baseline_raw="${ADDONS_RAW:-${TALOS_CLUSTER_BASELINE_ADDONS:-${TALOS_BASELINE_ADDONS:-cilium}}}"
  baseline_csv="$(normalize_csv_list "${baseline_raw}")"
  mapfile -t addons < <(csv_to_array "${baseline_csv}")
  (( ${#addons[@]} > 0 )) || die "No baseline addons defined."

  if [[ "${TALOS_DISABLE_DEFAULT_CNI:-false}" == "true" ]]; then
    contains_addon "cilium" "${addons[@]}" || \
      die "TALOS_DISABLE_DEFAULT_CNI=true requires cilium in baseline addons."
  fi

  kubeconfig_file="${KUBECONFIG_PATH:-overlays/${ENV_NAME}/talos/${CLUSTER_NAME}/generated/kubeconfig}"

  log_info "Applying cluster baseline configuration (post-bootstrap): ${addons[*]}"

  for addon in "${addons[@]}"; do
    [[ -n "${addon}" ]] || continue
    cmd=(
      "${SCRIPT_DIR}/phase-network-bringup.sh"
      "--env=${ENV_NAME}"
      "--cluster-name=${CLUSTER_NAME}"
      "--addon=${addon}"
      "--kubeconfig=${kubeconfig_file}"
    )
    [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
    run_or_echo "${cmd[@]}"
  done

  log_info "Cluster baseline configuration completed."
}

main "$@"
