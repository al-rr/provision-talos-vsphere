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
# @flag --skip-lb-config Disable automatic HAProxy Talos backend/frontend reconciliation.
# @arg --validate-timeout-seconds int Seconds to wait for kube-api readiness via VIP.
# @arg --validate-interval-seconds int Interval between kube-api readiness checks.
# @flag --skip-post-validate Skip kube-api readiness validation after bootstrap.
# @flag --dry-run,-n Print planned actions only.
# @flag --help,-h Show usage.

set -euo pipefail

BOOTSTRAP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${BOOTSTRAP_SCRIPT_DIR}/../../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/overlays/base/scripts/functions.sh"

ENV_NAME="lab"
MODE="all" # generate|apply|bootstrap|all
DRY_RUN="false"
USE_GLOBAL_PATCHES="false"
ROTATE_SECRETS="false"
CLUSTER_NAME=""
CLUSTER_ENDPOINT=""
GENERATED_DIR=""
CP_IPS_RAW=""
WORKER_IPS_RAW=""
BOOTSTRAP_NODE=""
AUTO_CONFIGURE_LB="true"
VALIDATE_POST_BOOTSTRAP="true"
VALIDATE_TIMEOUT_SECONDS="180"
VALIDATE_INTERVAL_SECONDS="5"
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
  --endpoint=<endpoint>       Cluster endpoint (e.g. https://192.168.0.30:6443)
  --generated-dir=<path>      Output dir for generated sensitive files
  --cp-ips=<csv>              Control-plane IP list
  --worker-ips=<csv>          Worker IP list
  --bootstrap-node=<ip>       Bootstrap control-plane node IP (default: first cp ip)
  --skip-lb-config            Skip automatic Talos HAProxy reconciliation
  --validate-timeout-seconds=<seconds>
                              Wait timeout for kube-api readiness via VIP (default: 180)
  --validate-interval-seconds=<seconds>
                              Check interval for kube-api readiness (default: 5)
  --skip-post-validate        Skip kube-api readiness validation after bootstrap
  --enable-global-patches     Enable shared/global patches for this run
  --disable-global-patches    Disable shared/global patches (default)
  --global-patches-dir=<path> Directory for enabled global patches
  --rotate-secrets            Regenerate Talos PKI secrets for this cluster
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
      --skip-lb-config) AUTO_CONFIGURE_LB="false"; shift ;;
      --validate-timeout-seconds=*) VALIDATE_TIMEOUT_SECONDS="${1#*=}"; shift ;;
      --validate-interval-seconds=*) VALIDATE_INTERVAL_SECONDS="${1#*=}"; shift ;;
      --skip-post-validate) VALIDATE_POST_BOOTSTRAP="false"; shift ;;
      --enable-global-patches) USE_GLOBAL_PATCHES="true"; shift ;;
      --disable-global-patches) USE_GLOBAL_PATCHES="false"; shift ;;
      --global-patches-dir=*) GLOBAL_PATCHES_DIR="${1#*=}"; USE_GLOBAL_PATCHES="true"; shift ;;
      --rotate-secrets) ROTATE_SECRETS="true"; shift ;;
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
  [[ "${VALIDATE_TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]] || die "--validate-timeout-seconds must be numeric."
  [[ "${VALIDATE_INTERVAL_SECONDS}" =~ ^[0-9]+$ ]] || die "--validate-interval-seconds must be numeric."
  [[ "${VALIDATE_TIMEOUT_SECONDS}" -gt 0 ]] || die "--validate-timeout-seconds must be > 0."
  [[ "${VALIDATE_INTERVAL_SECONDS}" -gt 0 ]] || die "--validate-interval-seconds must be > 0."
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

endpoint_host() {
  local endpoint="$1"
  endpoint="${endpoint#http://}"
  endpoint="${endpoint#https://}"
  endpoint="${endpoint%%/*}"
  endpoint="${endpoint%%:*}"
  printf '%s\n' "${endpoint}"
}

endpoint_port() {
  local endpoint="$1"
  local stripped=""
  local host_port=""
  stripped="${endpoint#http://}"
  stripped="${stripped#https://}"
  host_port="${stripped%%/*}"
  if [[ "${host_port}" == *:* ]]; then
    printf '%s\n' "${host_port##*:}"
  else
    printf '6443\n'
  fi
}

run_or_echo() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

apply_installer_image_override() {
  local config_file="$1"
  local installer_image="$2"
  local patch_file=""
  local tmp_file=""

  [[ -f "${config_file}" ]] || die "Missing config file for installer override: ${config_file}"
  [[ -n "${installer_image}" ]] || return 0

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] apply installer image override on ${config_file}: ${installer_image}"
    return 0
  fi

  patch_file="$(mktemp)"
  cat > "${patch_file}" <<EOF_PATCH
machine:
  install:
    image: ${installer_image}
EOF_PATCH

  tmp_file="$(mktemp)"
  talosctl machineconfig patch "${config_file}" -p "@${patch_file}" -o "${tmp_file}" >/dev/null
  mv "${tmp_file}" "${config_file}"
  rm -f "${patch_file}"
}

render_node_network_patches() {
  local cluster_patches_dir="$1"
  local cp_prefix="${TALOS_CONTROL_PLANE_NAME_PREFIX:-talos-cp}"
  local worker_prefix="${TALOS_WORKER_NAME_PREFIX:-talos-worker}"
  local iface="${TALOS_NODE_INTERFACE:-eth0}"
  local gateway="${TALOS_GATEWAY:-${NETWORK_GATEWAY:-}}"
  local netmask="${TALOS_NETMASK_PREFIX:-${NETWORK_NETMASK_PREFIX:-24}}"
  local dns_raw="${TALOS_NAMESERVERS:-${NETWORK_NAMESERVERS:-}}"
  local dns_csv=""
  local idx=1
  local ip=""
  local patch_file=""
  local dns_ip=""
  local -a dns_list=()

  mkdir -p "${cluster_patches_dir}"

  dns_csv="$(normalize_csv_list "${dns_raw}")"
  if [[ -n "${dns_csv}" ]]; then
    mapfile -t dns_list < <(csv_to_array "${dns_csv}")
  fi

  for ip in "${CP_IPS[@]}"; do
    patch_file="${cluster_patches_dir}/${cp_prefix}-${idx}.patch.yaml"
    {
      echo "machine:"
      echo "  network:"
      echo "    interfaces:"
      echo "      - interface: ${iface}"
      echo "        addresses:"
      echo "          - ${ip}/${netmask}"
      echo "        routes:"
      echo "          - network: 0.0.0.0/0"
      echo "            gateway: ${gateway}"
      echo "        dhcp: false"
      if (( ${#dns_list[@]} > 0 )); then
        echo "    nameservers:"
        for dns_ip in "${dns_list[@]}"; do
          [[ -n "${dns_ip}" ]] || continue
          echo "      - ${dns_ip}"
        done
      fi
    } > "${patch_file}"
    idx=$((idx + 1))
  done

  idx=1
  for ip in "${WORKER_IPS[@]}"; do
    patch_file="${cluster_patches_dir}/${worker_prefix}-${idx}.patch.yaml"
    {
      echo "machine:"
      echo "  network:"
      echo "    interfaces:"
      echo "      - interface: ${iface}"
      echo "        addresses:"
      echo "          - ${ip}/${netmask}"
      echo "        routes:"
      echo "          - network: 0.0.0.0/0"
      echo "            gateway: ${gateway}"
      echo "        dhcp: false"
      if (( ${#dns_list[@]} > 0 )); then
        echo "    nameservers:"
        for dns_ip in "${dns_list[@]}"; do
          [[ -n "${dns_ip}" ]] || continue
          echo "      - ${dns_ip}"
        done
      fi
    } > "${patch_file}"
    idx=$((idx + 1))
  done
}

build_generate_patch_args() {
  local kind="$1"
  local global_patches_dir="$2"
  local cluster_patches_dir="$3"
  local common_alias=""
  local -a args=()

  if [[ "${kind}" == "control-plane" ]]; then
    common_alias="cp-common.patch.yaml"
  else
    common_alias="${kind}-common.patch.yaml"
  fi

  if [[ -n "${global_patches_dir}" && -d "${global_patches_dir}" ]]; then
    [[ -f "${global_patches_dir}/dns.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${global_patches_dir}/dns.patch.yaml")
    [[ -f "${global_patches_dir}/flannel.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${global_patches_dir}/flannel.patch.yaml")
    [[ -f "${global_patches_dir}/${kind}-common.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${global_patches_dir}/${kind}-common.patch.yaml")
    [[ -f "${global_patches_dir}/${common_alias}" ]] && args+=("--config-patch-${kind}" "@${global_patches_dir}/${common_alias}")
  fi

  [[ -f "${cluster_patches_dir}/dns.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${cluster_patches_dir}/dns.patch.yaml")
  [[ -f "${cluster_patches_dir}/${kind}-common.patch.yaml" ]] && args+=("--config-patch-${kind}" "@${cluster_patches_dir}/${kind}-common.patch.yaml")
  [[ -f "${cluster_patches_dir}/${common_alias}" ]] && args+=("--config-patch-${kind}" "@${cluster_patches_dir}/${common_alias}")

  printf '%s\n' "${args[@]}"
}

patch_for_node() {
  local base_cfg="$1"
  local kind="$2"        # controlplane|worker
  local index="$3"
  local global_patches_dir="$4"
  local cluster_patches_dir="$5"
  local cp_prefix="${TALOS_CONTROL_PLANE_NAME_PREFIX:-talos-cp}"
  local worker_prefix="${TALOS_WORKER_NAME_PREFIX:-talos-worker}"
  local common_alias=""
  local named_patch=""
  local current=""
  local tmp=""
  local patch=""
  local -a chain=()

  if [[ -n "${global_patches_dir}" && -d "${global_patches_dir}" ]]; then
    [[ -f "${global_patches_dir}/dns.patch.yaml" ]] && chain+=("${global_patches_dir}/dns.patch.yaml")
    [[ -f "${global_patches_dir}/flannel.patch.yaml" ]] && chain+=("${global_patches_dir}/flannel.patch.yaml")
    [[ -f "${global_patches_dir}/${kind}-common.patch.yaml" ]] && chain+=("${global_patches_dir}/${kind}-common.patch.yaml")
    if [[ "${kind}" == "controlplane" ]]; then
      common_alias="cp-common.patch.yaml"
      [[ -f "${global_patches_dir}/${common_alias}" ]] && chain+=("${global_patches_dir}/${common_alias}")
    fi
    [[ -f "${global_patches_dir}/${kind}-${index}.patch.yaml" ]] && chain+=("${global_patches_dir}/${kind}-${index}.patch.yaml")
  fi

  [[ -f "${cluster_patches_dir}/dns.patch.yaml" ]] && chain+=("${cluster_patches_dir}/dns.patch.yaml")
  [[ -f "${cluster_patches_dir}/${kind}-common.patch.yaml" ]] && chain+=("${cluster_patches_dir}/${kind}-common.patch.yaml")
  if [[ "${kind}" == "controlplane" ]]; then
    common_alias="cp-common.patch.yaml"
    [[ -f "${cluster_patches_dir}/${common_alias}" ]] && chain+=("${cluster_patches_dir}/${common_alias}")
  fi
  [[ -f "${cluster_patches_dir}/${kind}-${index}.patch.yaml" ]] && chain+=("${cluster_patches_dir}/${kind}-${index}.patch.yaml")
  if [[ "${kind}" == "controlplane" ]]; then
    named_patch="${cluster_patches_dir}/${cp_prefix}-${index}.patch.yaml"
  else
    named_patch="${cluster_patches_dir}/${worker_prefix}-${index}.patch.yaml"
  fi
  [[ -f "${named_patch}" ]] && chain+=("${named_patch}")

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
  local installer_image="${TALOS_INSTALLER_IMAGE:-}"
  local cp_base=""
  local worker_base=""
  local arg=""
  local -a cp_patch_args=()
  local -a worker_patch_args=()
  local secrets_file=""
  local -a gen_args=()

  mkdir -p "${GENERATED_DIR}"
  cp_base="${GENERATED_DIR}/controlplane.yaml"
  worker_base="${GENERATED_DIR}/worker.yaml"
  secrets_file="${GENERATED_DIR}/secrets.yaml"

  while IFS= read -r arg; do
    [[ -n "${arg}" ]] && cp_patch_args+=("${arg}")
  done < <(build_generate_patch_args "control-plane" "${global_patches_dir}" "${cluster_patches_dir}")

  while IFS= read -r arg; do
    [[ -n "${arg}" ]] && worker_patch_args+=("${arg}")
  done < <(build_generate_patch_args "worker" "${global_patches_dir}" "${cluster_patches_dir}")

  if [[ "${ROTATE_SECRETS}" == "true" || ! -f "${secrets_file}" ]]; then
    log_info "Generating Talos secrets bundle: ${secrets_file}"
    run_or_echo talosctl gen secrets --output-file "${secrets_file}" --force
  else
    log_info "Reusing Talos secrets bundle: ${secrets_file}"
  fi

  gen_args=(
    gen
    config
    "${CLUSTER_NAME}"
    "${CLUSTER_ENDPOINT}"
    --output-dir "${GENERATED_DIR}"
    --with-secrets "${secrets_file}"
    --force
  )
  gen_args+=("${cp_patch_args[@]}")
  gen_args+=("${worker_patch_args[@]}")

  log_info "Generating Talos configs into ${GENERATED_DIR}"
  run_or_echo talosctl "${gen_args[@]}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    return 0
  fi

  [[ -f "${cp_base}" ]] || die "Missing generated controlplane config: ${cp_base}"
  [[ -f "${worker_base}" ]] || die "Missing generated worker config: ${worker_base}"
  [[ -f "${GENERATED_DIR}/talosconfig" ]] || die "Missing generated talosconfig: ${GENERATED_DIR}/talosconfig"

  if [[ -n "${installer_image}" ]]; then
    log_info "Applying installer image override from TALOS_INSTALLER_IMAGE: ${installer_image}"
    apply_installer_image_override "${cp_base}" "${installer_image}"
    apply_installer_image_override "${worker_base}" "${installer_image}"
  fi
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

run_lb_reconcile() {
  local configure_script="${BOOTSTRAP_SCRIPT_DIR}/configure_load_balancer.sh"
  local cp_csv=""
  local vip=""
  local endpoint_vip=""
  local -a lb_args=()

  [[ "${AUTO_CONFIGURE_LB}" == "true" ]] || return 0
  require_file "${configure_script}"

  cp_csv="$(IFS=,; echo "${CP_IPS[*]}")"
  endpoint_vip="$(endpoint_host "${CLUSTER_ENDPOINT}")"
  vip="${HAPROXY_VIP:-${endpoint_vip}}"

  [[ -n "${vip}" ]] || die "Could not resolve Talos VIP for HAProxy reconciliation."

  lb_args=(
    "--env=${ENV_NAME}"
    "--append"
    "--cluster-name=${CLUSTER_NAME}"
    "--vip=${vip}"
    "--cp-ips=${cp_csv}"
  )

  if [[ "${DRY_RUN}" == "true" ]]; then
    lb_args+=("--dry-run")
  fi

  log_info "Reconciling Talos HAProxy frontend/backend for cluster '${CLUSTER_NAME}' at ${vip}:6443"
  run_or_echo "${configure_script}" "${lb_args[@]}"
}

run_post_validation() {
  local endpoint_ip=""
  local endpoint_kube_port=""
  local elapsed=0
  local curl_output=""
  local tcp_ok="false"

  [[ "${VALIDATE_POST_BOOTSTRAP}" == "true" ]] || return 0
  [[ "${MODE}" == "bootstrap" || "${MODE}" == "all" ]] || return 0

  endpoint_ip="$(endpoint_host "${CLUSTER_ENDPOINT}")"
  endpoint_kube_port="$(endpoint_port "${CLUSTER_ENDPOINT}")"
  [[ -n "${endpoint_ip}" ]] || die "Could not parse endpoint host from ${CLUSTER_ENDPOINT}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] validate kube-api readiness at https://${endpoint_ip}:${endpoint_kube_port}/readyz"
    return 0
  fi

  log_info "Validating kube-api readiness at https://${endpoint_ip}:${endpoint_kube_port}/readyz"
  while (( elapsed < VALIDATE_TIMEOUT_SECONDS )); do
    if command -v curl >/dev/null 2>&1; then
      if curl_output="$(curl -ksS --max-time 5 "https://${endpoint_ip}:${endpoint_kube_port}/readyz" 2>/dev/null || true)"; then
        :
      fi
      if [[ "${curl_output}" == *"ok"* ]]; then
        log_info "kube-api readiness check succeeded through VIP ${endpoint_ip}:${endpoint_kube_port}."
        return 0
      fi
    else
      if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${endpoint_ip}/${endpoint_kube_port}" >/dev/null 2>&1; then
        tcp_ok="true"
      else
        tcp_ok="false"
      fi
      if [[ "${tcp_ok}" == "true" ]]; then
        log_warn "curl not found; TCP connectivity to ${endpoint_ip}:${endpoint_kube_port} is up."
        return 0
      fi
    fi

    sleep "${VALIDATE_INTERVAL_SECONDS}"
    elapsed=$((elapsed + VALIDATE_INTERVAL_SECONDS))
  done

  die "kube-api readiness check failed after ${VALIDATE_TIMEOUT_SECONDS}s for https://${endpoint_ip}:${endpoint_kube_port}/readyz."
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
  CLUSTER_ENDPOINT="${CLUSTER_ENDPOINT:-${TALOS_CLUSTER_ENDPOINT:-${HAPROXY_VIP:-192.168.0.30}:6443}}"
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
  render_node_network_patches "${cluster_patches_dir}"
  log_info "Rendered per-node network patches from overlay vars in: ${cluster_patches_dir}"
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
      run_lb_reconcile
      run_apply "${global_patches_dir}" "${cluster_patches_dir}"
      ;;
    bootstrap)
      run_lb_reconcile
      run_bootstrap
      ;;
    all)
      run_generate "${global_patches_dir}" "${cluster_patches_dir}"
      run_lb_reconcile
      run_apply "${global_patches_dir}" "${cluster_patches_dir}"
      run_bootstrap
      ;;
  esac

  run_post_validation

  log_info "Day-1 flow completed (mode=${MODE}). Generated files are in: ${GENERATED_DIR}"
}

main "$@"
