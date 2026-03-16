# Overrides for Ubuntu 24 image build on vSphere/ESXi 6.7

# ESXi 6.7 supports up to virtual hardware version 15
common_vm_version = 15

# Better compatibility in environments without a robust Content Library workflow
common_content_library_enabled = false
common_template_conversion     = true
common_content_library_destroy = false

# Keep VMware Tools upgrade policy disabled for legacy environments
common_tools_upgrade_policy = false

# Avoid dependency on HTTP seed for cloud-init
common_data_source = "disk"

# Host-based datastore uploads are often more reliable on older ESXi setups
vsphere_set_host_for_datastore_uploads = true

# Ubuntu 24 with generic Linux 64-bit guest type
vm_guest_os_type = "ubuntu64Guest"
vm_firmware      = "efi"
