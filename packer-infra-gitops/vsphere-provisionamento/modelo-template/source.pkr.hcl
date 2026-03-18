# Copyright 2024 - Assembleia Legislativa de Roraima. Todos os direitos reservados.
# Author: Ednil Libanio da Costa Junior
# Date: 14-09-2024

//  BLOCK: source
//  Defines the builder configuration blocks.

source "vsphere-iso" "oraclelinux" {

  // vCenter Server Endpoint Settings
  vcenter_server = var.vsphere_endpoint
  // vSphere Credentials
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = var.vsphere_insecure_connection

  // vSphere Settings
  datacenter = var.vsphere_datacenter
  cluster    = var.vsphere_cluster
  // host                           = var.vsphere_host
  datastore                      = var.vsphere_datastore
  folder                         = var.vsphere_folder
  resource_pool                  = var.vsphere_resource_pool
  set_host_for_datastore_uploads = var.vsphere_set_host_for_datastore_uploads

  // Virtual Machine Settings
  vm_name              = local.vm_name
  guest_os_type        = var.vm_guest_os_type
  firmware             = var.vm_firmware
  CPUs                 = var.vm_cpu_count
  cpu_cores            = var.vm_cpu_cores
  CPU_hot_plug         = var.vm_cpu_hot_add
  RAM                  = var.vm_mem_size
  RAM_hot_plug         = var.vm_mem_hot_add
  cdrom_type           = var.vm_cdrom_type
  disk_controller_type = ["pvscsi"] //var.vm_disk_controller_type
  storage {
    disk_size             = 26000
    disk_thin_provisioned = var.vm_disk_thin_provisioned
    disk_controller_index = 0
  }
  storage {
    disk_size             = 10000
    disk_thin_provisioned = var.vm_disk_thin_provisioned
    disk_controller_index = 0
  }
  network_adapters {
    network      = var.vsphere_network
    network_card = var.vm_network_card
  }
  vm_version           = var.common_vm_version
  remove_cdrom         = var.common_remove_cdrom
  reattach_cdroms      = var.vm_cdrom_count
  tools_upgrade_policy = var.common_tools_upgrade_policy
  // notes                = local.build_description

  // Removable Media Settings
  iso_paths    = var.common_iso_content_library_enabled ? [local.iso_paths.content_library] : [local.iso_paths.datastore]
  http_content = var.common_data_source == "http" ? local.data_source_content : null
  cd_content   = var.common_data_source == "disk" ? local.data_source_content : null
  // floppy_content = var.common_data_source == "floppy" ? local.data_source_content : null

  // Boot and Provisioning Settings
  boot_order    = var.vm_boot_order
  boot_wait     = var.vm_boot_wait
  http_ip       = var.common_data_source == "http" ? var.common_http_ip : null
  http_port_min = var.common_data_source == "http" ? var.common_http_port_min : null
  http_port_max = var.common_data_source == "http" ? var.common_http_port_max : null

  boot_command = [
    // This sends the "up arrow" key, typically used to navigate through boot menu options.
    "<up>",
    // This sends the "e" key. In the GRUB boot loader, this is used to edit the selected boot menu option.
    "e",
    // This sends two "down arrow" keys, followed by the "end" key, and then waits. This is used to navigate to a specific line in the boot menu option's configuration.
    "<down><down><end><wait>",
    // This types the string "text" followed by the value of the 'data_source_command' local variable.
    // This is used to modify the boot menu option's configuration to boot in text mode and specify the kickstart data source configured in the common variables.
    " inst.text ${local.data_source_command}",
    // This sends the "enter" key, waits, turns on the left control key, sends the "x" key, and then turns off the left control key. This is used to save the changes and exit the boot menu option's configuration, and then continue the boot process.
    "<enter><wait><leftCtrlOn>x<leftCtrlOff>"
  ]
  ip_wait_timeout   = var.common_ip_wait_timeout
  ip_settle_timeout = var.common_ip_settle_timeout
  shutdown_command  = "echo '${var.build_password}' | sudo -S -E shutdown -P now"
  shutdown_timeout  = var.common_shutdown_timeout

  // Communicator Settings and Credentials
  communicator       = "ssh"
  ssh_proxy_host     = var.communicator_proxy_host
  ssh_proxy_port     = var.communicator_proxy_port
  ssh_proxy_username = var.communicator_proxy_username
  ssh_proxy_password = var.communicator_proxy_password
  ssh_username       = var.build_username
  ssh_password       = var.build_password
  ssh_port           = var.communicator_port
  ssh_timeout        = var.communicator_timeout

  // Template and Content Library Settings
  convert_to_template = var.common_template_conversion
  dynamic "content_library_destination" {
    for_each = var.common_content_library_enabled ? [1] : []
    content {
      name    = local.template_name
      library = var.common_content_library
      //description = local.build_description
      ovf         = var.common_content_library_ovf
      destroy     = var.common_content_library_destroy
      skip_import = var.common_content_library_skip_export
    }
  }
  /*
  // OVF Export Settings
  dynamic "export" {
    for_each = var.common_ovf_export_enabled ? [1] : []
    content {
      name  = local.vm_name
      force = var.common_ovf_export_overwrite
      options = [
        "extraconfig"
      ]
      output_directory = local.ovf_export_path
    }
  }
  */
}