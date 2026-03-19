#!/usr/bin/env bash
# @file cluster-bootstrap.sh
# @brief Day-1 Talos flow: generate configs, apply configs, bootstrap cluster.
# @description
#   Executes the Day-1 sequence for Talos clusters in a reusable way:
#   1) generate machine configs and talosconfig,
#   2) apply per-node configs (including optional patches),
#   3) bootstrap the first control-plane node.
#
# @arg --env string Overlay environment name. Defaults to lab.
# @arg --mode string generate|apply|bootstrap|all. Defaults to all.
# @arg --cluster-name string Talos cluster name.
# @arg --endpoint string Cluster endpoint URL or host:port.
# @arg --generated-dir string Output directory for generated files.
# @arg --cp-ips string Control-plane IP list (CSV/JSON-like).
# @arg --worker-ips string Worker IP list (CSV/JSON-like).
# @arg --bootstrap-node string Control-plane IP used for bootstrap.
# @flag --dry-run,-n Print planned actions only.
# @flag --help,-h Show usage.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

ENV_NAME="lab"
MODE="all" # generate|apply|bootstrap|all
DRY_RUN="false"
USE_GLOBAL_PATCHES="false"
CLUSTER_NAME=""
CLUSTER_ENDPOINT=""
GENERATED_DIR=""
CP_IPS_RAW=""
WORKER_IPS_RAW=""
BOOTSTRAP_NODE=""
GLOBAL_PATCHES_DIR=""

declare -a CP_IPS=()
declare -a WORKER_IPS=()

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options]

Options:
  --env=<env>                 Overlay environment (default: lab)
  --mode=<mode>               generate|apply|bootstrap|all (default: all)
  --cluster-name=<name>       Talos cluster name
  --endpoint=<endpoint>       Cluster endpoint (e.g. https://192.168.0.250:6443)
  --generated-dir=<path>      Output dir for generated sensitive files
  --cp-ips=<csv>              Control-plane IP list
  --worker-ips=<csv>          Worker IP list
  --bootstrap-node=<ip>       Bootstrap control-plane node IP (default: first cp ip)
  --enable-global-patches     Enable shared/global patches for this run
  --disable-global-patches    Disable shared/global patches (default)
  --global-patches-dir=<path> Directory for enabled global patches
  -n, --dry-run               Show actions without executing
  -h, --help                  Show help
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env=*) ENV_NAME="${1#*=}"; shift ;;
      --mode=*) MODE="${1#*=}"; shift ;;
      -n|--dry-run) DRY_RUN="true"; shift ;;
      --cluster-name=*) CLUSTER_NAME="${1#*=}"; shift ;;
      --endpoint=*) CLUSTER_ENDPOINT="${1#*=}"; shift ;;
      --generated-dir=*) GENERATED_DIR="${1#*=}"; shift ;;
      --cp-ips=*) CP_IPS_RAW="${1#*=}"; shift ;;
      --worker-ips=*) WORKER_IPS_RAW="${1#*=}"; shift ;;
      --bootstrap-node=*) BOOTSTRAP_NODE="${1#*=}"; shift ;;
      --enable-global-patches) USE_GLOBAL_PATCHES="true"; shift ;;
      --disable-global-patches) USE_GLOBAL_PATCHES="false"; shift ;;
      --global-patches-dir=*) GLOBAL_PATCHES_DIR="${1#*=}"; USE_GLOBAL_PATCHES="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done
}

validate_args() {
  case "${MODE}" in
    generate|apply|bootstrap|all) ;;
    *) die "--mode must be one of: generate, apply, bootstrap, all" ;;
  esac
}

sanitize_overlay_env() {
  # Prevent inherited shell exports from overriding overlay vars during dry-run
  # and normal execution. CLI flags still win afterwards.
  [[ -z "${CLUSTER_NAME}" ]] && unset TALOS_CLUSTER_NAME || true
  [[ -z "${CLUSTER_ENDPOINT}" ]] && unset TALOS_CLUSTER_ENDPOINT || true
  [[ -z "${CP_IPS_RAW}" ]] && unset TALOS_CONTROL_PLANE_IPS || true
  [[ -z "${WORKER_IPS_RAW}" ]] && unset TALOS_WORKER_IPS || true
  unset TALOS_CONTROL_PLANE_CONFIG_PATH || true
  unset TALOS_WORKER_CONFIG_PATH || true
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
  local IFS=','
  read -r -a _arr <<<"${csv}"
  printf '%s\n' "${_arr[@]}"
}

