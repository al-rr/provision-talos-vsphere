packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
    vagrant = {
      version = "~> 1"
      source  = "github.com/hashicorp/vagrant"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.1"
    }
    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.6.3"
    }
  }
}

variable "build_username" {
  type        = string
  description = "The username to login to the guest operating system."
  sensitive   = true
  default     = "packer"
}


variable "build_password" {
  type        = string
  description = "The password to login to the guest operating system."
  sensitive   = true
  default     = "packer"
}

variable "build_password_encrypted" {
  type        = string
  description = "The SHA-512 encrypted password to login to the guest operating system."
  sensitive   = true
  default     = "$6$rounds=656000$e1a0c2f3d4b5c8d7$0j9v1xk5QmZg3z4J6Y5Fh8G5q5H5K5L5Q5L5Q5L5Q5L5Q5L5Q5L5Q"
}

variable "build_pub_key" {
  type        = string
  description = "The public key to login to the guest operating system."
  sensitive   = true
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCobT0gohts27nepbq4U89J3GjyH2n38bNZbHX7eXINIUom8duFI/Brsc+kcvTPm5xiEBlIahOI5BrxLwYfXixQSvDwdj3nGjFM3sCoDQjpT15JfdOsCpGE/DtNQKusoV32FI3O4Fosp0HDNHB6Dz2tK9AmR3+8ccYA0DRhNeDtMB0St2usVAO1Nci93/PxvLkDvFnux5W8IF4vPbHf9EtWYrQjcTSuLVqCZEzxaha5/muj7w6ILTyC/z4yrgAXrcUNdOUkFicbYKnSUirpO0YyASnDu+pIAef/d58eqY58lXv/0nzIcxI3it8cjDlwpq3h1tzsoCGJMRqUJgBGpJx1 dev-local"
}

variable common_data_source {
  type        = string
  description = "The data source to use for the kickstart file."
  default     = "cdrom"
}

variable iso_url {
  type        = string
  description = "The URL to the ISO file."
  default     = "/mnt/Oracle/OracleLinux-R9-U5-x86_64-dvd.iso"
}

variable iso_checksum {
  type        = string
  description = "The checksum of the ISO file."
  default     = "c2fa76c502cf1d93dfbd084d494d963ab7ea0a6f5535a083b8547b34037e88e1"
}

variable output_directory {
  type        = string
  description = "The output directory for the Vagrant box."
  default     = "/mnt/vms/vagrant-packer-exemplo"
}

locals {
  data_source_content = {
  "/ks.cfg" = file("${abspath(path.root)}/data/ks.cfg") }
  boot_command_string = var.common_data_source == "http" ? "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg" : "inst.ks=cdrom:/ks.cfg"
}


source "vmware-iso" "vagrant-packer-oraclelinux9" {

  // Configuração do Packer para criar uma imagem Vagrant do Oracle Linux 9
  vm_name = "vagrant-packer-exemplo"


  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  // Usuário e senha para SSH
  communicator     = "ssh"
  ssh_username     = var.build_username
  ssh_password     = var.build_password
  ssh_timeout      = "20m"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  # boot_command = [
  #   "<esc><wait>",
  #   "linux inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<enter>"
  # ]

  boot_command = [
    "<up><wait>",
    "e<wait>",
    "<down><down><end><wait>",
    "${local.boot_command_string}<wait>",
    "<enter><wait><leftCtrlOn>x<leftCtrlOff>"
  ]

  boot_wait = "5s"
  # http_directory = "data"
  http_content = var.common_data_source == "http" ? local.data_source_content : null
  cd_content   = var.common_data_source == "cdrom" ? local.data_source_content : null

  #  floppy_files = ["scripts/setup-user.sh"]

  // Hardware Configuration
  firmware = "efi"
  guest_os_type = "oracleLinux9_64Guest"
  cdrom_adapter_type = "ide"
  
  disk_size     = 40960
  #disk_adapter_type  = "nvme"
  #disk_type_id       = 0 # Growable virtual disk contained in a single file (monolithic sparse).
  # disk_additional_size = [10240, 10240] # Discos 2 e 3
  headless = false
  #tools_upload_flavor = "linux"
  cpus             = 2
  memory           = 2048
    output_directory = var.output_directory
  
}

build {
  sources = ["source.vmware-iso.vagrant-packer-oraclelinux9"]


  provisioner "shell" {
    inline = [
      "mkdir -p /home/${var.build_username}/.ssh",
      "echo '${var.build_pub_key}' >> /home/${var.build_username}/.ssh/authorized_keys",
      "chmod 700 /home/${var.build_username}/.ssh",
      "chmod 600 /home/${var.build_username}/.ssh/authorized_keys",
      "chown -R ${var.build_username}:${var.build_username} /home/${var.build_username}/.ssh"
    ]
  }
  # provisioner "file" {
  #   source      = var.ssh_pub_key
  #   destination = "/tmp/authorized_keys"
  # }

  # provisioner "shell" {
  #   inline = ["chmod 644 /tmp/authorized_keys"]
  # }

  # post-processor "vagrant" {
  #   output = "C:/Temp/oraclelinux810.box"
  # }
}
