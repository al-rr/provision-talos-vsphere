# Modelo Base para Imagens vSphere com Packer

Este diretório serve como um **modelo base** para criar novas imagens que serão provisionadas no vSphere via Packer. Ele contém a estrutura necessária e os arquivos de variáveis que devem ser configurados para cada nova imagem.

## Estrutura de Arquivos e Pastas

- **data/**: Contém arquivos de kickstart (`.tpl`) e outros dados necessários para a customização da imagem.
- **locals.pkr.hcl**: Arquivo de variáveis locais usado no **build.pkr.hcl**.
- **ansible-variables.pkr.hcl**: Arquivo de variáveis relacionadas ao Ansible.
- **network-variables.pkr.hcl**: Variáveis de configuração de rede (ex.: IPs, sub-redes).
- **storage-variables.pkr.hcl**: Definições de disco, particionamento e volumes.
- **vsphere-variables.pkr.hcl**: Variáveis específicas do ambiente vSphere, como credenciais e paths.
- **global-variables.pkr.hcl**: Variáveis globais que podem ser reutilizadas em todos os projetos de imagem.
- **build.pkr.hcl**: Arquivo principal do Packer que define o build e provisionamento da imagem.
- **variables.pkr.hcl**: Arquivo principal do Packer que define o build e provisionamento da imagem.
- **variables.auto.pkrvars.hcl**: Arquivo principal do Packer que define o build e provisionamento da imagem.

## Como Criar uma Nova Imagem

Para criar uma nova imagem, siga os passos abaixo:

1. **Copie a pasta modelo**:
   
   ```bash
   cp -r model-template/ nova-imagem/

## Configuração de Hardware

### Requisitos de Hardware

| | |
| ---- | :-------------: |
| Nome | modelo-template |
| Memória (GB) | 1GB |
| Core CPU | 2 |
| Sistema Operacional | Oracle Linux 8.10 |
| Ambiente | Staging |
| Discos | 1 |
| Storage | 20 GB |

### Armazenamento

| **Disco** | **GB** | **Partição** |
| --------- | :----: | -------- |
| sda  | 32  | /boot, /boot/efi, /, /home, /tmp |
| sdb  | 200  | /var |
| sdc  | 20  | /var/log |
| sdd  | 50  | /tmp |

| **Partição** | **Mount** | **MiB** | **Tipo** | **Disco** |
| ------------ | :------:  | :----:  |:-------: | :-------: |
| boot         | /boot     | 1024    | xfs      | -         |
| efi          | /boot/efi | 1024    | fat32    | -         |
| pv.sysvg     |           | 20480    | lvmpv   | -         |
| pv.datavg    |           | 20480    | lvmpv   | -         |

| **Volume Group** | **Partição** |
| ---------------- | :---------:  |
| vg_ol            | /boot        | 
| vg_data          | /boot        | 


| **Volume** | **Mount** | **MiB** | **Tipo** | **Grupo** |
| ---------- | :------:  | :----:  |:-------: | :-------: |
| root       | /         | 6000    | xfs      | vg_ol     |
| home       | /home     | 5000    | xfs    | -         |
| pv.sysvg     |           | 20480    | lvmpv   | -         |
| pv.datavg    |           | 20480    | lvmpv   | -         |


# Disk partitioning information
part /boot --fstype="xfs" --ondisk=nvme0n1 --size=1024
part pv.8959 --fstype="lvmpv" --ondisk=nvme0n1 --size=25000
part pv.9852 --fstype="lvmpv" --ondisk=nvme0n2 --size=21000

volgroup vg_ol --pesize=4096 pv.8959
volgroup vg_data --pesize=4096 pv.9852

logvol /home --fstype="xfs" --size=5000 --name=home --vgname=vg_ol
logvol /tmp --fstype="xfs" --size=2000 --name=tmp --vgname=vg_ol
logvol /var/log --fstype="xfs" --size=2000 --name=var_log --vgname=ovg_ol
logvol /var --fstype="xfs" --size=5000 --name=var --vgname=vg_ol
logvol swap --name=swap --grow --size=2000 --maxsize=4000 --vgname=vg_ol


| **Partição** | **GiB** | **MiB** | **Disco** |
| --------- | :--:  | :--: | :----: |
| /boot | 1 | 1024 | sda |
| /boot/efi | ~0.59 | 600 | sda |
| / | ~19.5 | 20000 | sda |
| /home | ~9.8 | 9984 | sda |
| /var | ~195.3 | 70016 | sdb |
| /var/log | ~19.5 | 19968 | sdc |
| /tmp | ~19.5 | 19968 | sdd |
