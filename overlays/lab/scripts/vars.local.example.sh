#!/usr/bin/env bash
# Local-only overrides for lab environment.
# Copy to overlays/lab/scripts/vars.local.sh and edit values.
# This file is ignored by git.

# VMware credentials and endpoint-specific values
export VSPHERE_ENDPOINT="CHANGE_ME"
export VSPHERE_USERNAME="CHANGE_ME"
export VSPHERE_PASSWORD="CHANGE_ME"

# Sensitive build and remote access values
export BUILD_PASSWORD="CHANGE_ME"
export BUILD_PASSWORD_ENCRYPTED="CHANGE_ME"
export BUILD_KEY="CHANGE_ME_PUBLIC_KEY"
export SSH_PRIVATE_KEY_FILE="CHANGE_ME"
export ANSIBLE_PRIVATE_KEY_FILE="CHANGE_ME"

# Optional local topology overrides (if you do not want these values in git)
# export HAPROXY_VIP="192.168.0.30"
# export TALOS_CONTROL_PLANE_IPS='["192.168.0.61","192.168.0.62","192.168.0.63"]'
# export TALOS_WORKER_IPS='["192.168.0.71","192.168.0.72","192.168.0.73"]'
