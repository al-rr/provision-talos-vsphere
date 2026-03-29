#!/usr/bin/env bash
# @file phase-cluster-ready.sh
# @brief Phase 1 orchestration for Talos cluster readiness.
# @description
#   Executes phase-1 workflow: provision VMs, run Talos bootstrap flow,
#   publish kubeconfig artifact, and validate baseline runtime readiness checks.
#
# @arg --env name Overlay environment name.
# @arg --cluster-name name Cluster name override.
# @arg --worker-count int Worker count override for current run.
# @flag --skip-provision Skip VM provisioning.
# @flag --skip-bootstrap Skip bootstrap flow.
# @flag --skip-cni-check Skip strict cni/proxy runtime check.
# @flag --clean-recreate Destroy and recreate cluster VMs for a clean run.
# @flag --skip-sync-access Skip local kubectl/talosctl sync.
# @arg --kubeconfig-path path Output kubeconfig path override.
# @flag --dry-run,-n Print actions without executing.
# @flag --help,-h Show usage information.
#
# @example
#   # Full phase-1 run on lab overlay
#   ./phase-cluster-ready.sh --env=lab
#
# @example
#   # Control-plane-only test run
#   ./phase-cluster-ready.sh --env=lab --worker-count=0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

ENV_NAME="lab"
CLUSTER_NAME=""
WORKER_COUNT_OVERRIDE=""
SKIP_PROVISION="false"
SKIP_BOOTSTRAP="false"
SKIP_CNI_CHECK="false"
FORCE_CLEAN_RECREATE="false"
SYNC_ACCESS="true"
DRY_RUN="false"
KUBECONFIG_PATH=""

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options]

Phase 1: Cluster Ready
  1) provision control-plane/worker VMs
  2) run Talos bootstrap flow (generate/apply/bootstrap)
  3) publish kubeconfig artifact
  4) validate API + CNI/proxy runtime config

Options:
  --env=<env>                    Overlay environment (default: lab)
  --cluster-name=<name>          Cluster name override
  --worker-count=<n>             Override worker count for this run
  --skip-provision               Skip VM provisioning step
  --skip-bootstrap               Skip Talos bootstrap step
  --skip-cni-check               Skip strict check for cni=none and proxy.disabled=true
  --clean-recreate               Destroy existing VMs and reset generated artifacts before create/bootstrap
  --skip-sync-access             Skip local kubectl/talosctl access synchronization
  --kubeconfig-path=<path>       Output kubeconfig path (default: overlays/<env>/talos/<cluster>/generated/kubeconfig)
  -n, --dry-run                  Print actions without executing
  -h, --help                     Show help

Examples:
  # Full phase-1 workflow (provision + bootstrap + validations)
  $(basename "$0") --env=lab

  # Clean recreate and bootstrap from scratch
  $(basename "$0") --env=lab --clean-recreate

  # Control-plane-only test run
  $(basename "$0") --env=lab --worker-count=0

  # Bootstrap-only re-run without provisioning
  $(basename "$0") --env=lab --skip-provision
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --cluster-name=*) CLUSTER_NAME="${1#*=}"; shift ;;
      --worker-count=*) WORKER_COUNT_OVERRIDE="${1#*=}"; shift ;;
      --skip-provision) SKIP_PROVISION="true"; shift ;;
      --skip-bootstrap) SKIP_BOOTSTRAP="true"; shift ;;
      --skip-cni-check) SKIP_CNI_CHECK="true"; shift ;;
      --clean-recreate) FORCE_CLEAN_RECREATE="true"; shift ;;
      --skip-sync-access) SYNC_ACCESS="false"; shift ;;
      --kubeconfig-path=*) KUBECONFIG_PATH="${1#*=}"; shift ;;
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

resolve_repo_path() {
  local path_value="$1"
  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
  else
    printf '%s\n' "${REPO_ROOT}/${path_value}"
  fi
}

run_or_echo() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

is_true() {
  local value="${1:-}"
  value="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')"
  [[ "${value}" == "1" || "${value}" == "true" || "${value}" == "yes" || "${value}" == "on" ]]
}

