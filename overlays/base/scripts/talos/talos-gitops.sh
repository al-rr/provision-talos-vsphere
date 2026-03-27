#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

ACTION=""
MANIFEST_ROOT_DIR=""
HELM_MANIFEST_DIR=""
ARGOCD_MANIFEST_DIR=""
ADDONS_RAW=""
EXCLUDE_ADDONS_RAW=""
SYSTEM_EXCLUDE_ADDONS_RAW="cilium"
KUBECONFIG_PATH=""
CILIUM_ROLLOUT_TIMEOUT="300s"
DRY_RUN="false"

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") <action> [options]

Actions:
  install-platform-helm         Install/update helm addons from GitOps manifests
  deploy-argocd-root-app        Apply Argo CD root app manifest
  configure-talos-cluster-tools Install platform helm and deploy Argo CD root app

Options:
  --manifest-root-dir=<path>     Root dir that contains helm/ and argocd/ (recommended)
  --helm-manifest-dir=<path>     Directory that contains addon folders and release.yaml
  --argocd-manifest-dir=<path>   Directory that contains root-app.yaml
  --addons=<list>                CSV/JSON-like addon list override (example: ["cilium","longhorn"])
  --exclude-addons=<list>        CSV/JSON-like addons to skip in install-platform-helm (merged with system excludes)
  --kubeconfig=<path>            Kubeconfig path override (default: KUBECONFIG or ~/.kube/config)
  --cilium-rollout-timeout=<dur> Timeout for Cilium rollout wait when cilium CLI is unavailable (default: 300s)
  -n, --dry-run                  Print actions without executing
  -h, --help                     Show help

Examples:
  $(basename "$0") install-platform-helm --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
  $(basename "$0") install-platform-helm --helm-manifest-dir=/home/vagrant/talos-vsphere-gitops/environments/lab/helm --addons='["longhorn"]'
  $(basename "$0") install-platform-helm --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab --exclude-addons='["longhorn"]'
  $(basename "$0") deploy-argocd-root-app --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
  $(basename "$0") configure-talos-cluster-tools --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
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
      --manifest-root-dir=*) MANIFEST_ROOT_DIR="${1#*=}"; shift ;;
      --helm-manifest-dir=*) HELM_MANIFEST_DIR="${1#*=}"; shift ;;
      --argocd-manifest-dir=*) ARGOCD_MANIFEST_DIR="${1#*=}"; shift ;;
      --addons=*) ADDONS_RAW="${1#*=}"; shift ;;
      --exclude-addons=*) EXCLUDE_ADDONS_RAW="${1#*=}"; shift ;;
      --kubeconfig=*) KUBECONFIG_PATH="${1#*=}"; shift ;;
      --cilium-rollout-timeout=*) CILIUM_ROLLOUT_TIMEOUT="${1#*=}"; shift ;;
      -n|--dry-run) DRY_RUN="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done

  [[ -n "${ACTION}" ]] || { usage; die "Action is required."; }
}

resolve_path() {
  local path_value="$1"
  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
  else
    printf '%s\n' "${PWD}/${path_value}"
  fi
}

