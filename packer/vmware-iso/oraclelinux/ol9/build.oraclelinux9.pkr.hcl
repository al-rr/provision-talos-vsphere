packer {
  required_version = ">= 1.12.0"
  required_plugins {
    vmware = {
      version = "~> 1.2.0"
      source  = "github.com/hashicorp/vmware"
    }

    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.4.2"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.2"
    }
    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.6.3"
    }
  }

}

source "vmware-iso" "oraclelinux-9" {
  vm_name          = var.vm_name
  iso_url          = var.iso_url
  iso_checksum   = var.iso_checksum
  # iso_target_path = abspath(var.iso_target_path)

  communicator = var.communicator
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  # ssh_port         = var.ssh_port
  ssh_timeout      = var.ssh_timeout

  # cores              = var.vmware_cores
  cpus         = var.cpus
  memory           = var.memory
  disk_size    = var.disk_size
  disk_adapter_type  = var.vmware_disk_adapter_type
  disk_type_id     = var.disk_type_id

  # VMware specific options
  firmware           = var.vmware_firmware
  cdrom_adapter_type = var.vmware_cdrom_adapter_type
  guest_os_type      = var.vmware_guest_os_type
  network_adapter_type = var.vmware_network_adapter_type
  # network            = var.vmware_network
  # version            = var.vmware_version
  # Source block common options  
  http_directory = var.http_directory
  boot_command = var.boot_command
  boot_wait    = var.vmware_boot_wait  
  
  # floppy_files    = var.floppy_files
  # headless       = var.headless
  headless       = true
  output_directory = "${var.output_directory != null ? var.output_directory : "output"}/${var.vm_name}"
  # output_directory = var.output_directory
  shutdown_command = var.shutdown_command
  shutdown_timeout = var.shutdown_timeout  
  
}

# source "vmware-iso" "oraclelinux-9" {
#   # VMware specific options
#   # ISO do Oracle Linux (ajuste o caminho conforme o seu ambiente)
#   iso_url      = "file://H:/Oracle/OracleLinux-R9-U5-x86_64-dvd.iso"
#   iso_checksum = "none"

#   communicator = "ssh"
#   ssh_username = "packer"
#   ssh_password = "VMw@re123!"
#   ssh_timeout  = "30m"

#   # Configurações de hardware
#   guest_os_type     = "oracleLinux9_64Guest"
#   cpus              = 2
#   memory            = 2048
#   disk_size         = 40960
#   disk_adapter_type = "sata"
#   disk_type_id      = 0
#   # Boot automático via HTTP Kickstart
#   # O instalador será instruído a ler o ks.cfg do CD-ROM
#   boot_wait = "10s"
#   ## Senão for bios, não funciona no Windows.
#   firmware           = "bios"
#   cdrom_adapter_type = "scsi"

#   http_directory = "data"
#   boot_command = [
#     "<esc><wait>",
#     "linux inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<enter>"
#   ]


#   shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"
#   output_directory = "P:/IMAs/oraclelinux-9"
#   headless         = true
# }

build {

  sources = ["source.vmware-iso.oraclelinux-9"]

  # provisioner "ansible" {
  #   user                   = var.build_username
  #   galaxy_file            = "${path.cwd}/ansible/linux-requirements.yml"
  #   galaxy_force_with_deps = true
  #   playbook_file          = "${path.cwd}/ansible/linux-playbook.yml"
  #   roles_path             = "${path.cwd}/ansible/roles"
  #   ansible_env_vars = [
  #     "ANSIBLE_CONFIG=${path.cwd}/ansible/ansible.cfg",
  #     "ANSIBLE_PYTHON_INTERPRETER=/usr/libexec/platform-python"
  #   ]
  #   extra_arguments = [
  #     "--extra-vars", "display_skipped_hosts=false",
  #     "--extra-vars", "build_username=${var.build_username}",
  #     "--extra-vars", "build_key='${var.build_key}'",
  #     "--extra-vars", "ansible_username=${var.ansible_username}",
  #     "--extra-vars", "ansible_key='${var.ansible_key}'",
  #     "--extra-vars", "enable_cloudinit=${var.vm_guest_os_cloudinit}",
  #   ]
  # }

  # post-processor "manifest" {
  #   output     = local.manifest_output
  #   strip_path = true
  #   strip_time = true
  #   custom_data = {
  #     ansible_username         = var.ansible_username
  #     build_username           = var.build_username
  #     build_date               = local.build_date
  #     build_version            = local.build_version
  #     common_data_source       = var.common_data_source
  #     common_vm_version        = var.common_vm_version
  #     vm_cpu_cores             = var.vm_cpu_cores
  #     vm_cpu_count             = var.vm_cpu_count
  #     vm_disk_size             = var.vm_disk_size
  #     vm_disk_thin_provisioned = var.vm_disk_thin_provisioned
  #     vm_firmware              = var.vm_firmware
  #     vm_guest_os_type         = var.vm_guest_os_type
  #     vm_mem_size              = var.vm_mem_size
  #     vm_network_card          = var.vm_network_card
  #     vsphere_cluster          = var.vsphere_cluster
  #     vsphere_host             = var.vsphere_host
  #     vsphere_datacenter       = var.vsphere_datacenter
  #     vsphere_datastore        = var.vsphere_datastore
  #     vsphere_endpoint         = var.vsphere_endpoint
  #     vsphere_folder           = var.vsphere_folder
  #   }
  # }

  # provisioner "shell" {
  #   scripts = [
  #     "${path.root}/../../scripts/oraclelinux/update.sh",
  #     "${path.root}/../../scripts/oraclelinux/provision.sh",
  #     "${path.root}/../../scripts/oraclelinux/cleanup.sh",
  #   ]
  # }

  # post-processor "manifest" {
  #   output     = local.manifest_output
  #   strip_path = true
  #   strip_time = true
  # }
}
