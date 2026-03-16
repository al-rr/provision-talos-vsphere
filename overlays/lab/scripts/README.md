# Lab Scripts

This directory is reserved for lab-controller bootstrap assets only.

Keep scripts here only when they prepare the Vagrant-based lab environment
itself, such as:

- bootstrapping the controller guest
- installing Ansible inside the lab controller
- installing lab-only dependencies

Do not keep reusable HAProxy, Talos, GOVC, Packer, or Terraform workflow
scripts here. Shared automation belongs in `overlays/base`. Environment
differences belong in `overlays/lab/scripts/vars.sh`.