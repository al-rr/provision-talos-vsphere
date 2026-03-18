#!/usr/bin/env bash
# @file vars-esxi-prod.sh
# @description ESXi/GOVC production-ready profile for HAProxy + Talos lab.

# HAProxy pair on ESXi (fixed addresses in this profile)
export HAPROXY_VIP="${HAPROXY_VIP:-192.168.0.250}"
export HAPROXY_NODE_1_NAME="${HAPROXY_NODE_1_NAME:-talos-lb-1}"
export HAPROXY_NODE_1_IP="${HAPROXY_NODE_1_IP:-192.168.0.243}"
export HAPROXY_NODE_2_NAME="${HAPROXY_NODE_2_NAME:-talos-lb-2}"
export HAPROXY_NODE_2_IP="${HAPROXY_NODE_2_IP:-192.168.0.249}"

# Talos cluster topology behind HAProxy VIP
export TALOS_CLUSTER_ENDPOINT="${TALOS_CLUSTER_ENDPOINT:-${HAPROXY_VIP}}"
export TALOS_OVA_PATH="${TALOS_OVA_PATH:-https://factory.talos.dev/image/903b2da78f99adef03cbbd4df6714563823f63218508800751560d3bc3557e40/v1.12.4/vmware-amd64.ova}"
export TALOS_CONTROL_PLANE_IPS="${TALOS_CONTROL_PLANE_IPS:-[\"192.168.0.88\",\"192.168.0.89\",\"192.168.0.90\"]}"
export TALOS_WORKER_IPS="${TALOS_WORKER_IPS:-[\"192.168.0.91\",\"192.168.0.92\"]}"

# GOVC naming defaults used by provision_haproxy.sh
export GOVC_VM_NAME_PREFIX="${GOVC_VM_NAME_PREFIX:-talos-lb}"
export GOVC_VM_COUNT="${GOVC_VM_COUNT:-2}"
export GOVC_VM_START_INDEX="${GOVC_VM_START_INDEX:-1}"
export GOVC_VM_STATIC_IPS="${GOVC_VM_STATIC_IPS:-[\"192.168.0.243\",\"192.168.0.249\"]}"
export GOVC_VM_GATEWAY="${GOVC_VM_GATEWAY:-192.168.0.2}"
export GOVC_VM_NETMASK_PREFIX="${GOVC_VM_NETMASK_PREFIX:-24}"
export GOVC_VM_NAMESERVERS="${GOVC_VM_NAMESERVERS:-[\"192.168.0.2\"]}"
export GOVC_VM_STATIC_INTERFACE="${GOVC_VM_STATIC_INTERFACE:-ens160}"
export GOVC_VM_ENFORCE_GUEST_STATIC_NETWORK="${GOVC_VM_ENFORCE_GUEST_STATIC_NETWORK:-true}"
export GOVC_VM_GUEST_USERNAME="${GOVC_VM_GUEST_USERNAME:-vagrant}"
export GOVC_VM_GUEST_PASSWORD="${GOVC_VM_GUEST_PASSWORD:-vagrant}"
