variable "ansible_key" {
  type    = string
  default = null
}

variable "ansible_username" {
  type    = string
  default = null
}

variable "build_username" {
  type        = string
  description = "The username to login to the guest operating system."
  sensitive   = true
}


variable "build_password" {
  type        = string
  description = "The password to login to the guest operating system."
  sensitive   = true
}

variable "build_password_encrypted" {
  type        = string
  description = "The SHA-512 encrypted password to login to the guest operating system."
  sensitive   = true
}

variable "build_key" {
  type        = string
  description = "The public key to login to the guest operating system."
  sensitive   = true
}

variable common_data_source {
  type        = string
  description = "The data source to use for the kickstart file."
  default     = "http"
}

// Virtual Machine Settings

variable "vm_guest_os_language" {
  type        = string
  description = "The guest operating system language."
  default     = "en_US"
}

variable "vm_guest_os_keyboard" {
  type        = string
  description = "The guest operating system keyboard input."
  default     = "us"
}

variable "vm_guest_os_timezone" {
  type        = string
  description = "The guest operating system timezone."
  default     = "UTC"
}

variable "vm_guest_os_family" {
  type        = string
  description = "The guest operating system family. Used for naming and VMware Tools."
  default     = "linux"
}

variable "vm_guest_os_name" {
  type        = string
  description = "The guest operating system name. Used for naming."
}

variable "vm_guest_os_version" {
  type        = string
  description = "The guest operating system version. Used for naming."
}

variable "vm_guest_os_type" {
  type        = string
  description = "The guest operating system type, also know as guestid."
}

variable "vm_guest_os_cloudinit" {
  type        = bool
  description = "Enable cloud-init for the guest operating system."
  default     = false
}

// Additional Settings

variable "additional_packages" {
  type        = list(string)
  description = "Additional packages to install."
  default     = []
}