require_dir_path() {
  local dir_path="$1"
  [[ -d "${dir_path}" ]] || die "Required directory not found: ${dir_path}"
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

in_array() {
  local needle="$1"
  shift
  local item=""
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

read_release_field() {
  local file_path="$1"
  local field_name="$2"
  awk -F': ' -v key="${field_name}" '$1==key {print $2; exit}' "${file_path}" | sed -e 's/^"//' -e 's/"$//'
}

resolve_values_file_path() {
  local release_file="$1"
  local addon_dir="$2"
  local manifest_root="$3"
  local values_raw="$4"
  local candidate=""
  local basename_candidate=""

  [[ -n "${values_raw}" ]] || return 1

  if [[ "${values_raw}" = /* && -f "${values_raw}" ]]; then
    printf '%s\n' "${values_raw}"
    return 0
  fi

  if [[ -f "${addon_dir}/${values_raw}" ]]; then
    printf '%s\n' "${addon_dir}/${values_raw}"
    return 0
  fi

  basename_candidate="$(basename "${values_raw}")"
  if [[ -f "${addon_dir}/${basename_candidate}" ]]; then
    printf '%s\n' "${addon_dir}/${basename_candidate}"
    return 0
  fi

  if [[ -n "${manifest_root}" ]]; then
    candidate="${manifest_root}/${values_raw}"
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  return 1
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
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl get namespace ${namespace} || kubectl create namespace ${namespace}"
    return 0
  fi

  KUBECONFIG="${kubeconfig_file}" kubectl get namespace "${namespace}" >/dev/null 2>&1 || \
    KUBECONFIG="${kubeconfig_file}" kubectl create namespace "${namespace}" >/dev/null
}

label_namespace_security() {
  local kubeconfig_file="$1"
  local namespace="$2"
  local enforce_level="$3"
  local audit_level="$4"
  local warn_level="$5"

  [[ -n "${namespace}" ]] || return 0
  if [[ -z "${enforce_level}" && -z "${audit_level}" && -z "${warn_level}" ]]; then
    return 0
  fi

  local -a cmd=(kubectl label namespace "${namespace}" --overwrite)
  [[ -n "${enforce_level}" ]] && cmd+=("pod-security.kubernetes.io/enforce=${enforce_level}")
  [[ -n "${audit_level}" ]] && cmd+=("pod-security.kubernetes.io/audit=${audit_level}")
  [[ -n "${warn_level}" ]] && cmd+=("pod-security.kubernetes.io/warn=${warn_level}")

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} ${cmd[*]}"
    return 0
  fi

  KUBECONFIG="${kubeconfig_file}" "${cmd[@]}" >/dev/null
}

resolve_addons() {
  local helm_dir="$1"
  local addons_csv=""
  local system_exclude_csv=""
  local exclude_csv=""
  local -a addons=()
  local -a system_exclude_addons=()
  local -a exclude_addons=()
  local -a merged_excludes=()
  local -a filtered_addons=()
  local addon=""
  local ex=""

  if [[ -n "${ADDONS_RAW}" ]]; then
    addons_csv="$(normalize_csv_list "${ADDONS_RAW}")"
    mapfile -t addons < <(csv_to_array "${addons_csv}")
  else
    mapfile -t addons < <(find "${helm_dir}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  fi

  system_exclude_csv="$(normalize_csv_list "${SYSTEM_EXCLUDE_ADDONS_RAW}")"
  if [[ -n "${system_exclude_csv}" ]]; then
    mapfile -t system_exclude_addons < <(csv_to_array "${system_exclude_csv}")
  fi

  exclude_csv="$(normalize_csv_list "${EXCLUDE_ADDONS_RAW}")"
  if [[ -n "${exclude_csv}" ]]; then
    mapfile -t exclude_addons < <(csv_to_array "${exclude_csv}")
  fi

  for ex in "${system_exclude_addons[@]}"; do
    [[ -n "${ex}" ]] || continue
    if ! in_array "${ex}" "${merged_excludes[@]:-}"; then
      merged_excludes+=("${ex}")
    fi
  done
  for ex in "${exclude_addons[@]}"; do
    [[ -n "${ex}" ]] || continue
    if ! in_array "${ex}" "${merged_excludes[@]:-}"; then
      merged_excludes+=("${ex}")
    fi
  done

  for addon in "${addons[@]}"; do
    [[ -n "${addon}" ]] || continue
    if (( ${#merged_excludes[@]} > 0 )) && in_array "${addon}" "${merged_excludes[@]}"; then
      printf '[INFO] Skipping excluded addon %s.\n' "${addon}" >&2
      continue
    fi
    filtered_addons+=("${addon}")
  done

  (( ${#filtered_addons[@]} > 0 )) || die "No addons resolved for installation after exclusions."
  printf '%s\n' "${filtered_addons[@]}"
}

install_single_addon() {
  local helm_dir="$1"
  local manifest_root="$2"
  local addon="$3"
  local kubeconfig_file="$4"
  local addon_dir="${helm_dir}/${addon}"
  local release_file="${addon_dir}/release.yaml"
  local render_dir="/tmp/talos-gitops-render/${addon}"
  local render_file="${render_dir}/rendered.yaml"
  local release_name=""
  local namespace=""
  local chart=""
  local version=""
  local values_raw=""
  local values_file=""
  local validation_selector=""
  local namespace_label_enforce=""
  local namespace_label_audit=""
  local namespace_label_warn=""
  local -a extra_namespaces=()
  local ns=""

  require_dir_path "${addon_dir}"
  require_file "${release_file}"

  release_name="$(read_release_field "${release_file}" "releaseName")"
  namespace="$(read_release_field "${release_file}" "namespace")"
  chart="$(read_release_field "${release_file}" "chart")"
  version="$(read_release_field "${release_file}" "version")"
  values_raw="$(read_release_field "${release_file}" "valuesFile")"
  validation_selector="$(read_release_field "${release_file}" "validationSelector")"
  namespace_label_enforce="$(read_release_field "${release_file}" "namespaceLabelEnforce")"
  namespace_label_audit="$(read_release_field "${release_file}" "namespaceLabelAudit")"
  namespace_label_warn="$(read_release_field "${release_file}" "namespaceLabelWarn")"

  [[ -n "${release_name}" ]] || die "releaseName missing in ${release_file}"
  [[ -n "${namespace}" ]] || die "namespace missing in ${release_file}"
  [[ -n "${chart}" ]] || die "chart missing in ${release_file}"
  [[ -n "${version}" ]] || die "version missing in ${release_file}"
  [[ -n "${values_raw}" ]] || die "valuesFile missing in ${release_file}"

  values_file="$(resolve_values_file_path "${release_file}" "${addon_dir}" "${manifest_root}" "${values_raw}")" || \
    die "Could not resolve valuesFile '${values_raw}' from ${release_file}"

  log_info "[${addon}] Phase 2/1: helm template"
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

  ensure_namespace "${kubeconfig_file}" "${namespace}"
  label_namespace_security "${kubeconfig_file}" "${namespace}" \
    "${namespace_label_enforce}" "${namespace_label_audit}" "${namespace_label_warn}"

  if [[ "${addon}" == "cilium" ]]; then
    mapfile -t extra_namespaces < <(collect_cilium_secret_namespaces "${values_file}")
    for ns in "${extra_namespaces[@]}"; do
      [[ "${ns}" == "${namespace}" ]] && continue
      ensure_namespace "${kubeconfig_file}" "${ns}"
    done
  fi

  log_info "[${addon}] Phase 2/2: server-side dry-run validation"
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl apply --server-side --force-conflicts --dry-run=server -f ${render_file}"
  else
    KUBECONFIG="${kubeconfig_file}" kubectl apply --server-side --force-conflicts --dry-run=server -f "${render_file}" >/dev/null
  fi

  log_info "[${addon}] Phase 2/3: helm upgrade --install"
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} helm upgrade --install ${release_name} ${chart} --version ${version} --namespace ${namespace} --create-namespace -f ${values_file}"
  else
    KUBECONFIG="${kubeconfig_file}" helm upgrade --install "${release_name}" "${chart}" \
      --version "${version}" \
      --namespace "${namespace}" \
      --create-namespace \
      -f "${values_file}"
  fi

  log_info "[${addon}] Phase 2/4: post-install validations"
  if [[ "${DRY_RUN}" == "true" ]]; then
    if [[ -n "${validation_selector}" ]]; then
      log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl -n ${namespace} get pods -l ${validation_selector}"
    else
      log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl -n ${namespace} get pods"
    fi
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl get nodes"
  else
    if [[ -n "${validation_selector}" ]]; then
      KUBECONFIG="${kubeconfig_file}" kubectl -n "${namespace}" get pods -l "${validation_selector}"
    else
      KUBECONFIG="${kubeconfig_file}" kubectl -n "${namespace}" get pods
    fi
    KUBECONFIG="${kubeconfig_file}" kubectl get nodes

    if [[ "${addon}" == "cilium" ]]; then
      if command -v cilium >/dev/null 2>&1; then
        KUBECONFIG="${kubeconfig_file}" cilium status --wait
      else
        log_warn "cilium CLI not found; waiting daemonset/cilium rollout via kubectl (${CILIUM_ROLLOUT_TIMEOUT})"
        if ! KUBECONFIG="${kubeconfig_file}" kubectl -n "${namespace}" rollout status daemonset/cilium --timeout="${CILIUM_ROLLOUT_TIMEOUT}"; then
          log_warn "Cilium rollout timed out; continue monitoring manually."
        fi
      fi
    fi
  fi

  log_info "[${addon}] Follow-up monitoring:"
  if [[ -n "${validation_selector}" ]]; then
    log_info "  KUBECONFIG=${kubeconfig_file} kubectl -n ${namespace} get pods -l ${validation_selector} -w"
  else
    log_info "  KUBECONFIG=${kubeconfig_file} kubectl -n ${namespace} get pods -w"
  fi
  log_info "  KUBECONFIG=${kubeconfig_file} kubectl get nodes -w"
}

install_platform_helm() {
  local helm_dir="$1"
  local manifest_root="$2"
  local kubeconfig_file="$3"
  local system_exclude_csv=""
  local exclude_csv=""
  local addon=""
  local -a addons=()

  require_dir_path "${helm_dir}"
  system_exclude_csv="$(normalize_csv_list "${SYSTEM_EXCLUDE_ADDONS_RAW}")"
  exclude_csv="$(normalize_csv_list "${EXCLUDE_ADDONS_RAW}")"
  [[ -n "${system_exclude_csv}" ]] && log_info "System excluded addons: ${system_exclude_csv}"
  [[ -n "${exclude_csv}" ]] && log_info "User excluded addons: ${exclude_csv}"
  mapfile -t addons < <(resolve_addons "${helm_dir}")

  log_info "Installing platform helm addons from ${helm_dir}: ${addons[*]}"
  for addon in "${addons[@]}"; do
    [[ -n "${addon}" ]] || continue
    install_single_addon "${helm_dir}" "${manifest_root}" "${addon}" "${kubeconfig_file}"
  done
}

deploy_argocd_root_app() {
  local argocd_manifest_abs="$1"
  local kubeconfig_file="$2"
  local root_app_file="${argocd_manifest_abs}/root-app.yaml"

  require_file "${root_app_file}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] KUBECONFIG=${kubeconfig_file} kubectl apply -f ${root_app_file}"
    return 0
  fi

  KUBECONFIG="${kubeconfig_file}" kubectl apply -f "${root_app_file}"
}

main() {
  local manifest_root_abs=""
  local helm_manifest_abs=""
  local argocd_manifest_abs=""
  local kubeconfig_file=""

  parse_args "$@"

  if [[ -n "${MANIFEST_ROOT_DIR}" ]]; then
    manifest_root_abs="$(resolve_path "${MANIFEST_ROOT_DIR}")"
    require_dir_path "${manifest_root_abs}"
    [[ -n "${HELM_MANIFEST_DIR}" ]] || HELM_MANIFEST_DIR="${manifest_root_abs}/helm"
    [[ -n "${ARGOCD_MANIFEST_DIR}" ]] || ARGOCD_MANIFEST_DIR="${manifest_root_abs}/argocd"
  fi

  if [[ -n "${HELM_MANIFEST_DIR}" ]]; then
    helm_manifest_abs="$(resolve_path "${HELM_MANIFEST_DIR}")"
  fi
  if [[ -n "${ARGOCD_MANIFEST_DIR}" ]]; then
    argocd_manifest_abs="$(resolve_path "${ARGOCD_MANIFEST_DIR}")"
  fi

  if [[ -n "${KUBECONFIG_PATH}" ]]; then
    kubeconfig_file="$(resolve_path "${KUBECONFIG_PATH}")"
  elif [[ -n "${KUBECONFIG:-}" ]]; then
    kubeconfig_file="${KUBECONFIG}"
  else
    kubeconfig_file="${HOME}/.kube/config"
  fi

  case "${ACTION}" in
    install-platform-helm)
      [[ -n "${helm_manifest_abs}" ]] || die "--helm-manifest-dir is required for install-platform-helm (or use --manifest-root-dir)."
      require_dir_path "${helm_manifest_abs}"
      install_platform_helm "${helm_manifest_abs}" "${manifest_root_abs}" "${kubeconfig_file}"
      ;;
    deploy-argocd-root-app)
      [[ -n "${argocd_manifest_abs}" ]] || die "--argocd-manifest-dir is required for deploy-argocd-root-app (or use --manifest-root-dir)."
      require_dir_path "${argocd_manifest_abs}"
      deploy_argocd_root_app "${argocd_manifest_abs}" "${kubeconfig_file}"
      ;;
    configure-talos-cluster-tools)
      [[ -n "${helm_manifest_abs}" ]] || die "--helm-manifest-dir is required for configure-talos-cluster-tools (or use --manifest-root-dir)."
      [[ -n "${argocd_manifest_abs}" ]] || die "--argocd-manifest-dir is required for configure-talos-cluster-tools (or use --manifest-root-dir)."
      require_dir_path "${helm_manifest_abs}"
      require_dir_path "${argocd_manifest_abs}"
      install_platform_helm "${helm_manifest_abs}" "${manifest_root_abs}" "${kubeconfig_file}"
      deploy_argocd_root_app "${argocd_manifest_abs}" "${kubeconfig_file}"
      ;;
  esac
}

main "$@"
