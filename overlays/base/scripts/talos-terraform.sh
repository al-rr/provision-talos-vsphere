#!/usr/bin/env bash
set -euo pipefail

# @describe Run Terraform plan or apply for Talos nodes from the base Terraform tree.
# @option --env Target overlay environment. Defaults to prod.
# @flag --apply Apply the planned changes.
# @flag --auto-approve Auto-approve terraform apply.

ENV_NAME="prod"
APPLY="false"
AUTO_APPROVE="false"

for arg in "$@"; do
  case "$arg" in
    --env=*)
      ENV_NAME="${arg#*=}"
      ;;
    --apply)
      APPLY="true"
      ;;
    --auto-approve)
      AUTO_APPROVE="true"
      ;;
    *)
      echo "Usage: $0 [--env=<env>] [--apply] [--auto-approve]"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/functions.sh"
load_overlay_vars "${ENV_NAME}"
export_talos_terraform_vars

cd "${REPO_ROOT}/${TALOS_TERRAFORM_DIR}"

log_info "terraform init"
terraform init

log_info "terraform validate"
terraform validate

log_info "terraform plan"
terraform plan

if [[ "${APPLY}" == "true" ]]; then
  if [[ "${AUTO_APPROVE}" == "true" ]]; then
    log_info "terraform apply -auto-approve"
    terraform apply -auto-approve
  else
    log_info "terraform apply"
    terraform apply
  fi
fi
