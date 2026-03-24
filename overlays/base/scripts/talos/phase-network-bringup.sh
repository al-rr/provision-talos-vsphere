#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

ENV_NAME="lab"
CLUSTER_NAME=""
ADDON_NAME="cilium"
DRY_RUN="false"
RENDER_ONLY="false"
KUBECONFIG_PATH=""

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options]

Phase 2: Network Bring-up (Helm)
  1) helm template (required)
  2) kubectl apply --dry-run=server on rendered manifest (required)
  3) helm upgrade --install (unless --render-only)
  4) post-install validations

Options:
  --env=<env>                    Overlay environment (default: lab)
  --cluster-name=<name>          Cluster name override
  --addon=<name>                 Addon name under helm/ (default: cilium)
  --kubeconfig=<path>            Kubeconfig path (default: overlays/<env>/talos/<cluster>/generated/kubeconfig)
  --render-only                  Stop before helm upgrade --install
  -n, --dry-run                  Print actions without executing
  -h, --help                     Show help
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --cluster-name=*) CLUSTER_NAME="${1#*=}"; shift ;;
      --addon=*) ADDON_NAME="${1#*=}"; shift ;;
      --kubeconfig=*) KUBECONFIG_PATH="${1#*=}"; shift ;;
      --render-only) RENDER_ONLY="true"; shift ;;
      -n|--dry-run) DRY_RUN="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done
}

resolve_repo_path() {
  local path_value="$1"
  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
  else
    printf '%s\n' "${REPO_ROOT}/${path_value}"
  fi
}

read_release_field() {
  local file_path="$1"
  local field_name="$2"
  awk -F': ' -v key="${field_name}" '$1==key {print $2; exit}' "${file_path}" | sed -e 's/^"//' -e 's/"$//'
}

run_or_echo() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

