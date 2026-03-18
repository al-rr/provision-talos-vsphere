#!/usr/bin/env bash
# @file install.sh
# @brief Install govc binary in an idempotent way.
# @description
#   Downloads govc release archive from govmomi GitHub releases and installs
#   the binary into /usr/local/bin.
#
# @arg --version string govc version tag (e.g. v0.52.0). Defaults to v0.52.0.
# @arg --install-dir string Target directory for binary. Defaults to /usr/local/bin.
# @flag --dry-run Print planned actions without executing.
# @flag --help,-h Show usage information.
#
# @example
#   ./overlays/base/scripts/govc/install.sh
# @example
#   ./overlays/base/scripts/govc/install.sh --version=v0.52.0 --install-dir=/usr/local/bin

set -euo pipefail

GOVC_VERSION="${GOVC_VERSION:-v0.52.0}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
DRY_RUN="false"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
      --version=<tag>      govc release tag (default: ${GOVC_VERSION})
      --install-dir=<dir>  install directory (default: ${INSTALL_DIR})
      --dry-run            print actions without executing
  -h, --help               show this help
EOF
}

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
die() { log_error "$*"; exit 1; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version=*)
        GOVC_VERSION="${1#*=}"
        shift
        ;;
      --install-dir=*)
        INSTALL_DIR="${1#*=}"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        die "Unknown argument: $1"
        ;;
    esac
  done
}

require_tools() {
  command -v curl >/dev/null 2>&1 || die "curl is required."
  command -v tar >/dev/null 2>&1 || die "tar is required."
  command -v mktemp >/dev/null 2>&1 || die "mktemp is required."
}

run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] $*"
    return 0
  fi
  "$@"
}

installed_version() {
  if ! command -v govc >/dev/null 2>&1; then
    return 1
  fi

  local output=""
  output="$(govc version 2>/dev/null || true)"
  if [[ "${output}" =~ govc[[:space:]]+([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+) ]]; then
    printf 'v%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

download_and_install() {
  local os arch archive_name url tmp_dir
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "${arch}" in
    x86_64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "Unsupported architecture: ${arch}" ;;
  esac

  archive_name="govc_${os}_${arch}.tar.gz"
  url="https://github.com/vmware/govmomi/releases/download/${GOVC_VERSION}/${archive_name}"
  tmp_dir="$(mktemp -d)"

  log_info "Downloading ${url}"
  run_cmd curl -fLso "${tmp_dir}/${archive_name}" "${url}"

  log_info "Extracting govc archive"
  run_cmd tar -xzf "${tmp_dir}/${archive_name}" -C "${tmp_dir}"
  if [[ "${DRY_RUN}" == "false" ]]; then
    [[ -x "${tmp_dir}/govc" ]] || die "govc binary not found in archive."
  fi

  log_info "Installing govc to ${INSTALL_DIR}"
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] sudo install -o root -g root -m 0755 ${tmp_dir}/govc ${INSTALL_DIR}/govc"
  else
    sudo install -o root -g root -m 0755 "${tmp_dir}/govc" "${INSTALL_DIR}/govc"
  fi

  run_cmd rm -rf "${tmp_dir}"
}

main() {
  parse_args "$@"
  require_tools

  local current=""
  if current="$(installed_version)"; then
    if [[ "${current}" == "${GOVC_VERSION}" ]]; then
      log_info "govc ${current} already installed. Nothing to do."
      exit 0
    fi
    log_warn "govc ${current} installed; target is ${GOVC_VERSION}. Upgrading."
  else
    log_info "govc not found. Installing ${GOVC_VERSION}."
  fi

  download_and_install

  if [[ "${DRY_RUN}" == "false" ]]; then
    local final=""
    final="$(installed_version || true)"
    [[ "${final}" == "${GOVC_VERSION}" ]] || die "govc install failed. Expected ${GOVC_VERSION}, got ${final:-unknown}."
    log_info "govc installed successfully: ${final}"
  fi
}

main "$@"
