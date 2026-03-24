output "haproxy_vm_name" {
  value = vsphere_virtual_machine.haproxy.name
}

output "haproxy_vm_default_ip" {
  value = vsphere_virtual_machine.haproxy.default_ip_address
}