main() {
  local generated_dir=""
  local talosconfig_path=""
  local cp_ips_raw=""
  local bootstrap_node=""
  local kubeconfig_out=""
  local machineconfig_dump=""
  local worker_ips_override=""
  local expected_member_count=0
  local members_dump=""
  local members_ips=()
  local -a cp_ips=()
  local -a provision_cmd=()
  local -a destroy_cmd=()
  local -a pre_generate_cmd=()
  local -a bootstrap_cmd=()
  local -a sync_kubectl_cmd=()
  local -a sync_talosctl_cmd=()
  local disable_default_cni="${TALOS_DISABLE_DEFAULT_CNI:-false}"

  parse_args "$@"

  load_overlay_vars "${ENV_NAME}"

  CLUSTER_NAME="${CLUSTER_NAME:-${TALOS_CLUSTER_NAME:-talos}}"
  generated_dir="$(resolve_repo_path "overlays/${ENV_NAME}/talos/${CLUSTER_NAME}/generated")"
  talosconfig_path="${generated_dir}/talosconfig"

  cp_ips_raw="${TALOS_CONTROL_PLANE_IPS:-}"
  cp_ips_raw="$(normalize_csv_list "${cp_ips_raw}")"
  mapfile -t cp_ips < <(csv_to_array "${cp_ips_raw}")
  (( ${#cp_ips[@]} > 0 )) || die "TALOS_CONTROL_PLANE_IPS is empty for env=${ENV_NAME}."
  bootstrap_node="${cp_ips[0]}"

  if [[ "${FORCE_CLEAN_RECREATE}" == "true" ]]; then
    log_warn "Clean recreate enabled: destroying existing Talos VMs and resetting generated artifacts."
    destroy_cmd=("${REPO_ROOT}/overlays/base/scripts/talos/provision-cluster.sh" "--env=${ENV_NAME}")
    if [[ -n "${WORKER_COUNT_OVERRIDE}" ]]; then
      destroy_cmd+=("--worker-count=${WORKER_COUNT_OVERRIDE}")
    fi
    destroy_cmd+=("destroy")
    run_or_echo "${destroy_cmd[@]}"

    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] rm -rf ${generated_dir}/*"
    else
      mkdir -p "${generated_dir}"
      rm -rf "${generated_dir:?}/"*
    fi
  fi

  if [[ "${SKIP_PROVISION}" != "true" ]]; then
    if [[ ! -f "${generated_dir}/controlplane.yaml" || ! -f "${generated_dir}/worker.yaml" || ! -f "${generated_dir}/talosconfig" ]]; then
      pre_generate_cmd=("${REPO_ROOT}/overlays/base/scripts/talos/cluster-bootstrap.sh" "--env=${ENV_NAME}" "--mode=generate")
      if [[ -n "${WORKER_COUNT_OVERRIDE}" && "${WORKER_COUNT_OVERRIDE}" == "0" ]]; then
        worker_ips_override="[]"
        pre_generate_cmd+=("--worker-ips=${worker_ips_override}")
      fi
      if [[ "${FORCE_CLEAN_RECREATE}" == "true" ]]; then
        pre_generate_cmd+=("--rotate-secrets" "--force-generate")
      fi
      log_info "Pre-step: generating Talos configs required for VM provisioning"
      run_or_echo "${pre_generate_cmd[@]}"
    fi

    provision_cmd=("${REPO_ROOT}/overlays/base/scripts/talos/provision-cluster.sh" "--env=${ENV_NAME}")
    if [[ -n "${WORKER_COUNT_OVERRIDE}" ]]; then
      provision_cmd+=("--worker-count=${WORKER_COUNT_OVERRIDE}")
    fi
    provision_cmd+=("create")

    log_info "Phase 1/4: provisioning Talos VMs"
    run_or_echo "${provision_cmd[@]}"
  fi

  if [[ "${SKIP_BOOTSTRAP}" != "true" ]]; then
    bootstrap_cmd=("${REPO_ROOT}/overlays/base/scripts/talos/cluster-bootstrap.sh" "--env=${ENV_NAME}" "--mode=all")

    if [[ -n "${WORKER_COUNT_OVERRIDE}" && "${WORKER_COUNT_OVERRIDE}" == "0" ]]; then
      worker_ips_override="[]"
      bootstrap_cmd+=("--worker-ips=${worker_ips_override}")
    fi
    # When CNI default is disabled (cni: none), nodes are expected to remain NotReady
    # until Cilium is installed, so bootstrap post-validation must be skipped here.
    if is_true "${disable_default_cni}"; then
      bootstrap_cmd+=("--skip-post-validate")
    fi
    log_info "Phase 2/4: cluster bootstrap flow"
    run_or_echo "${bootstrap_cmd[@]}"
  fi

  kubeconfig_out="${KUBECONFIG_PATH:-overlays/${ENV_NAME}/talos/${CLUSTER_NAME}/generated/kubeconfig}"
  kubeconfig_out="$(resolve_repo_path "${kubeconfig_out}")"

  log_info "Phase 3/4: publishing kubeconfig artifact"
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] talosctl --talosconfig ${talosconfig_path} --nodes ${bootstrap_node} --endpoints ${bootstrap_node} kubeconfig ${kubeconfig_out} --force --merge=false --force-context-name admin@${CLUSTER_NAME}"
  else
    mkdir -p "$(dirname "${kubeconfig_out}")"
    talosctl --talosconfig "${talosconfig_path}" \
      --nodes "${bootstrap_node}" \
      --endpoints "${bootstrap_node}" \
      kubeconfig "${kubeconfig_out}" \
      --force \
      --merge=false \
      --force-context-name "admin@${CLUSTER_NAME}"
  fi

  if [[ "${SYNC_ACCESS}" == "true" ]]; then
    log_info "Phase 3.5/4: syncing local kubectl and talosctl access"
    sync_kubectl_cmd=(
      "${REPO_ROOT}/overlays/base/scripts/talos/sync-kubectl.sh"
      "--env=${ENV_NAME}"
      "--cluster-name=${CLUSTER_NAME}"
      "--source=${kubeconfig_out}"
    )
    sync_talosctl_cmd=(
      "${REPO_ROOT}/overlays/base/scripts/talos/sync-talosctl.sh"
      "--env=${ENV_NAME}"
      "--cluster-name=${CLUSTER_NAME}"
      "--source=${talosconfig_path}"
    )
    run_or_echo "${sync_kubectl_cmd[@]}"
    run_or_echo "${sync_talosctl_cmd[@]}"
  else
    log_warn "Skipping access sync (--skip-sync-access)."
  fi

  log_info "Phase 4/4: validation"
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] kubectl --kubeconfig ${kubeconfig_out} get nodes -o wide"
    log_info "[DRY-RUN] talosctl --talosconfig ${talosconfig_path} --nodes ${bootstrap_node} --endpoints ${bootstrap_node} get machineconfig -o yaml"
  else
    kubectl --kubeconfig "${kubeconfig_out}" get nodes -o wide

    machineconfig_dump="$(mktemp)"
    talosctl --talosconfig "${talosconfig_path}" \
      --nodes "${bootstrap_node}" \
      --endpoints "${bootstrap_node}" \
      get machineconfig -o yaml > "${machineconfig_dump}"

    if [[ "${SKIP_CNI_CHECK}" != "true" ]]; then
      grep -qE '^\s*name:\s*none\s*$' "${machineconfig_dump}" || die "CNI check failed: expected cluster.network.cni.name=none"
      grep -qE '^\s*disabled:\s*true\s*$' "${machineconfig_dump}" || die "Proxy check failed: expected cluster.proxy.disabled=true"
      log_info "CNI/proxy check passed (cni=none, proxy.disabled=true)."
    else
      log_warn "Skipping CNI/proxy strict check (--skip-cni-check)."
    fi

    rm -f "${machineconfig_dump}"

    if [[ -n "${WORKER_COUNT_OVERRIDE}" && "${WORKER_COUNT_OVERRIDE}" == "0" ]]; then
      expected_member_count="${#cp_ips[@]}"
      members_dump="$(mktemp)"
      talosctl --talosconfig "${talosconfig_path}" \
        --nodes "${bootstrap_node}" \
        --endpoints "${bootstrap_node}" \
        get members > "${members_dump}"

      mapfile -t members_ips < <(
        awk 'NR>1 && NF>0 {print $NF}' "${members_dump}" \
          | sed -e 's/\["//' -e 's/"\]//' -e 's/,//g' \
          | awk 'NF'
      )
      rm -f "${members_dump}"

      if [[ "${#members_ips[@]}" -ne "${expected_member_count}" ]]; then
        die "Member check failed: expected ${expected_member_count} members (control planes only), got ${#members_ips[@]}."
      fi

      local expected_ip=""
      for expected_ip in "${cp_ips[@]}"; do
        if ! printf '%s\n' "${members_ips[@]}" | grep -qx "${expected_ip}"; then
          die "Member check failed: expected control-plane member IP ${expected_ip} not found."
        fi
      done
      log_info "Member check passed: only expected control-plane members are present."
    fi
  fi

  log_info "Cluster Ready phase completed for cluster '${CLUSTER_NAME}' (env=${ENV_NAME})."
}

main "$@"
