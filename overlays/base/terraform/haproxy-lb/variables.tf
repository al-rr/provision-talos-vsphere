variable "vsphere_server" {
  type        = string
  description = "vCenter or ESXi address"
}

variable "vsphere_user" {
  type        = string
  description = "vSphere username"
}

variable "vsphere_password" {
  type        = string
  sensitive   = true
  description = "vSphere user password"
}

variable "vsphere_allow_unverified_ssl" {
  type        = bool
  default     = true
  description = "Skip TLS certificate validation"
}

variable "datacenter" {
  type        = string
  description = "Datacenter name"
}

variable "cluster" {
  type        = string
  description = "Cluster name"
}

variable "resource_pool" {
  type        = string
  default     = ""
  description = "Resource Pool name. Empty uses the cluster root pool"
}

variable "datastore" {
  type        = string
  description = "Datastore name"
}

variable "network" {
  type        = string
  description = "VM port group"
}

variable "folder" {
  type        = string
  default     = ""
  description = "VM folder (optional)"
}

variable "template_name" {
  type        = string
  description = "Ubuntu template name created by Packer"
}

variable "vm_name" {
  type        = string
  default     = "haproxy-lb-01"
  description = "Load balancer VM name"
}

variable "vm_cpus" {
  type    = number
  default = 2
}

variable "vm_memory_mb" {
  type    = number
  default = 4096
}

variable "vm_disk_gb" {
  type    = number
  default = 40
}

variable "vm_ipv4_address" {
  type        = string
  description = "Static VM IP address"
}

variable "vm_ipv4_prefix" {
  type    = number
  default = 24
}

variable "vm_ipv4_gateway" {
  type        = string
  description = "VM gateway"
}

variable "vm_dns_servers" {
  type    = list(string)
  default = []
}

variable "vm_domain" {
  type    = string
  default = "infra.local"
}
