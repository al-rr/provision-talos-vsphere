// Ansible Credentials
ansible_username = "ansible"
ansible_key      = "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAHqWj5PfbkbGqiyhA2aJIpoWawhpu0AA/hn3xfvPD3cnhImhvp7lY72NfFJZYOcrv/iZQTAnjsprvn4ImvjjoXXNQEgiqmI0z9jZSNfcBEg7dyRATdt4hdsUuFx5ZfSXt2whE9TBNmysIih4y0YuBJWWXu0ImIzs+R27IMwFSbJzL8RVg== ansible@example.com"

// Default Account Credentials
build_username           = "ejunior"
build_password           = "VMw@re123!"
build_password_encrypted = "$6$KspR8KgZFVxDOiiF$n4hhyeSGgamrz25mqvOfnK5xm6blwDJftlQZy0H60pwRdPKXsf996/lLzFrfW0H/ZHoE.jEPgVmFZpmgce6jX0"
build_key                = "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBADwXV3rbRCWwhSr6aMkHukV5O7OGAEyUtAerj2anJHm3mwbOxlBU/uO4f0ELqo2GJcTALMC0aFrbvu9qonIH5VF7wBBfCP1cS5B92sUagVV9ldI/uo89e/7dVYC9maPsFaZq2G0/PLU0hZKOohq99Oxc2RMSiJaaenX/hNqx5xYSaK+CA== packer@example.com"

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
ssh_username              = "ejunior"
ssh_password              = "VMw@re123!"
ssh_timeout               = "30m"
vmware_boot_wait          = "10s"
## Senão for bios, não funciona no Windows.
vmware_firmware           = "bios"
vmware_cdrom_adapter_type = "scsi"
http_directory            = "data"
shutdown_command          = "echo 'ejunior' | sudo -S shutdown -P now"
output_directory          = "P:/IMAs/oraclelinux-9"
headless                  = true


