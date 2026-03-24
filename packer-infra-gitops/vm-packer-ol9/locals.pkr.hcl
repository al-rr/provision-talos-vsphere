# Copyright 2024 - Assembleia Legislativa de Roraima. Todos os direitos reservados.
# Author: Ednil Libanio da Costa Junior
# Date: 14-09-2024

locals {
  build_by   = "Built by: HashiCorp Packer ${packer.version}"
  build_date = formatdate("DD-MM-YYYY hh:mm ZZZ", timestamp())
  #  build_version     = data.git-repository.cwd.head
  #  build_description = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"
  iso_paths = {
    content_library = "${var.common_iso_content_library}/${var.iso_content_library_item}/${var.iso_file}",
    datastore       = "[${var.common_iso_datastore}] ${var.iso_datastore_path}/${var.iso_file}"
  }
  manifest_date   = formatdate("DD-MM-YYYY hh:mm:ss", timestamp())
  manifest_path   = "${path.cwd}/manifests/"
  manifest_output = "${local.manifest_path}${local.manifest_date}.json"
  ovf_export_path = "${path.cwd}/artifacts/${local.vm_name}"
  data_source_content = {
    "/ks.cfg" = templatefile("${abspath(path.root)}/data/ks.pkrtpl.hcl", {
      build_username           = var.build_username
      build_password           = var.build_password
      build_password_encrypted = var.build_password_encrypted
      build_user_gecos         = var.build_user_gecos
      vm_guest_os_language     = var.vm_guest_os_language
      vm_guest_os_keyboard     = var.vm_guest_os_keyboard
      vm_guest_os_timezone     = var.vm_guest_os_timezone
      vm_guest_os_cloudinit    = var.vm_guest_os_cloudinit
      network = templatefile("${abspath(path.root)}/data/network.pkrtpl.hcl", {
        device  = var.vm_network_device
        ip      = var.vm_ip_address
        netmask = var.vm_ip_netmask
        gateway = var.vm_ip_gateway
        dns     = var.vm_dns_list
      })
      storage             = templatefile("${abspath(path.root)}/data/storage.pkrtpl.hcl", {})
      additional_packages = join(" ", var.additional_packages)
    })
  }
  data_source_command = var.common_data_source == "http" ? "inst.ks=http://${var.packer_host}:${var.packer_ks_port}/ks.cfg" : "inst.ks=cdrom:/ks.cfg"

  # vm_name             = "${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}-${local.build_version}"
  template_name      = var.template_name
  vm_name            = var.vm_name
  bucket_name        = replace("${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}", ".", "")
  bucket_description = "${var.vm_guest_os_family} ${var.vm_guest_os_name} ${var.vm_guest_os_version}"
}