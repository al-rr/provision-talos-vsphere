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
  default     = ""
  description = "Cluster name when targeting vCenter inventory"
}

variable "host" {
  type        = string
  default     = ""
  description = "Standalone ESXi host name when no cluster is used"
}

variable "resource_pool" {
  type        = string
  default     = ""
  description = "Resource pool name. Empty uses the cluster or host root pool"
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
  description = "VM folder path"
}

variable "cluster_name" {
  type        = string
  default     = "talos-prod"
  description = "Logical cluster name used for VM naming"
}

variable "cluster_endpoint" {
  type        = string
  description = "Canonical Kubernetes endpoint, normally the HAProxy VIP or DNS name"
}

variable "talos_template_name" {
  type        = string
  description = "Talos VM template name already present in vSphere"
}

variable "talos_ovf_url" {
  type        = string
  default     = ""
  description = "Reserved for a future OVA-based workflow"
}

variable "control_plane_count" {
  type        = number
  default     = 3
  description = "Number of control plane nodes"
}

variable "worker_count" {
  type        = number
  default     = 2
  description = "Number of worker nodes"
}

variable "control_plane_cpu" {
  type    = number
  default = 2
}

variable "control_plane_memory_mb" {
  type    = number
  default = 4096
}

variable "control_plane_disk_gb" {
  type    = number
  default = 20
}

variable "worker_cpu" {
  type    = number
  default = 2
}

variable "worker_memory_mb" {
  type    = number
  default = 4096
}

variable "worker_disk_gb" {
  type    = number
  default = 40
}

variable "control_plane_ips" {
  type        = list(string)
  default     = []
  description = "Expected control plane IPs for documentation and outputs"
}

variable "worker_ips" {
  type        = list(string)
  default     = []
  description = "Expected worker IPs for documentation and outputs"
}

variable "talos_gateway" {
  type        = string
  default     = ""
  description = "Documented gateway used by generated Talos configs"
}

variable "talos_netmask_prefix" {
  type        = number
  default     = 24
  description = "Documented prefix used by generated Talos configs"
}

variable "talos_nameservers" {
  type        = list(string)
  default     = []
  description = "Documented nameservers used by generated Talos configs"
}

variable "talos_domain" {
  type        = string
  default     = "infra.local"
  description = "Domain used for VM metadata and annotations"
}

variable "control_plane_config_path" {
  type        = string
  description = "Path to the generated Talos control plane machine config"
}

variable "worker_config_path" {
  type        = string
  description = "Path to the generated Talos worker machine config"
}
