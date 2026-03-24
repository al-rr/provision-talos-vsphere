#!/usr/bin/env bash
set -euo pipefail

# @describe Run HAProxy Ansible automation from the base Ansible tree.
# @option --env Target overlay environment. Defaults to prod.
# @flag --syntax-check Run ansible syntax validation only.

ENV_NAME="prod"
SYNTAX_CHECK="false"

for arg in "$@"; do
  case "$arg" in
    --env=*)
      ENV_NAME="${arg#*=}"
      ;;
    --syntax-check)
      SYNTAX_CHECK="true"
      ;;
    *)
      echo "Usage: $0 [--env=<env>] [--syntax-check]"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/functions.sh"
load_overlay_vars "${ENV_NAME}"
export_ansible_vars

export ANSIBLE_CONFIG="${REPO_ROOT}/overlays/base/ansible/haproxy/ansible.cfg"

if [[ "${SYNTAX_CHECK}" == "true" ]]; then
  log_info "ansible-playbook --syntax-check"
  ansible-playbook -i "${REPO_ROOT}/${HAPROXY_ANSIBLE_INVENTORY}" "${REPO_ROOT}/${HAPROXY_ANSIBLE_PLAYBOOK}" --syntax-check
else
  log_info "ansible-playbook"
  ansible-playbook -i "${REPO_ROOT}/${HAPROXY_ANSIBLE_INVENTORY}" "${REPO_ROOT}/${HAPROXY_ANSIBLE_PLAYBOOK}"
fi
