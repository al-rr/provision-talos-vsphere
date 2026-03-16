#!/usr/bin/env bash
# @file vars.sh
# @description Default variables for all environments.
#              Environment overlays must source this file first and then
#              override only the values that change.

export OVERLAY_ENV="${OVERLAY_ENV:-}"
export OVERLAY_ALLOW_LEGACY_ENV="${OVERLAY_ALLOW_LEGACY_ENV:-false}"

# Repository paths
export BASE_PACKER_DIR="overlays/base/packer"
export BASE_HAPROXY_TERRAFORM_DIR="overlays/base/terraform/haproxy-lb"
export BASE_TALOS_TERRAFORM_DIR="overlays/base/terraform/talos"
export BASE_HAPROXY_ANSIBLE_DIR="overlays/base/ansible/haproxy"
export BASE_GOVC_DIR="overlays/base/govc"

# vSphere Settings
export VSPHERE_DATACENTER=""
export VSPHERE_CLUSTER=""
export VSPHERE_HOST="192.168.0.233"
export VSPHERE_DATASTORE="DATASTORE_02"
export VSPHERE_NETWORK="VM Network"
export VSPHERE_FOLDER=""
export VSPHERE_RESOURCE_POOL=""
export VSPHERE_SET_HOST_FOR_DATASTORE_UPLOADS="false"
export VSPHERE_API_TIMEOUT="10"
export VSPHERE_ENDPOINT="192.168.0.233"
export VSPHERE_USERNAME=""
export VSPHERE_PASSWORD=""
export VSPHERE_INSECURE_CONNECTION="true"

# Build account
export BUILD_USERNAME=""
export BUILD_PASSWORD=""
export BUILD_PASSWORD_ENCRYPTED=""
export BUILD_KEY=""

# Ansible
export ANSIBLE_USERNAME=""
export ANSIBLE_KEY=""
export ANSIBLE_PRIVATE_KEY_FILE=""
export ANSIBLE_HOST_KEY_CHECKING="False"

# Shared Packer settings
export COMMON_ISO_DATASTORE=""
export COMMON_ISO_CONTENT_LIBRARY=""
export COMMON_ISO_CONTENT_LIBRARY_ENABLED="false"
export COMMON_VM_VERSION="15"
export COMMON_TOOLS_UPGRADE_POLICY="true"
export COMMON_REMOVE_CDROM="true"
export COMMON_TEMPLATE_CONVERSION="false"
export COMMON_CONTENT_LIBRARY=""
export COMMON_CONTENT_LIBRARY_ENABLED="false"
export COMMON_CONTENT_LIBRARY_OVF="true"
export COMMON_CONTENT_LIBRARY_DESTROY="true"
export COMMON_CONTENT_LIBRARY_SKIP_EXPORT="false"
export COMMON_OVF_EXPORT_ENABLED="false"
export COMMON_OVF_EXPORT_OVERWRITE="true"
export COMMON_DATA_SOURCE="disk"
export COMMON_HTTP_IP=""
export COMMON_HTTP_PORT_MIN="8000"
export COMMON_HTTP_PORT_MAX="8099"
export COMMON_IP_WAIT_TIMEOUT="20m"
export COMMON_IP_SETTLE_TIMEOUT="5s"
export COMMON_SHUTDOWN_TIMEOUT="15m"

# Proxy
export COMMUNICATOR_PROXY_HOST=""
export COMMUNICATOR_PROXY_PORT=""
export COMMUNICATOR_PROXY_USERNAME=""
export COMMUNICATOR_PROXY_PASSWORD=""

# HAProxy topology and automation
export HAPROXY_VIP=""
export HAPROXY_NODE_1_NAME="haproxy-01"
export HAPROXY_NODE_1_IP=""
export HAPROXY_NODE_2_NAME="haproxy-02"
export HAPROXY_NODE_2_IP=""
export HAPROXY_PACKER_TEMPLATE_PATH="${BASE_PACKER_DIR}"
export HAPROXY_PACKER_OVERRIDE_FILE=""
export HAPROXY_ANSIBLE_INVENTORY="${BASE_HAPROXY_ANSIBLE_DIR}/inventory"
export HAPROXY_ANSIBLE_PLAYBOOK="${BASE_HAPROXY_ANSIBLE_DIR}/playbooks/provision_haproxy.yml"
export HAPROXY_TERRAFORM_DIR="${BASE_HAPROXY_TERRAFORM_DIR}"

# HAProxy VM convenience values
export TF_TEMPLATE_NAME=""
export TF_VM_NAME="haproxy-lb-01"
export TF_VM_CPUS="2"
export TF_VM_MEMORY_MB="4096"
export TF_VM_DISK_GB="40"
export TF_VM_IPV4_ADDRESS=""
export TF_VM_IPV4_PREFIX="24"
export TF_VM_IPV4_GATEWAY=""
export TF_VM_DOMAIN="infra.local"

# Talos topology and automation
export TALOS_TERRAFORM_DIR="${BASE_TALOS_TERRAFORM_DIR}"
export TALOS_CLUSTER_NAME="talos-prod"
export TALOS_CLUSTER_ENDPOINT=""
export TALOS_TEMPLATE_NAME=""
export TALOS_OVF_URL=""
export TALOS_CONTROL_PLANE_COUNT="3"
export TALOS_WORKER_COUNT="2"
export TALOS_CONTROL_PLANE_CPU="2"
export TALOS_CONTROL_PLANE_MEMORY_MB="4096"
export TALOS_CONTROL_PLANE_DISK_GB="20"
export TALOS_WORKER_CPU="2"
export TALOS_WORKER_MEMORY_MB="4096"
export TALOS_WORKER_DISK_GB="40"
export TALOS_CONTROL_PLANE_IPS=""
export TALOS_WORKER_IPS=""
export TALOS_GATEWAY=""
export TALOS_NETMASK_PREFIX="24"
export TALOS_NAMESERVERS=""
export TALOS_DOMAIN="infra.local"
export TALOS_CONTROL_PLANE_CONFIG_PATH=""
export TALOS_WORKER_CONFIG_PATH=""

# Optional local ISO path for upload automation
export ISO_LOCAL_PATH=""
