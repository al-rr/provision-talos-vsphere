#!/usr/bin/env bash
# @file vars.sh
# @description Default DNS module variables (dnsmasq VM lifecycle + service settings).

# DNS VM provisioning defaults (govc-backed)
export DNS_VM_COUNT="${DNS_VM_COUNT:-1}"
export DNS_VM_NAME_PREFIX="${DNS_VM_NAME_PREFIX:-talos-dns}"
export DNS_VM_START_INDEX="${DNS_VM_START_INDEX:-1}"

# Source image/template selection
# Prefer template in lab for stability; OVA can be used when explicitly set.
export DNS_VM_TEMPLATE_NAME="${DNS_VM_TEMPLATE_NAME:-${GOVC_VM_TEMPLATE_NAME:-}}"
export DNS_VM_OVA_PATH="${DNS_VM_OVA_PATH:-}"
export DNS_VM_OVF_PATH="${DNS_VM_OVF_PATH:-}"

# Compute/network defaults
export DNS_VM_CPUS="${DNS_VM_CPUS:-1}"
export DNS_VM_MEMORY_MB="${DNS_VM_MEMORY_MB:-1024}"
export DNS_VM_DISK_GB="${DNS_VM_DISK_GB:-20}"
export DNS_VM_NETMASK_PREFIX="${DNS_VM_NETMASK_PREFIX:-24}"
export DNS_VM_STATIC_INTERFACE="${DNS_VM_STATIC_INTERFACE:-ens160}"
export DNS_VM_GATEWAY="${DNS_VM_GATEWAY:-${TALOS_GATEWAY:-}}"
export DNS_VM_BOOTSTRAP_NAMESERVERS="${DNS_VM_BOOTSTRAP_NAMESERVERS:-1.1.1.1,8.8.8.8}"

# Guest access used for static network enforcement when enabled
export DNS_VM_GUEST_USERNAME="${DNS_VM_GUEST_USERNAME:-${BUILD_USERNAME:-${GOVC_VM_GUEST_USERNAME:-}}}"
export DNS_VM_GUEST_PASSWORD="${DNS_VM_GUEST_PASSWORD:-${BUILD_PASSWORD:-${GOVC_VM_GUEST_PASSWORD:-}}}"
export DNS_VM_GUEST_STATIC="${DNS_VM_GUEST_STATIC:-auto}"
export DNS_SSH_USER="${DNS_SSH_USER:-${DNS_VM_GUEST_USERNAME:-}}"
export DNS_CLOUDINIT_PASSWORD="${DNS_CLOUDINIT_PASSWORD:-${DNS_VM_GUEST_PASSWORD:-}}"
export DNS_CLOUDINIT_PUBLIC_KEY="${DNS_CLOUDINIT_PUBLIC_KEY:-${BUILD_KEY:-${ANSIBLE_KEY:-}}}"

# Optional fixed address for single DNS VM
export DNS_VM_STATIC_IP="${DNS_VM_STATIC_IP:-}"

# dnsmasq service-level defaults
export DNS_DOMAIN="${DNS_DOMAIN:-lab.local}"
export DNS_LISTEN_ADDRESSES="${DNS_LISTEN_ADDRESSES:-${DNS_VM_STATIC_IP:-}}"
export DNS_UPSTREAM_SERVERS="${DNS_UPSTREAM_SERVERS:-1.1.1.1,8.8.8.8}"
export DNS_A_RECORDS="${DNS_A_RECORDS:-}"
