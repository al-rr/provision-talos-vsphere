# © Broadcom. All Rights Reserved.
# The term “Broadcom” refers to Broadcom Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-2-Clause

/*
    DESCRIPTION:
    Oracle Linux 9 build variables.
    Packer Plugin for VMware vSphere: 'vsphere-iso' builder.
*/

// EDITADO PARA TESTE.
vm_name                 = "oraclelinux-9-x86-64-template"
vm_disk_controller_type = ["sata"]
vsphere_resource_pool   = null
common_template_conversion = true
# vsphere_endpoint="odin.infra.al.rr.lan"
common_data_source = "disk"
# vsphere_set_host_for_datastore_uploads="false"
# vsphere_insecure_connection="true"

// Guest Operating System Metadata
vm_guest_os_name    = "oracle"
vm_guest_os_version = "9.6"
vm_network_card     = "e1000e"
vm_network_device   = "ens160"

// Virtual Machine Guest Operating System Setting
vm_guest_os_type = "oracleLinux8_64Guest"

// Virtual Machine Hardware Settings
# vm_firmware = "efi-secure"
vm_firmware = "efi"

// Removable Media Settings
# iso_datastore_path       = "iso/linux/oracle-linux/9/amd64"
iso_datastore_path         = "ISOs"
iso_content_library_item = "OracleLinux-R9-U6-x86_64-dvd"
iso_file                 = "OracleLinux-R9-U6-x86_64-dvd.iso"
common_iso_content_library_enabled = false
