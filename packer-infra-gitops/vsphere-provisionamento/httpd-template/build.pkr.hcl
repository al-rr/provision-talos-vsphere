# Copyright 2024 - Assembleia Legislativa de Roraima. Todos os direitos reservados.
# Author: Ednil Libanio da Costa Junior
# Date: 14-09-2024

packer {
  required_version = ">= 1.7.0"
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.4.0"
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

build {
  name = "modelo-template"

  sources = ["source.vsphere-iso.oraclelinux"]

  provisioner "shell" {
    inline = [
      "mkdir -p /home/${var.build_username}/.ssh",
      "echo '${var.ansible_key}' >> /home/${var.build_username}/.ssh/authorized_keys",
      "chmod 700 /home/${var.build_username}/.ssh",
      "chmod 600 /home/${var.build_username}/.ssh/authorized_keys",
      "chown -R ${var.build_username}:${var.build_username} /home/${var.build_username}/.ssh"
    ]
  }
  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
  }
}