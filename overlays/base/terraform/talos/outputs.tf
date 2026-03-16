output "cluster_endpoint" {
  value = var.cluster_endpoint
}

output "control_plane_names" {
  value = vsphere_virtual_machine.control_plane[*].name
}

output "worker_names" {
  value = vsphere_virtual_machine.worker[*].name
}

output "documented_control_plane_ips" {
  value = local.control_plane_ips
}

output "documented_worker_ips" {
  value = local.worker_ips
}
