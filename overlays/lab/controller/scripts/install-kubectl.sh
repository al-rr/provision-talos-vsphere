#!/usr/bin/env bash
# @describe Install kubectl on the lab controller (idempotent).
# @arg --version optional kubectl version tag (e.g. v1.35.2). Default: latest stable.
# @arg --install-dir optional install directory. Default: /home/vagrant/.local/bin.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
BASE_FUNCTIONS="${REPO_ROOT}/overlays/base/scripts/functions.sh"

# shellcheck source=/dev/null
source "${BASE_FUNCTIONS}"

KUBECTL_VERSION="stable"
INSTALL_DIR="${HOME}/.local/bin"

usage() {
  cat <<EOF_USAGE
Usage: $(basename "$0") [options]

Options:
  --version=<tag>      kubectl version (e.g. v1.35.2) or stable (default)
  --install-dir=<dir>  installation directory (default: ~/.local/bin)
  -h, --help           show this help
EOF_USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version=*) KUBECTL_VERSION="${1#*=}"; shift ;;
      --install-dir=*) INSTALL_DIR="${1#*=}"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "Unknown argument: $1" ;;
    esac
  done
}

resolve_version() {
  local version_input="$1"
  local resolved="${version_input}"

  if [[ "${version_input}" == "stable" ]]; then
    resolved="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  fi

  [[ "${resolved}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid kubectl version: ${resolved}"
  printf '%s\n' "${resolved}"
}

current_version() {
  if ! command -v kubectl >/dev/null 2>&1; then
    return 1
  fi
  kubectl version --client --output=yaml 2>/dev/null | sed -n 's/^  gitVersion: //p' | head -n1
}

ensure_path_hint() {
  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) return 0 ;;
    *)
      log_warn "${INSTALL_DIR} is not in PATH for this shell."
      log_warn "Run: export PATH=\"${INSTALL_DIR}:\$PATH\""
      ;;
  esac
}

install_kubectl() {
  local version="$1"
  local url="https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"

  mkdir -p "${INSTALL_DIR}"
  curl -fsSL -o "${INSTALL_DIR}/kubectl" "${url}"
  chmod 0755 "${INSTALL_DIR}/kubectl"
}

main() {
  parse_args "$@"

  local target_version=""
  local current=""

  target_version="$(resolve_version "${KUBECTL_VERSION}")"
  current="$(current_version || true)"

  if [[ -n "${current}" && "${current}" == "${target_version}" ]]; then
    log_info "kubectl ${current} already installed. Nothing to do."
    ensure_path_hint
    return 0
  fi

  if [[ -n "${current}" ]]; then
    log_warn "kubectl ${current} found; upgrading to ${target_version}."
  else
    log_info "Installing kubectl ${target_version}."
  fi

  install_kubectl "${target_version}"

  local final_version
  final_version="$(current_version || true)"
  [[ "${final_version}" == "${target_version}" ]] || die "kubectl install failed. Expected ${target_version}, got ${final_version:-unknown}."

  log_info "kubectl installed successfully: ${final_version}"
  ensure_path_hint
}

main "$@"
