# Oracle Linux 8 Template

Este template de imagem é construído para criar máquinas virtuais baseadas no Oracle Linux 8 no vSphere 6.7. Ele segue as melhores práticas de segurança e performance para o ambiente de produção.

## O que está incluído

- **Sistema Operacional**: Oracle Linux 8
- **Particionamento**: 
  - `/boot`: 500 MB
  - `/`: 30 GB
  - `swap`: 2 GB
- **Customizações**: 
  - Instalação do OpenSSH.
  - Hardening de segurança básico (desativação de root login via SSH, firewall configurado).
  - Suporte ao Ansible para automação futura.
  
## Scripts e Configurações

- **scripts/setup.sh**: Script responsável por instalar e configurar pacotes adicionais.
- **Packer Config**: O arquivo `ol8-template.json` define a configuração do Packer para a criação desta imagem.

## Como Usar

Para criar este template, certifique-se de estar no diretório `ol8-template` e execute o comando:

```bash
packer build ol8-template.pkr.hcl
