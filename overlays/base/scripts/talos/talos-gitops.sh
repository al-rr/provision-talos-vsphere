#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

ACTION=""
PROJECT_DIR=""
ARGOCD_MANIFEST_DIR=""
ADDONS_RAW=""
KUBECONFIG_PATH=""
DRY_RUN="false"

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") <action> [options]

Actions:
  install-platform-helm        Install/update all helm addons from argocd-manifest-dir/helm
  deploy-argocd-root-app       Apply Argo CD root app manifest
  configure-talos-cluster-tools Install platform helm and deploy Argo CD root app

Options:
  --project-dir=<path>          Cluster project dir (required)
  --argocd-manifest-dir=<path>  Directory that contains argocd/ and helm/ (required)
  --addons=<list>               CSV/JSON-like addon list override for install-platform-helm
  --kubeconfig=<path>           Kubeconfig path override (default: <project>/generated/kubeconfig)
  -n, --dry-run                 Print actions without executing
  -h, --help                    Show help

Examples:
  $(basename "$0") install-platform-helm --project-dir=overlays/lab/talos/talos-dev --argocd-manifest-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
  $(basename "$0") deploy-argocd-root-app --project-dir=overlays/lab/talos/talos-dev --argocd-manifest-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
  $(basename "$0") configure-talos-cluster-tools --project-dir=overlays/lab/talos/talos-dev --argocd-manifest-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      install-platform-helm|deploy-argocd-root-app|configure-talos-cluster-tools)
        [[ -z "${ACTION}" ]] || die "Action already set: ${ACTION}"
        ACTION="$1"
        shift
        ;;
      --project-dir=*) PROJECT_DIR="${1#*=}"; shift ;;
      --argocd-manifest-dir=*) ARGOCD_MANIFEST_DIR="${1#*=}"; shift ;;
      --addons=*) ADDONS_RAW="${1#*=}"; shift ;;
      --kubeconfig=*) KUBECONFIG_PATH="${1#*=}"; shift ;;
      -n|--dry-run) DRY_RUN="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done

  [[ -n "${ACTION}" ]] || { usage; die "Action is required."; }
}

resolve_repo_path() {
  local path_value="$1"
  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
  else
    printf '%s\n' "${REPO_ROOT}/${path_value}"
  fi
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

require_dir_path() {
  local dir_path="$1"
  [[ -d "${dir_path}" ]] || die "Required directory not found: ${dir_path}"
}

sync_helm_manifests() {
  local source_helm_dir="$1"
  local target_helm_dir="$2"

  require_dir_path "${source_helm_dir}"

  run_or_echo mkdir -p "${target_helm_dir}"
  if command -v rsync >/dev/null 2>&1; then
    run_or_echo rsync -a --delete "${source_helm_dir}/" "${target_helm_dir}/"
  else
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] rm -rf ${target_helm_dir}/* && cp -a ${source_helm_dir}/. ${target_helm_dir}/"
    else
      find "${target_helm_dir}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
      cp -a "${source_helm_dir}/." "${target_helm_dir}/"
    fi
  fi
}

resolve_addons() {
  local helm_dir="$1"
  local addons_csv=""
  local -a addons=()

  if [[ -n "${ADDONS_RAW}" ]]; then
    addons_csv="$(normalize_csv_list "${ADDONS_RAW}")"
    mapfile -t addons < <(csv_to_array "${addons_csv}")
  else
    mapfile -t addons < <(find "${helm_dir}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  fi

  (( ${#addons[@]} > 0 )) || die "No addons resolved for installation."
  printf '%s\n' "${addons[@]}"
}

install_platform_helm() {
  local project_abs="$1"
  local manifest_abs="$2"
  local kubeconfig_file="$3"
  local source_helm_dir="${manifest_abs}/helm"
  local target_helm_dir="${project_abs}/helm"
  local addon=""
  local -a addons=()
  local -a cmd=()

  sync_helm_manifests "${source_helm_dir}" "${target_helm_dir}"
  mapfile -t addons < <(resolve_addons "${target_helm_dir}")

  log_info "Installing platform helm addons: ${addons[*]}"
  for addon in "${addons[@]}"; do
    [[ -n "${addon}" ]] || continue
    cmd=(
      "${SCRIPT_DIR}/phase-network-bringup.sh"
      "--project-dir=${project_abs}"
      "--addon=${addon}"
      "--kubeconfig=${kubeconfig_file}"
    )
    [[ "${DRY_RUN}" == "true" ]] && cmd+=("--dry-run")
    run_or_echo "${cmd[@]}"
  done
}

deploy_argocd_root_app() {
  local manifest_abs="$1"
  local kubeconfig_file="$2"
  local root_app_file="${manifest_abs}/argocd/root-app.yaml"

  require_file "${root_app_file}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl apply -f ${root_app_file}"
    return 0
  fi

  KUBECONFIG="${kubeconfig_file}" kubectl apply -f "${root_app_file}"
}

main() {
  local project_abs=""
  local manifest_abs=""
  local kubeconfig_file=""

  parse_args "$@"

  [[ -n "${PROJECT_DIR}" ]] || die "--project-dir is required."
  [[ -n "${ARGOCD_MANIFEST_DIR}" ]] || die "--argocd-manifest-dir is required."

  project_abs="$(resolve_repo_path "${PROJECT_DIR}")"
  manifest_abs="$(resolve_repo_path "${ARGOCD_MANIFEST_DIR}")"
  require_dir_path "${project_abs}"
  require_dir_path "${manifest_abs}"
  require_dir_path "${manifest_abs}/helm"
  require_dir_path "${manifest_abs}/argocd"

  kubeconfig_file="${KUBECONFIG_PATH:-${project_abs}/generated/kubeconfig}"
  kubeconfig_file="$(resolve_repo_path "${kubeconfig_file}")"

  case "${ACTION}" in
    install-platform-helm)
      install_platform_helm "${project_abs}" "${manifest_abs}" "${kubeconfig_file}"
      ;;
    deploy-argocd-root-app)
      deploy_argocd_root_app "${manifest_abs}" "${kubeconfig_file}"
      ;;
    configure-talos-cluster-tools)
      install_platform_helm "${project_abs}" "${manifest_abs}" "${kubeconfig_file}"
      deploy_argocd_root_app "${manifest_abs}" "${kubeconfig_file}"
      ;;
  esac
}

main "$@"
