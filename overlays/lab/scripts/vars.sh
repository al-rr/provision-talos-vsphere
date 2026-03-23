#!/usr/bin/env bash
# @file vars.sh
# @description Lab overlay environment overrides (source of truth for lab values).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BASE_VARS="${REPO_ROOT}/overlays/base/scripts/vars.sh"

if [[ ! -f "${BASE_VARS}" ]]; then
  echo "[ERROR] Missing base vars file: ${BASE_VARS}" >&2
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    exit 1
  fi
  return 1
fi

# shellcheck source=/dev/null
source "${BASE_VARS}"

export OVERLAY_ENV="lab"

# Environment anchors (override values only).
export NETWORK_GATEWAY="192.168.0.2"
export NETWORK_NETMASK_PREFIX="24"
export NETWORK_NAMESERVERS='["192.168.0.53"]'
export VM_STATIC_INTERFACE="ens160"

# Build/guest account in lab (used by Packer and GOVC in-guest steps).
export BUILD_USERNAME="vagrant"
export BUILD_PASSWORD="vagrant"
if [[ -z "${BUILD_KEY:-}" && -f "/home/vagrant/.ssh/id_ed25519.pub" ]]; then
  export BUILD_KEY
  BUILD_KEY="$(tr -d '\n' < /home/vagrant/.ssh/id_ed25519.pub)"
fi

# Shared SSH identity for remote operations in lab.
export SSH_USER="vagrant"
export SSH_PORT="22"
export SSH_PRIVATE_KEY_FILE="/home/vagrant/.ssh/id_ed25519"

# Ansible remote automation identity (inherits SSH_* unless explicitly overridden).
export ANSIBLE_USERNAME="${ANSIBLE_USERNAME:-${SSH_USER}}"
export ANSIBLE_PRIVATE_KEY_FILE="${ANSIBLE_PRIVATE_KEY_FILE:-${SSH_PRIVATE_KEY_FILE}}"
export ANSIBLE_HOST_KEY_CHECKING="False"

# VMware/vSphere target (lab).
export VSPHERE_HOST="192.168.0.233"
export VSPHERE_ENDPOINT="192.168.0.233"
export VSPHERE_DATASTORE="DATASTORE_02"
export VSPHERE_NETWORK="VM Network"
export VSPHERE_USERNAME="root"
export VSPHERE_PASSWORD="Senha@123"

# HAProxy topology.
export HAPROXY_VIP="192.168.0.30"
export HAPROXY_NODE_1_NAME="talos-lb-1"
export HAPROXY_NODE_1_IP="192.168.0.31"
export HAPROXY_NODE_2_NAME="talos-lb-2"
export HAPROXY_NODE_2_IP="192.168.0.32"

# Shared GOVC settings consumed by VMware-backed modules.
export GOVC_VM_ENFORCE_GUEST_STATIC_NETWORK="true"

# DNS VM + dnsmasq records.
export DNS_VM_TEMPLATE_NAME="ubuntu-24-04-lts-template"
export DNS_VM_OVA_PATH="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.ova"
export DNS_VM_STATIC_IP="192.168.0.53"
export DNS_VM_GATEWAY="${NETWORK_GATEWAY}"
export DNS_VM_STATIC_INTERFACE="ens192"
export DNS_VM_GUEST_STATIC="true"
export DNS_VM_GUEST_USERNAME="${BUILD_USERNAME}"
export DNS_VM_GUEST_PASSWORD="${BUILD_PASSWORD}"
export DNS_SSH_USER="${DNS_VM_GUEST_USERNAME}"
export DNS_CLOUDINIT_PASSWORD="${DNS_VM_GUEST_PASSWORD}"
export DNS_CLOUDINIT_PUBLIC_KEY="${DNS_CLOUDINIT_PUBLIC_KEY:-${BUILD_KEY}}"
export DNS_DOMAIN="infra.lab"
export DNS_LISTEN_ADDRESSES="${DNS_VM_STATIC_IP}"
export DNS_UPSTREAM_SERVERS="1.1.1.1,8.8.8.8"
DNS_A_RECORDS_LIST=(
  "talos-api.${DNS_DOMAIN}=${HAPROXY_VIP}"
  "${HAPROXY_NODE_1_NAME}.${DNS_DOMAIN}=${HAPROXY_NODE_1_IP}"
  "${HAPROXY_NODE_2_NAME}.${DNS_DOMAIN}=${HAPROXY_NODE_2_IP}"
)

# Talos topology.
export TALOS_CLUSTER_NAME="talos"
export TALOS_CLUSTER_ENDPOINT="${HAPROXY_VIP}"
export TALOS_OVA_PATH="https://factory.talos.dev/image/903b2da78f99adef03cbbd4df6714563823f63218508800751560d3bc3557e40/v1.12.4/vmware-amd64.ova"
export TALOS_CONTROL_PLANE_IPS='["192.168.0.61","192.168.0.62","192.168.0.63"]'
export TALOS_WORKER_IPS='["192.168.0.71","192.168.0.72"]'
export TALOS_CONTROL_PLANE_NAME_PREFIX="talos-cp"
export TALOS_WORKER_NAME_PREFIX="talos-worker"
export TALOS_GATEWAY="${NETWORK_GATEWAY}"
export TALOS_NETMASK_PREFIX="${NETWORK_NETMASK_PREFIX}"
export TALOS_NAMESERVERS="${NETWORK_NAMESERVERS}"
export TALOS_CONTROL_PLANE_CONFIG_PATH="overlays/lab/talos/${TALOS_CLUSTER_NAME}/controlplane.yaml"
export TALOS_WORKER_CONFIG_PATH="overlays/lab/talos/${TALOS_CLUSTER_NAME}/worker.yaml"

# Add Talos node records to DNS_A_RECORDS_LIST from TALOS_* IP lists.
talos_cp_index=1
while IFS= read -r talos_cp_ip || [[ -n "${talos_cp_ip}" ]]; do
  [[ -n "${talos_cp_ip}" ]] || continue
  DNS_A_RECORDS_LIST+=("${TALOS_CONTROL_PLANE_NAME_PREFIX}-${talos_cp_index}.${DNS_DOMAIN}=${talos_cp_ip}")
  talos_cp_index=$((talos_cp_index + 1))
done < <(printf '%s\n' "${TALOS_CONTROL_PLANE_IPS}" | tr -d '[]" ' | tr ',' '\n')

talos_worker_index=1
while IFS= read -r talos_worker_ip || [[ -n "${talos_worker_ip}" ]]; do
  [[ -n "${talos_worker_ip}" ]] || continue
  DNS_A_RECORDS_LIST+=("${TALOS_WORKER_NAME_PREFIX}-${talos_worker_index}.${DNS_DOMAIN}=${talos_worker_ip}")
  talos_worker_index=$((talos_worker_index + 1))
done < <(printf '%s\n' "${TALOS_WORKER_IPS}" | tr -d '[]" ' | tr ',' '\n')
