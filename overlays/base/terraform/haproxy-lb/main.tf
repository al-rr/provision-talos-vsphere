provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = var.vsphere_allow_unverified_ssl
}

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  count         = var.resource_pool == "" ? 0 : 1
  name          = var.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

locals {
  resource_pool_id = var.resource_pool == "" ? data.vsphere_compute_cluster.cluster.resource_pool_id : data.vsphere_resource_pool.pool[0].id
}

resource "vsphere_virtual_machine" "haproxy" {
  name             = var.vm_name
  folder           = var.folder == "" ? null : var.folder
  resource_pool_id = local.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = var.vm_cpus
  memory   = var.vm_memory_mb

  guest_id  = data.vsphere_virtual_machine.template.guest_id
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  firmware         = "efi"
  enable_disk_uuid = true

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = length(data.vsphere_virtual_machine.template.network_interface_types) > 0 ? data.vsphere_virtual_machine.template.network_interface_types[0] : "vmxnet3"
  }

  disk {
    label            = "disk0"
    size             = var.vm_disk_gb
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = var.vm_name
        domain    = var.vm_domain
      }

      network_interface {
        ipv4_address = var.vm_ipv4_address
        ipv4_netmask = var.vm_ipv4_prefix
      }

      ipv4_gateway    = var.vm_ipv4_gateway
      dns_server_list = var.vm_dns_servers
    }
  }

  extra_config = {
    "disk.enableUUID" = "1"
  }
}
