#!/bin/bash
# Copyright 2024 Assembleia Legislativa do Estado de Roraima. Todos os direitos reservados.
# Author: Ednil Libanio da Costa Junior
# Date: 30-09-2024
# Este script permite definir as variáveis sensíveis no contexto do ambiente do sistema operacional
# em vez de defini-las nos arquivos hcl do Packer.

# Ansible Credentials
ansible_username=""
ansible_key=""

# GitHub Credentials
gh_username=""
gh_token=""

# Default Account Credentials
build_username=""
build_password=""
build_password_encrypted=""
build_key=""

# Red Hat Subscription Manager Credentials
rhsm_username="uytryu@gmail.com"
rhsm_password=""

# vSphere Credentials
vsphere_endpoint="vcenter.infra.al.rr.lan"
vsphere_username="uytrytu@vsphere.local"
vsphere_password="XXXXX"
vsphere_insecure_connection="false"

# vSphere Settings
vsphere_datacenter="ALRR"
vsphere_cluster="Asgard"
vsphere_host="oiuyiuoy.infra.al.rr.lan"
vsphere_datastore="DatastoreCluster"
vsphere_network="VM Network"
vsphere_folder=""
vsphere_resource_pool=""
vsphere_set_host_for_datastore_uploads="false"
# Minha variavel extra
vsphere_api_timeout="10"

# Removable Media Settings
common_iso_datastore="datastore-sata-01"
common_iso_content_library="ALRR Content Library"
common_content_library_name="ALRR Content Library"
common_iso_content_library_enabled="false"

# Virtual Machine Settings
common_vm_version="19"
common_tools_upgrade_policy="true"
common_remove_cdrom="true"

# Template and Content Library Settings
common_template_conversion="false"
common_content_library="ALRR Content Library"
common_content_library_enabled="true"
common_content_library_ovf="true"
# Novos
common_content_library_destroy="true"
common_content_library_skip_export="false"

# OVF Export Settings
common_ovf_export_enabled="false"
common_ovf_export_overwrite="true"

# Boot and Provisioning Settings
common_data_source="http"
common_http_ip=""
common_http_port_min="8000"
common_http_port_max="8099"
common_ip_wait_timeout="20m"
common_ip_settle_timeout="5s"
common_shutdown_timeout="15m"

# Proxy Credentials
use_socks_proxy="false"
communicator_proxy_host=""
communicator_proxy_port=""
communicator_proxy_username=""
communicator_proxy_password=""

# HCP Packer
# Novo
common_hcp_packer_registry_enabled="false"

# Packer Logging
echo -e '\n> Setting the Packer Logging...'
log_dir="/tmp/packer"
mkdir -p "${log_dir}"
export PACKER_LOG=1
export PACKER_LOG_PATH="${log_dir}/packer.log"

echo -e '\n> Setting the vSphere credentials...'
# vSphere Credentials
export PKR_VAR_vsphere_endpoint="${vsphere_endpoint}"
export PKR_VAR_vsphere_username="${vsphere_username}"
export PKR_VAR_vsphere_password="${vsphere_password}"
export PKR_VAR_vsphere_insecure_connection="${vsphere_insecure_connection}"

echo '> Setting the vSphere settings...'
# vSphere Settings
export PKR_VAR_vsphere_datacenter="${vsphere_datacenter}"
export PKR_VAR_vsphere_cluster="${vsphere_cluster}"
export PKR_VAR_vsphere_host="${vsphere_host}"
export PKR_VAR_vsphere_datastore="${vsphere_datastore}"
export PKR_VAR_vsphere_network="${vsphere_network}"
export PKR_VAR_vsphere_folder="${vsphere_folder}"
export PKR_VAR_vsphere_resource_pool="${vsphere_resource_pool}"
export PKR_VAR_vsphere_set_host_for_datastore_uploads="${vsphere_set_host_for_datastore_uploads}"
export PKR_VAR_common_content_library_name="${common_content_library_name}"
export PKR_VAR_common_iso_datastore="${common_iso_datastore}"
export PKR_VAR_common_iso_content_library="${common_iso_content_library}"

echo '> Setting the common virtual machine settings...'
# Virtual Machine Settings
export PKR_VAR_common_vm_version="${common_vm_version}"
export PKR_VAR_common_tools_upgrade_policy="${common_tools_upgrade_policy}"
export PKR_VAR_common_remove_cdrom="${common_remove_cdrom}"

echo '> Setting the common template and content library settings...'
# Template and Content Library Settings
export PKR_VAR_common_template_conversion="${common_template_conversion}"
export PKR_VAR_common_content_library_ovf="${common_content_library_ovf}"
export PKR_VAR_common_content_library_destroy="${common_content_library_destroy}"
export PKR_VAR_common_content_library_skip_export="${common_content_library_skip_export}"

echo '> Setting the OVF export settings...'
# OVF Export Settings
export PKR_VAR_common_ovf_export_enabled="${common_ovf_export_enabled}"
export PKR_VAR_common_ovf_export_overwrite="${common_ovf_export_overwrite}"

echo '> Setting the common boot and provisioning settings...'
# Boot and Provisioning Settings
export PKR_VAR_common_data_source="${common_data_source}"
export PKR_VAR_common_http_ip="${common_http_ip}"
export PKR_VAR_common_http_port_min="${common_http_port_min}"
export PKR_VAR_common_http_port_max="${common_http_port_max}"
export PKR_VAR_common_ip_wait_timeout="${common_ip_wait_timeout}"
export PKR_VAR_common_ip_settle_timeout="${common_ip_settle_timeout}"
export PKR_VAR_common_shutdown_timeout="${common_shutdown_timeout}"

# Proxy Credentials
if [ "$use_socks_proxy" == "true" ]; then

	echo '> Setting the proxy credentials...'
	export PKR_VAR_communicator_proxy_host="${communicator_proxy_host}"
	export PKR_VAR_communicator_proxy_port="${communicator_proxy_port}"
	export PKR_VAR_communicator_proxy_username="${communicator_proxy_username}"
	export PKR_VAR_communicator_proxy_password="${communicator_proxy_password}"

fi

echo '> Setting the default account credentials...'
# Default Account Credentials
export PKR_VAR_build_username="${build_username}"
export PKR_VAR_build_password="${build_password}"
export PKR_VAR_build_password_encrypted="${build_password_encrypted}"
export PKR_VAR_build_key="${build_key}"

echo '> Setting the Ansible credentials...'
# Ansible Credentials
export PKR_VAR_ansible_username="${ansible_username}"
export PKR_VAR_ansible_key="${ansible_key}"

echo '> Setting the RedHat Subscription Manager credentials...'
# Red Hat Subscription Manager Credentials
export PKR_VAR_rhsm_username="${rhsm_username}"
export PKR_VAR_rhsm_password="${rhsm_password}"
echo