collect_cilium_secret_namespaces() {
  local values_path="$1"
  awk '
    /^\s*secretsNamespace:\s*$/ { in_block=1; next }
    in_block && /^\s*name:\s*/ {
      ns=$0
      sub(/^[[:space:]]*name:[[:space:]]*/, "", ns)
      gsub(/"/, "", ns)
      if (ns != "") print ns
      in_block=0
      next
    }
    in_block && /^[^[:space:]]/ { in_block=0 }
  ' "${values_path}" | sort -u
}

ensure_namespace() {
  local kubeconfig_file="$1"
  local namespace="$2"
  [[ -n "${namespace}" ]] || return 0
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl create namespace ${namespace} --dry-run=client -o yaml | kubectl apply -f -"
    return 0
  fi
  KUBECONFIG="${kubeconfig_file}" kubectl get namespace "${namespace}" >/dev/null 2>&1 || \
    KUBECONFIG="${kubeconfig_file}" kubectl create namespace "${namespace}" >/dev/null
}

namespace_exists() {
  local kubeconfig_file="$1"
  local namespace="$2"
  KUBECONFIG="${kubeconfig_file}" kubectl get namespace "${namespace}" >/dev/null 2>&1
}

delete_namespace() {
  local kubeconfig_file="$1"
  local namespace="$2"
  [[ -n "${namespace}" ]] || return 0
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl delete namespace ${namespace}"
    return 0
  fi
  KUBECONFIG="${kubeconfig_file}" kubectl delete namespace "${namespace}" --wait=true >/dev/null
}

main() {
  local cluster_dir=""
  local helm_dir=""
  local addon_dir=""
  local release_file=""
  local render_dir=""
  local render_file=""
  local release_name=""
  local namespace=""
  local chart=""
  local version=""
  local values_file=""
  local kubeconfig_file=""
  local -a extra_namespaces=()
  local -a preflight_created_ns=()
  local ns=""

  parse_args "$@"
  load_overlay_vars "${ENV_NAME}"

  CLUSTER_NAME="${CLUSTER_NAME:-${TALOS_CLUSTER_NAME:-talos}}"
  cluster_dir="$(resolve_repo_path "overlays/${ENV_NAME}/talos/${CLUSTER_NAME}")"
  helm_dir="${cluster_dir}/helm"
  addon_dir="${helm_dir}/${ADDON_NAME}"
  release_file="${addon_dir}/release.yaml"

  require_file "${release_file}"

  release_name="$(read_release_field "${release_file}" "releaseName")"
  namespace="$(read_release_field "${release_file}" "namespace")"
  chart="$(read_release_field "${release_file}" "chart")"
  version="$(read_release_field "${release_file}" "version")"
  values_file="$(read_release_field "${release_file}" "valuesFile")"

  [[ -n "${release_name}" ]] || die "releaseName missing in ${release_file}"
  [[ -n "${namespace}" ]] || die "namespace missing in ${release_file}"
  [[ -n "${chart}" ]] || die "chart missing in ${release_file}"
  [[ -n "${version}" ]] || die "version missing in ${release_file}"
  [[ -n "${values_file}" ]] || die "valuesFile missing in ${release_file}"

  values_file="$(resolve_repo_path "${values_file}")"
  require_file "${values_file}"

  kubeconfig_file="${KUBECONFIG_PATH:-overlays/${ENV_NAME}/talos/${CLUSTER_NAME}/generated/kubeconfig}"
  kubeconfig_file="$(resolve_repo_path "${kubeconfig_file}")"

  render_dir="${cluster_dir}/generated/helm/${ADDON_NAME}"
  render_file="${render_dir}/rendered.yaml"

  log_info "Phase 2/1: helm template (mandatory)"
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] mkdir -p ${render_dir}"
    log_info "[DRY-RUN] helm template ${release_name} ${chart} --version ${version} --namespace ${namespace} --create-namespace -f ${values_file} > ${render_file}"
  else
    mkdir -p "${render_dir}"
    helm template "${release_name}" "${chart}" \
      --version "${version}" \
      --namespace "${namespace}" \
      --create-namespace \
      -f "${values_file}" > "${render_file}"
    [[ -s "${render_file}" ]] || die "Rendered file is empty: ${render_file}"
  fi

  # Some Cilium profiles reference extra namespaces (for example cilium-secrets)
  # that must exist before server-side dry-run.
  ensure_namespace "${kubeconfig_file}" "${namespace}"
  if [[ "${ADDON_NAME}" == "cilium" ]]; then
    mapfile -t extra_namespaces < <(collect_cilium_secret_namespaces "${values_file}")
    for ns in "${extra_namespaces[@]}"; do
      [[ "${ns}" == "${namespace}" ]] && continue
      if [[ "${DRY_RUN}" == "true" ]]; then
        ensure_namespace "${kubeconfig_file}" "${ns}"
      else
        if ! namespace_exists "${kubeconfig_file}" "${ns}"; then
          ensure_namespace "${kubeconfig_file}" "${ns}"
          preflight_created_ns+=("${ns}")
        fi
      fi
    done
  fi

  log_info "Phase 2/2: server-side dry-run validation (mandatory)"
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl apply --dry-run=server -f ${render_file}"
  else
    KUBECONFIG="${kubeconfig_file}" kubectl apply --dry-run=server -f "${render_file}" >/dev/null
  fi

  if [[ "${RENDER_ONLY}" == "true" ]]; then
    if [[ "${DRY_RUN}" != "true" ]]; then
      for ns in "${preflight_created_ns[@]}"; do
        delete_namespace "${kubeconfig_file}" "${ns}"
      done
    fi
    log_warn "Stopping at render-only mode. Helm install/upgrade was not executed."
    log_info "Rendered manifest: ${render_file}"
    exit 0
  fi

  # Namespaces created only to satisfy server-side dry-run must be removed,
  # so Helm can create and own them in the release metadata.
  if [[ "${DRY_RUN}" != "true" ]]; then
    for ns in "${preflight_created_ns[@]}"; do
      delete_namespace "${kubeconfig_file}" "${ns}"
    done
  fi

  log_info "Phase 2/3: helm upgrade --install"
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} helm upgrade --install ${release_name} ${chart} --version ${version} --namespace ${namespace} --create-namespace -f ${values_file}"
  else
    KUBECONFIG="${kubeconfig_file}" helm upgrade --install "${release_name}" "${chart}" \
      --version "${version}" \
      --namespace "${namespace}" \
      --create-namespace \
      -f "${values_file}"
  fi

  log_info "Phase 2/4: post-install validations"
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl -n ${namespace} get pods -l k8s-app=${ADDON_NAME}"
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl get nodes"
    log_info "[DRY-RUN] cilium status (if cilium CLI exists)"
  else
    KUBECONFIG="${kubeconfig_file}" kubectl -n "${namespace}" get pods -l "k8s-app=${ADDON_NAME}"
    KUBECONFIG="${kubeconfig_file}" kubectl get nodes
    if command -v cilium >/dev/null 2>&1; then
      KUBECONFIG="${kubeconfig_file}" cilium status --wait
    else
      log_warn "cilium CLI not found; skipping 'cilium status --wait'."
    fi
  fi

  log_info "Network Bring-up phase completed for addon '${ADDON_NAME}' in cluster '${CLUSTER_NAME}'."
}

main "$@"
