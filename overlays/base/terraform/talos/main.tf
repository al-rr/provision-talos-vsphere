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
  count         = var.cluster != "" ? 1 : 0
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_host" "host" {
  count         = var.cluster == "" && var.host != "" ? 1 : 0
  name          = var.host
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  count         = var.resource_pool != "" ? 1 : 0
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
  name          = var.talos_template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

locals {
  resource_pool_id = var.resource_pool != "" ? data.vsphere_resource_pool.pool[0].id : (
    var.cluster != "" ? data.vsphere_compute_cluster.cluster[0].resource_pool_id : data.vsphere_host.host[0].resource_pool_id
  )

  control_plane_names = [for idx in range(var.control_plane_count) : format("%s-cp-%02d", var.cluster_name, idx + 1)]
  worker_names        = [for idx in range(var.worker_count) : format("%s-worker-%02d", var.cluster_name, idx + 1)]
  control_plane_ips   = length(var.control_plane_ips) == var.control_plane_count ? var.control_plane_ips : [for _ in range(var.control_plane_count) : ""]
  worker_ips          = length(var.worker_ips) == var.worker_count ? var.worker_ips : [for _ in range(var.worker_count) : ""]

  control_plane_config_b64 = base64encode(file(var.control_plane_config_path))
  worker_config_b64        = base64encode(file(var.worker_config_path))
}

resource "vsphere_virtual_machine" "control_plane" {
  count            = var.control_plane_count
  name             = local.control_plane_names[count.index]
  folder           = var.folder == "" ? null : var.folder
  resource_pool_id = local.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus  = var.control_plane_cpu
  memory    = var.control_plane_memory_mb
  guest_id  = data.vsphere_virtual_machine.template.guest_id
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  firmware         = "efi"
  enable_disk_uuid = true
  annotation       = "role=control-plane endpoint=${var.cluster_endpoint} expected_ip=${local.control_plane_ips[count.index]}"

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = length(data.vsphere_virtual_machine.template.network_interface_types) > 0 ? data.vsphere_virtual_machine.template.network_interface_types[0] : "vmxnet3"
  }

  disk {
    label            = "disk0"
    size             = var.control_plane_disk_gb
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  extra_config = {
    "disk.enableUUID"          = "1"
    "guestinfo.talos.config"   = local.control_plane_config_b64
    "guestinfo.talos.role"     = "control-plane"
    "guestinfo.talos.endpoint" = var.cluster_endpoint
  }
}

resource "vsphere_virtual_machine" "worker" {
  count            = var.worker_count
  name             = local.worker_names[count.index]
  folder           = var.folder == "" ? null : var.folder
  resource_pool_id = local.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus  = var.worker_cpu
  memory    = var.worker_memory_mb
  guest_id  = data.vsphere_virtual_machine.template.guest_id
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  firmware         = "efi"
  enable_disk_uuid = true
  annotation       = "role=worker endpoint=${var.cluster_endpoint} expected_ip=${local.worker_ips[count.index]}"

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = length(data.vsphere_virtual_machine.template.network_interface_types) > 0 ? data.vsphere_virtual_machine.template.network_interface_types[0] : "vmxnet3"
  }

  disk {
    label            = "disk0"
    size             = var.worker_disk_gb
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  extra_config = {
    "disk.enableUUID"          = "1"
    "guestinfo.talos.config"   = local.worker_config_b64
    "guestinfo.talos.role"     = "worker"
    "guestinfo.talos.endpoint" = var.cluster_endpoint
  }
}