resolve_repo_path() {
  local path_value="$1"
  if [[ -z "${path_value}" ]]; then
    printf '%s\n' ""
    return 0
  fi
  if [[ "${path_value}" = /* ]]; then
    printf '%s\n' "${path_value}"
  else
    printf '%s\n' "${REPO_ROOT}/${path_value}"
  fi
}

normalize_endpoint() {
  local endpoint="$1"
  endpoint="${endpoint#http://}"
  endpoint="${endpoint#https://}"
  printf 'https://%s\n' "${endpoint}"
}

run_or_echo() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

build_generate_patch_args() {
  local kind="$1"
  local global_patches_dir="$2"
  local cluster_patches_dir="$3"
  local -a args=()

  if [[ -n "${global_patches_dir}" && -d "${global_patches_dir}" ]]; then
    [[ -f "${global_patches_dir}/dns.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${global_patches_dir}/dns.patch.yaml")
    [[ -f "${global_patches_dir}/flannel.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${global_patches_dir}/flannel.patch.yaml")
    [[ -f "${global_patches_dir}/${kind}-common.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${global_patches_dir}/${kind}-common.patch.yaml")
  fi

  [[ -f "${cluster_patches_dir}/dns.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${cluster_patches_dir}/dns.patch.yaml")
  [[ -f "${cluster_patches_dir}/${kind}-common.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${cluster_patches_dir}/${kind}-common.patch.yaml")

  printf '%s\n' "${args[@]}"
}

patch_for_node() {
  local base_cfg="$1"
  local kind="$2"        # controlplane|worker
  local index="$3"
  local global_patches_dir="$4"
  local cluster_patches_dir="$5"
  local current=""
  local tmp=""
  local patch=""
  local -a chain=()

  if [[ -n "${global_patches_dir}" && -d "${global_patches_dir}" ]]; then
    [[ -f "${global_patches_dir}/dns.patch.yaml" ]] && chain+=("${global_patches_dir}/dns.patch.yaml")
    [[ -f "${global_patches_dir}/flannel.patch.yaml" ]] && chain+=("${global_patches_dir}/flannel.patch.yaml")
    [[ -f "${global_patches_dir}/${kind}-common.patch.yaml" ]] && chain+=("${global_patches_dir}/${kind}-common.patch.yaml")
    [[ -f "${global_patches_dir}/${kind}-${index}.patch.yaml" ]] && chain+=("${global_patches_dir}/${kind}-${index}.patch.yaml")
  fi

  [[ -f "${cluster_patches_dir}/dns.patch.yaml" ]] && chain+=("${cluster_patches_dir}/dns.patch.yaml")
  [[ -f "${cluster_patches_dir}/${kind}-common.patch.yaml" ]] && chain+=("${cluster_patches_dir}/${kind}-common.patch.yaml")
  [[ -f "${cluster_patches_dir}/${kind}-${index}.patch.yaml" ]] && chain+=("${cluster_patches_dir}/${kind}-${index}.patch.yaml")

  if (( ${#chain[@]} == 0 )); then
    printf '%s\n' "${base_cfg}"
    return 0
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '%s\n' "${base_cfg}"
    return 0
  fi

  current="$(mktemp)"
  cp "${base_cfg}" "${current}"

  for patch in "${chain[@]}"; do
    tmp="$(mktemp)"
    talosctl machineconfig patch "${current}" -p "@${patch}" -o "${tmp}" >/dev/null
    mv "${tmp}" "${current}"
  done

  printf '%s\n' "${current}"
}

run_generate() {
  local global_patches_dir="$1"
  local cluster_patches_dir="$2"
  local cp_base=""
  local worker_base=""
  local arg=""
  local -a cp_patch_args=()
  local -a worker_patch_args=()

  mkdir -p "${GENERATED_DIR}"
  cp_base="${GENERATED_DIR}/controlplane.yaml"
  worker_base="${GENERATED_DIR}/worker.yaml"

  while IFS= read -r arg; do
    [[ -n "${arg}" ]] && cp_patch_args+=("${arg}")
  done < <(build_generate_patch_args "control-plane" "${global_patches_dir}" "${cluster_patches_dir}")

  while IFS= read -r arg; do
    [[ -n "${arg}" ]] && worker_patch_args+=("${arg}")
  done < <(build_generate_patch_args "worker" "${global_patches_dir}" "${cluster_patches_dir}")

  log_info "Generating Talos configs into ${GENERATED_DIR}"
  run_or_echo talosctl gen config "${CLUSTER_NAME}" "${CLUSTER_ENDPOINT}" \
    --output-dir "${GENERATED_DIR}" \
    "${cp_patch_args[@]}" \
    "${worker_patch_args[@]}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    return 0
  fi

  [[ -f "${cp_base}" ]] || die "Missing generated controlplane config: ${cp_base}"
  [[ -f "${worker_base}" ]] || die "Missing generated worker config: ${worker_base}"
  [[ -f "${GENERATED_DIR}/talosconfig" ]] || die "Missing generated talosconfig: ${GENERATED_DIR}/talosconfig"
}

run_apply() {
  local global_patches_dir="$1"
  local cluster_patches_dir="$2"
  local cp_base="${GENERATED_DIR}/controlplane.yaml"
  local worker_base="${GENERATED_DIR}/worker.yaml"
  local idx=0
  local ip=""
  local cfg=""

  if [[ "${DRY_RUN}" != "true" ]]; then
    [[ -f "${cp_base}" ]] || die "Missing generated controlplane config: ${cp_base}. Run --mode=generate first."
    [[ -f "${worker_base}" ]] || die "Missing generated worker config: ${worker_base}. Run --mode=generate first."
  fi

  idx=1
  for ip in "${CP_IPS[@]}"; do
    cfg="$(patch_for_node "${cp_base}" "controlplane" "${idx}" "${global_patches_dir}" "${cluster_patches_dir}")"
    log_info "Applying control-plane config to ${ip}"
    run_or_echo talosctl apply-config --insecure --nodes "${ip}" --file "${cfg}"
    [[ "${cfg}" != "${cp_base}" ]] && rm -f "${cfg}"
    idx=$((idx + 1))
  done

  if (( ${#WORKER_IPS[@]} == 0 )); then
    log_warn "Worker IP list is empty; skipping worker apply phase."
    return 0
  fi

  idx=1
  for ip in "${WORKER_IPS[@]}"; do
    cfg="$(patch_for_node "${worker_base}" "worker" "${idx}" "${global_patches_dir}" "${cluster_patches_dir}")"
    log_info "Applying worker config to ${ip}"
    run_or_echo talosctl apply-config --insecure --nodes "${ip}" --file "${cfg}"
    [[ "${cfg}" != "${worker_base}" ]] && rm -f "${cfg}"
    idx=$((idx + 1))
  done
}

run_bootstrap() {
  local talosconfig_path="${GENERATED_DIR}/talosconfig"
  if [[ "${DRY_RUN}" != "true" ]]; then
    [[ -f "${talosconfig_path}" ]] || die "Missing talosconfig: ${talosconfig_path}. Run --mode=generate first."
  fi
  log_info "Bootstrapping cluster via ${BOOTSTRAP_NODE}"
  run_or_echo talosctl --talosconfig "${talosconfig_path}" \
    --nodes "${BOOTSTRAP_NODE}" \
    --endpoints "${BOOTSTRAP_NODE}" \
    bootstrap
}

main() {
  local cluster_patches_dir=""
  local global_patches_enabled_default=""
  local global_patches_legacy_default=""
  local global_patches_available_default=""
  local global_patches_dir=""
  local cp_cfg_path=""
  local cluster_patches_default=""

  parse_args "$@"
  validate_args

  sanitize_overlay_env
  load_overlay_vars "${ENV_NAME}"

  if ! command -v talosctl >/dev/null 2>&1; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_warn "talosctl not found, but continuing due to --dry-run."
    else
      die "talosctl not found. Install with overlays/base/scripts/talos/install.sh."
    fi
  fi

  CLUSTER_NAME="${CLUSTER_NAME:-${TALOS_CLUSTER_NAME:-k8s-cluster-lab}}"
  CLUSTER_ENDPOINT="${CLUSTER_ENDPOINT:-${TALOS_CLUSTER_ENDPOINT:-192.168.0.250:6443}}"
  CLUSTER_ENDPOINT="$(normalize_endpoint "${CLUSTER_ENDPOINT}")"
  GENERATED_DIR="${GENERATED_DIR:-overlays/${ENV_NAME}/talos/${CLUSTER_NAME}/generated}"
  GENERATED_DIR="$(resolve_repo_path "${GENERATED_DIR}")"

  CP_IPS_RAW="${CP_IPS_RAW:-${TALOS_CONTROL_PLANE_IPS:-}}"
  WORKER_IPS_RAW="${WORKER_IPS_RAW:-${TALOS_WORKER_IPS:-}}"
  CP_IPS_RAW="$(normalize_csv_list "${CP_IPS_RAW}")"
  WORKER_IPS_RAW="$(normalize_csv_list "${WORKER_IPS_RAW}")"
  mapfile -t CP_IPS < <(csv_to_array "${CP_IPS_RAW}")
  mapfile -t WORKER_IPS < <(csv_to_array "${WORKER_IPS_RAW}")

  (( ${#CP_IPS[@]} > 0 )) || die "Control-plane IPs are empty."

  BOOTSTRAP_NODE="${BOOTSTRAP_NODE:-${CP_IPS[0]}}"

  global_patches_available_default="$(resolve_repo_path "overlays/${ENV_NAME}/talos/patches-available")"
  global_patches_enabled_default="$(resolve_repo_path "overlays/${ENV_NAME}/talos/patches-enabled")"
  global_patches_legacy_default="$(resolve_repo_path "overlays/${ENV_NAME}/talos/patches")"
  cluster_patches_default="$(resolve_repo_path "overlays/${ENV_NAME}/talos/${CLUSTER_NAME}/patches")"

  cp_cfg_path="$(resolve_repo_path "${TALOS_CONTROL_PLANE_CONFIG_PATH:-}")"
  if [[ -d "${cluster_patches_default}" ]]; then
    cluster_patches_dir="${cluster_patches_default}"
  elif [[ -n "${cp_cfg_path}" ]]; then
    cluster_patches_dir="$(dirname "${cp_cfg_path}")/patches"
  else
    cluster_patches_dir="${cluster_patches_default}"
  fi

  if [[ "${USE_GLOBAL_PATCHES}" == "true" ]]; then
    if [[ -n "${GLOBAL_PATCHES_DIR}" ]]; then
      global_patches_dir="$(resolve_repo_path "${GLOBAL_PATCHES_DIR}")"
    elif [[ -d "${global_patches_enabled_default}" ]]; then
      global_patches_dir="${global_patches_enabled_default}"
    else
      global_patches_dir="${global_patches_legacy_default}"
    fi
    [[ -d "${global_patches_dir}" ]] || log_warn "Global patches enabled, but directory not found: ${global_patches_dir}. Proceeding without global patches."
  else
    global_patches_dir=""
  fi

  [[ -d "${cluster_patches_dir}" ]] || log_warn "Cluster patches directory not found: ${cluster_patches_dir}. Proceeding without cluster patches."
  if [[ "${USE_GLOBAL_PATCHES}" == "true" ]]; then
    log_info "Global patches mode: enabled"
    log_info "Using global patches directory: ${global_patches_dir}"
    log_info "Global patches available directory (optional): ${global_patches_available_default}"
    log_info "Tip: keep candidates in patches-available and only activate in patches-enabled."
  else
    log_info "Global patches mode: disabled (enable with --enable-global-patches)"
  fi
  log_info "Using cluster patches directory: ${cluster_patches_dir}"

  case "${MODE}" in
    generate)
      run_generate "${global_patches_dir}" "${cluster_patches_dir}"
      ;;
    apply)
      run_apply "${global_patches_dir}" "${cluster_patches_dir}"
      ;;
    bootstrap)
      run_bootstrap
      ;;
    all)
      run_generate "${global_patches_dir}" "${cluster_patches_dir}"
      run_apply "${global_patches_dir}" "${cluster_patches_dir}"
      run_bootstrap
      ;;
  esac

  log_info "Day-1 flow completed (mode=${MODE}). Generated files are in: ${GENERATED_DIR}"
}

main "$@"
