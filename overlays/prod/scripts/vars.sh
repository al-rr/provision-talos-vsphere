#!/usr/bin/env bash
# @file vars.sh
# @description Production environment overrides for Talos and HAProxy.

BASE_VARS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../base/scripts" && pwd)/vars.sh"
# shellcheck source=/dev/null
source "${BASE_VARS}"

export OVERLAY_ENV="prod"
export VSPHERE_DATACENTER="ha-datacenter"
export HAPROXY_PACKER_OVERRIDE_FILE="overlays/prod/haproxy-lb/packer/esxi67-override.pkrvars.hcl"

# HAProxy topology
export HAPROXY_VIP="172.17.20.90"
export HAPROXY_NODE_1_NAME="haproxy-01"
export HAPROXY_NODE_1_IP="172.17.20.91"
export HAPROXY_NODE_2_NAME="haproxy-02"
export HAPROXY_NODE_2_IP="172.17.20.92"
export HAPROXY_STATS_USER="admin"
export HAPROXY_STATS_PASS="changeme"
export HAPROXY_FRONTENDS_BLOCK=$'frontend talos_k8s_api\n  bind *:6443\n  mode tcp\n  default_backend talos_k8s_api_backend'
export HAPROXY_BACKENDS_BLOCK=$'backend talos_k8s_api_backend\n  mode tcp\n  balance roundrobin\n  option tcp-check\n  server cp01 172.17.20.101:6443 check\n  server cp02 172.17.20.102:6443 check\n  server cp03 172.17.20.103:6443 check'
export TF_VM_NAME="haproxy-lb-01"
export TF_VM_IPV4_ADDRESS="172.17.20.91"
export TF_VM_IPV4_GATEWAY="172.17.20.1"

# Talos topology
export TALOS_CLUSTER_NAME="talos-prod"
export TALOS_CLUSTER_ENDPOINT="${HAPROXY_VIP}"
export TALOS_CONTROL_PLANE_IPS='["172.17.20.101","172.17.20.102","172.17.20.103"]'
export TALOS_WORKER_IPS='["172.17.20.111","172.17.20.112"]'
export TALOS_GATEWAY="172.17.20.1"
export TALOS_NAMESERVERS='["172.17.20.10","172.17.20.11"]'
export TALOS_CONTROL_PLANE_CONFIG_PATH="overlays/prod/talos/generated/controlplane.yaml"
export TALOS_WORKER_CONFIG_PATH="overlays/prod/talos/generated/worker.yaml"
