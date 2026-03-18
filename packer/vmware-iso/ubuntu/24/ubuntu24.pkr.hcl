packer {
  required_plugins {
    vmware = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/vmware"
    }
    vagrant = {
      version = "~> 1"
      source  = "github.com/hashicorp/vagrant"
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

source "vmware-iso" "ubuntu-24-x86-64" {
  vm_name      = var.vm_name
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  communicator = var.communicator
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  # ssh_port         = var.ssh_port
  ssh_timeout = var.ssh_timeout

  # cores              = var.vmware_cores
  cpus              = var.cpus
  memory            = var.memory
  disk_size         = var.disk_size
  disk_adapter_type = var.vmware_disk_adapter_type
  disk_type_id      = var.disk_type_id

  # VMware specific options
  firmware           = var.vmware_firmware
  cdrom_adapter_type = var.vmware_cdrom_adapter_type
  guest_os_type      = var.vmware_guest_os_type
  network_adapter_type = var.vmware_network_adapter_type
  # network            = var.vmware_network
  # version            = var.vmware_version
  # Source block common options  
  http_directory = var.http_directory
  boot_command   = var.boot_command
  boot_wait      = var.vmware_boot_wait

  # floppy_files    = var.floppy_files
  # headless       = var.headless
  headless         = true
  output_directory = "${var.output_directory != null ? var.output_directory : "output"}/${var.vm_name}"
  # output_directory = var.output_directory
  shutdown_command = var.shutdown_command
  shutdown_timeout = var.shutdown_timeout
}

build {
  sources = ["source.vmware-iso.ubuntu-24-x86-64"]
}
