// Ansible Credentials
ansible_username = "ansible"
ansible_key      = "ssh-ed25519 CHANGE_ME_PUBLIC_KEY ansible@example.com"

# // Default Account Credentials
build_username           = "build"
build_password           = "CHANGE_ME"
build_password_encrypted = "CHANGE_ME_ENCRYPTED_HASH"
build_key                = "ssh-ed25519 CHANGE_ME_PUBLIC_KEY packer@example.com"



// Guest Operating System Metadata
vm_name             = "ubuntu-24-x86-64"
vm_guest_os_type    = "ubuntu-64"
vm_guest_os_name    = "ubuntu"
vm_guest_os_version = "24.04"


iso_url      = "file://H:/Ubuntu/ubuntu-24.04.3-live-server-amd64.iso"
iso_checksum = "file:https://releases.ubuntu.com/noble/SHA256SUMS"
boot_command = ["<wait>e<wait><down><down><down><end> autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/<wait><f10><wait>"]

cpus              = 2
memory            = 2048
disk_size         = 40960
vmware_disk_adapter_type = "sata"
disk_type_id      = 0

communicator     = "ssh"
ssh_username     = "build"
ssh_password     = "CHANGE_ME"
ssh_timeout      = "30m"
vmware_boot_wait = "10s"
## Senão for bios, não funciona no Windows.
vmware_firmware           = "bios"
vmware_cdrom_adapter_type = "scsi"
http_directory            = "data"
shutdown_command          = "echo 'build' | sudo -S shutdown -P now"
output_directory          = "P:/IMAs/ubuntu-24-x86-64"
headless                  = true
