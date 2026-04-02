#!/usr/bin/env bash
# @file vars.local.example.sh
# @description Local overrides for packer module variables.
# Copy this file to vars.local.sh and edit values for your environment.

# vSphere connection and inventory
# export VSPHERE_ENDPOINT="192.168.0.233"
# export VSPHERE_USERNAME="root"
# export VSPHERE_PASSWORD="CHANGE_ME"
# export VSPHERE_INSECURE_CONNECTION="true"
# export VSPHERE_DATACENTER="Datacenter"
# export VSPHERE_CLUSTER="Cluster"
# export VSPHERE_HOST="192.168.0.200"
# export VSPHERE_DATASTORE="DATASTORE_02"
# export VSPHERE_NETWORK="VM Network"
# export VSPHERE_FOLDER=""
# export VSPHERE_RESOURCE_POOL=""
# export VSPHERE_SET_HOST_FOR_DATASTORE_UPLOADS="false"

# Build account
# export BUILD_USERNAME="vagrant"
# export BUILD_PASSWORD="vagrant"
# Optional when BUILD_PASSWORD is set; otherwise required.
# export BUILD_PASSWORD_ENCRYPTED=""
# export BUILD_KEY=""  # public key content or path to *.pub file
# export ANSIBLE_USERNAME=""  # optional; defaults to BUILD_USERNAME
# export ANSIBLE_KEY=""       # optional; defaults to BUILD_KEY

# Common settings
# export COMMON_DATA_SOURCE="disk"
# export COMMON_TEMPLATE_CONVERSION="false"
# export COMMON_OVF_EXPORT_ENABLED="false"
# export COMMON_OVF_EXPORT_OVERWRITE="true"
# export COMMON_ISO_DATASTORE="DATASTORE_02"
# export COMMON_ISO_CONTENT_LIBRARY="Content Library"
# export COMMON_ISO_CONTENT_LIBRARY_ENABLED="false"

# Optional proxy and logging
# export COMMUNICATOR_PROXY_HOST=""
# export COMMUNICATOR_PROXY_PORT=""
# export COMMUNICATOR_PROXY_USERNAME=""
# export COMMUNICATOR_PROXY_PASSWORD=""
# export PACKER_ENABLE_LOG="true"
# export PACKER_LOG_PATH="/tmp/packer/packer.log"
