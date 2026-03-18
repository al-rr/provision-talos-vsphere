// Ansible Credentials
ansible_username = "ansible"
ansible_key      = "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAHqWj5PfbkbGqiyhA2aJIpoWawhpu0AA/hn3xfvPD3cnhImhvp7lY72NfFJZYOcrv/iZQTAnjsprvn4ImvjjoXXNQEgiqmI0z9jZSNfcBEg7dyRATdt4hdsUuFx5ZfSXt2whE9TBNmysIih4y0YuBJWWXu0ImIzs+R27IMwFSbJzL8RVg== ansible@example.com"

# // Default Account Credentials
build_username           = "ejunior"
build_password           = "vagrant"
build_password_encrypted = "$6$rounds=4096$5CU3LEj/MQvbkfPb$LmKEF9pCfU8R.dA.GemgE/8GT6r9blge3grJvdsVTMFKyLEQwzEF3SGWqAzjawY/XHRpWj4fOiLBrRyxJhIRJ1"
build_key                = "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBADwXV3rbRCWwhSr6aMkHukV5O7OGAEyUtAerj2anJHm3mwbOxlBU/uO4f0ELqo2GJcTALMC0aFrbvu9qonIH5VF7wBBfCP1cS5B92sUagVV9ldI/uo89e/7dVYC9maPsFaZq2G0/PLU0hZKOohq99Oxc2RMSiJaaenX/hNqx5xYSaK+CA== packer@example.com"



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
ssh_username     = "ejunior"
ssh_password     = "vagrant"
ssh_timeout      = "30m"
vmware_boot_wait = "10s"
## Senão for bios, não funciona no Windows.
vmware_firmware           = "bios"
vmware_cdrom_adapter_type = "scsi"
http_directory            = "data"
shutdown_command          = "echo 'ejunior' | sudo -S shutdown -P now"
output_directory          = "P:/IMAs/ubuntu-24-x86-64"
headless                  = true


