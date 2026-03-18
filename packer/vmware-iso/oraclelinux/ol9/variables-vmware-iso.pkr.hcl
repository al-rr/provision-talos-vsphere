# vmware-iso
variable "vmware_boot_wait" {
  type    = string
  default = null
}
variable "vmware_cdrom_adapter_type" {
  type        = string
  default     = "sata"
  description = "CDROM adapter type.  Needs to be SATA (or non-SCSI) for ARM64 builds."
}
variable "vmware_cores" {
  type        = number
  default     = 2
  description = "The number of virtual CPU cores per socket for the virtual machine"
}
variable "vmware_disk_adapter_type" {
  type        = string
  default     = "sata"
  description = "Disk adapter type.  Needs to be SATA (PVSCSI, or non-SCSI) for ARM64 builds."
}
variable "vmware_firmware" {
  type        = string
  default     = null
  description = "The firmware type for the virtual machine. Allowed values are bios, efi, and efi-secure (for secure boot). Defaults to the recommended firmware type for the guest operating system"
}
variable "vmware_guest_os_type" {
  type        = string
  default     = null
  description = "OS type for virtualization optimization"
}
variable "vmware_tools_upload_flavor" {
  type    = string
  default = null
}
variable "vmware_tools_upload_path" {
  type    = string
  default = null
}
variable "vmware_version" {
  type    = number
  default = 21
}
variable "vmware_vmx_data" {
  type    = map(string)
  default = null
}
variable "vmware_vmx_remove_ethernet_interfaces" {
  type    = bool
  default = true
}
variable "vmware_usb" {
  type        = bool
  default     = false
  description = "Enable the USB 2.0 controllers for the virtual machine"
}
variable "vmware_network_adapter_type" {
  type    = string
  default = "e1000e"
}
variable "vmware_network" {
  type    = string
  default = "nat"
}
variable "vmware_vnc_disable_password" {
  type    = bool
  default = true
}

# Source block common variables
variable "boot_command" {
  type        = list(string)
  default     = null
  description = "Commands to pass to gui session to initiate automated install"
}
variable "default_boot_wait" {
  type    = string
  default = null
}
variable "cd_content" {
  type        = map(string)
  default     = null
  description = "Content to be served by the cdrom"
}
variable "cd_files" {
  type    = list(string)
  default = null
}
variable "cd_label" {
  type    = string
  default = "cidata"
}
variable "cpus" {
  type    = number
  default = 2
}
variable "communicator" {
  type    = string
  default = null
}
variable "disk_size" {
  type    = number
  default = null
}
variable "floppy_files" {
  type    = list(string)
  default = null
}
variable "headless" {
  type        = bool
  default     = true
  description = "Start GUI window to interact with VM"
}
variable "http_directory" {
  type    = string
  default = null
}
variable "iso_checksum" {
  type        = string
  default     = null
  description = "ISO download checksum"
}
variable "iso_target_path" {
  type        = string
  default     = "build_dir_iso"
  description = "Path to store the ISO file. Null will use packer cache default or build_dir_iso will put it in the local build/iso directory."
}
variable "iso_url" {
  type        = string
  default     = null
  description = "ISO download url"
}
variable "memory" {
  type    = number
  default = null
}
variable "output_directory" {
  type    = string
  default = null
}
variable "shutdown_command" {
  type    = string
  default = null
}
variable "shutdown_timeout" {
  type    = string
  default = "15m"
}
variable "ssh_password" {
  type    = string
  default = "vagrant"
}
variable "ssh_port" {
  type    = number
  default = 22
}
variable "ssh_timeout" {
  type    = string
  default = "15m"
}
variable "ssh_username" {
  type    = string
  default = "vagrant"
}
variable "winrm_password" {
  type    = string
  default = "vagrant"
}
variable "winrm_timeout" {
  type    = string
  default = "60m"
}
variable "winrm_username" {
  type    = string
  default = "vagrant"
}
variable "vm_name" {
  type    = string
  default = null
}

# builder common block
variable "scripts" {
  type    = list(string)
  default = null
}

variable disk_type_id {
  type = string
  default = 0  
}
