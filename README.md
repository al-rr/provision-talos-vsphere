# vSphere Talos Bootstrap

## Requirements

* VMware Workstation instalado no **host (Windows 10)**.
* Acesso com **privilégios de administrador** no Windows (vários comandos precisam de prompt elevado).
* Rede entre host e guest funcionando (host-only ou NAT). Confirme que você consegue **pingar** o host a partir do guest.
* Terminal no guest com `curl`/`nc` ou similares para testes.

## Steps

- set GOVC variables
- run script `00-setup.sh` to install `GOVCM` and `talosctl`
- run bootstrap.sh to create cluster Kubernetes

## Variables

## Lab Environment

- set variables values in Vagrantfile
- run `vagrant validate .`
- run vagrant up to start guest machine
- when the guest is uping, the script 00-setup.sh is executed.
- access the guest: vagrant ssh
- - run bootstrap.sh to create cluster Kubernetes


- marcar efi
- colocar disk.enableUUID=1
- remover disco removível

talosctl apply-config --insecure --nodes 192.168.0.250 --file worker.yaml --patch @../worker.patch.yaml