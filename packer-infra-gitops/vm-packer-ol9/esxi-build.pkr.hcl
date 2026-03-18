packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.4.2"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.1"
    }
    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.6.3"
    }
  }
}

variable "build_username" {
  type        = string
  description = "The username to login to the guest operating system."
  sensitive   = true
  default     = "packer"
}


variable "build_password" {
  type        = string
  description = "The password to login to the guest operating system."
  sensitive   = true
  default     = "packer"
}

variable "build_password_encrypted" {
  type        = string
  description = "The SHA-512 encrypted password to login to the guest operating system."
  sensitive   = true
  default     = "$6$rounds=656000$e1a0c2f3d4b5c8d7$0j9v1xk5QmZg3z4J6Y5Fh8G5q5H5K5L5Q5L5Q5L5Q5L5Q5L5Q5L5Q"
}

variable "build_pub_key" {
  type        = string
  description = "The public key to login to the guest operating system."
  sensitive   = true
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCobT0gohts27nepbq4U89J3GjyH2n38bNZbHX7eXINIUom8duFI/Brsc+kcvTPm5xiEBlIahOI5BrxLwYfXixQSvDwdj3nGjFM3sCoDQjpT15JfdOsCpGE/DtNQKusoV32FI3O4Fosp0HDNHB6Dz2tK9AmR3+8ccYA0DRhNeDtMB0St2usVAO1Nci93/PxvLkDvFnux5W8IF4vPbHf9EtWYrQjcTSuLVqCZEzxaha5/muj7w6ILTyC/z4yrgAXrcUNdOUkFicbYKnSUirpO0YyASnDu+pIAef/d58eqY58lXv/0nzIcxI3it8cjDlwpq3h1tzsoCGJMRqUJgBGpJx1 dev-local"
}

variable common_data_source {
  type        = string
  description = "The data source to use for the kickstart file."
  default     = "cdrom"
}

variable iso_url {
  type        = string
  description = "The URL to the ISO file."
  default     = "/mnt/Oracle/OracleLinux-R9-U5-x86_64-dvd.iso"
}

variable iso_checksum {
  type        = string
  description = "The checksum of the ISO file."
  default     = "c2fa76c502cf1d93dfbd084d494d963ab7ea0a6f5535a083b8547b34037e88e1"
}

variable output_directory {
  type        = string
  description = "The output directory for the Vagrant box."
  default     = "/mnt/vms/vagrant-packer-exemplo"
}

locals {
  data_source_content = {
  "/ks.cfg" = file("${abspath(path.root)}/data/ks.cfg") }
  boot_command_string = var.common_data_source == "http" ? "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg" : "inst.ks=cdrom:/ks.cfg"
}


source "vsphere-iso" "packer-exemplo" {

  // vSphere Credentials
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = var.vsphere_insecure_connection

  // vSphere Settings
  host                           = var.vsphere_host
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
  
}




build {
  name = "modelo-template"

  sources = ["source.vsphere-iso.oraclelinux"]

  provisioner "shell" {
    inline = [
      "mkdir -p /home/${var.build_username}/.ssh",
      "echo '${var.ansible_key}' >> /home/${var.build_username}/.ssh/authorized_keys",
      "chmod 700 /home/${var.build_username}/.ssh",
      "chmod 600 /home/${var.build_username}/.ssh/authorized_keys",
      "chown -R ${var.build_username}:${var.build_username} /home/${var.build_username}/.ssh"
    ]
  }
  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
  }
}
