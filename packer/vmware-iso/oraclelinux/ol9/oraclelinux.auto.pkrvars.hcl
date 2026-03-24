// Ansible Credentials
ansible_username = "ansible"
ansible_key      = "ssh-ed25519 CHANGE_ME_PUBLIC_KEY ansible@example.com"

// Default Account Credentials
build_username           = "build"
build_password           = "CHANGE_ME"
build_password_encrypted = "CHANGE_ME_ENCRYPTED_HASH"
build_key                = "ssh-ed25519 CHANGE_ME_PUBLIC_KEY packer@example.com"

// Guest Operating System Metadata
vm_name              = "oraclelinux-9"
vm_guest_os_type     = "oracleLinux9_64Guest"
vm_guest_os_name     = "oracle"
vm_guest_os_version  = "9.6"

iso_url      = "file://H:/Oracle/OracleLinux-R9-U5-x86_64-dvd.iso"
iso_checksum = "file:https://linux.oracle.com/security/gpg/checksum/OracleLinux-R9-U5-Server-x86_64.checksum"
boot_command = [
    "<esc><wait>",
    "linux inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<enter>"
]

cpus              = 2
memory            = 2048
disk_size        = 40960
vmware_disk_adapter_type = "sata"
disk_type_id      = 0

communicator              = "ssh"
ssh_username              = "build"
ssh_password              = "CHANGE_ME"
ssh_timeout               = "30m"
vmware_boot_wait          = "10s"
## Senão for bios, não funciona no Windows.
vmware_firmware           = "bios"
vmware_cdrom_adapter_type = "scsi"
http_directory            = "data"
shutdown_command          = "echo 'build' | sudo -S shutdown -P now"
output_directory          = "P:/IMAs/oraclelinux-9"
headless                  = true
