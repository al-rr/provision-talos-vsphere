# Ubuntu 24.04 LTS profile defaults for lab/vSphere.
vm_name_prefix          = "ubuntu-24-04-lts-template"
vm_name_timestamp_enabled = true
vsphere_resource_pool   = null
common_data_source      = "disk"
# ESXi standalone does not support convert_to_template. Keep as golden VM.
common_template_conversion = false

# Guest OS metadata
vm_guest_os_name        = "ubuntu"
vm_guest_os_version     = "24.04-lts"
vm_guest_os_type        = "ubuntu64Guest"

# VM networking
vm_network_card         = "e1000e"
vm_network_device       = "ens160"

# VM hardware
vm_firmware             = "efi"
vm_disk_controller_type = ["sata"]
vm_boot_wait            = "10s"

# ISO on datastore
iso_datastore_path                 = "ISOs"
iso_content_library_item           = "ubuntu-24.04.3-live-server-amd64"
iso_file                           = "ubuntu-24.04.3-live-server-amd64.iso"
common_iso_content_library_enabled = false

# Optional extra packages via autoinstall
additional_packages = []
