# vSphere Provisionamento com Packer

Este projeto faz parte do repositório principal `infra-gitops` e é responsável pela criação de templates de máquinas virtuais para o ambiente vSphere (versão 6.7) no vCenter. Utilizamos o [Packer](https://www.packer.io/) para automatizar a criação dessas imagens, que posteriormente são armazenadas na **Content Library** do vSphere e provisionadas por meio do Terraform.


## Dependências

Este projeto depende da imagem ``assembleiarr/packer-alpine``.

## Pré-requisitos

Antes de inicializar esse projeto, siga os passos do ../README.md.

Este ambiente foi configurado para funcionar no ambiente OL/RHEL/CentOS.

1. Docker
2. Direnv
3. Imagem assembleiarr/packer-alpine


## configuração `.envrc`
As variaveis no arquivo .envrc dependem das variaveis definidas no arquivo `gitops.env` na raiz do projeto.

## Configuração Packer Kickstart Port
firewall-cmd --add-port=${PACKER_KS_PORT}/tcp --permanent
firewall-cmd --reload



## Estrutura do Projeto

- **vsphere-provisionamento/**: Diretório onde são mantidas todas as definições de imagens relacionadas ao ambiente vSphere.
- **Imagens (Templates)**: Cada subpasta dentro de `vsphere-provisionamento` representa um template de imagem, com suas configurações específicas.
- **gitops.env**: Arquivo na raiz do projeto com variáveis globais compartilhadas entre Packer e Terraform, como credenciais e configurações do vSphere.

## Diretrizes para Criação de Imagens

- **Nomenclatura**: O nome de cada subpasta reflete o propósito da imagem, como `ol8-template` ou `apache-template`.
- **Content Library**: Todas as imagens criadas serão armazenadas na Content Library do vSphere para facilitar o gerenciamento e a reutilização.
- **Configuração Padrão**:
  - **Sistema Operacional**: As imagens devem usar o particionamento adequado para o sistema, com discos otimizados para o uso no vSphere.
  - **Segurança**: Seguir as políticas de segurança da empresa, garantindo a desativação de serviços desnecessários e a aplicação das melhores práticas de hardening.
  - **Automação**: Cada imagem deve ser configurada com as ferramentas de automação necessárias, como o **Ansible**, para facilitar o gerenciamento pós-provisionamento.
  
## Processos e Ferramentas

- **Packer**: Utilizado para definir e construir as imagens. O Packer lê os arquivos de configuração das imagens e as gera com base nos parâmetros definidos.
- **Terraform**: Usado para provisionar as máquinas virtuais a partir dos templates criados pelo Packer.

### Como Usar

1. Clone o repositório `infra-gitops`.
2. Configure suas variáveis de ambiente no arquivo `gitops.env`.
3. Para criar uma imagem específica, navegue até a pasta desejada dentro de `vsphere-provisionamento` e execute o comando do Packer para gerar a imagem.
4. Após a criação, a imagem será enviada para a Content Library e estará disponível para uso com o Terraform.

## Variáveis Globais

As variáveis globais utilizadas para este projeto estão centralizadas no arquivo `gitops.env` na raiz do repositório. As principais variáveis incluem:

- **VCENTER_SERVER**: Endereço do servidor vCenter.
- **VCENTER_USER**: Usuário com permissões para criar imagens no vCenter.
- **VCENTER_PASSWORD**: Senha do usuário.
- **CONTENT_LIBRARY**: Nome da Content Library onde as imagens serão armazenadas.
- **TEMPLATES_PATH**: Caminho no vSphere onde os templates serão criados.

---

## Estrutura das Pastas

Cada pasta dentro de `vsphere-provisionamento` corresponde a uma imagem/template específico. Essas pastas devem conter:

- Um arquivo `README.md` descrevendo os detalhes da imagem.
- O arquivo de configuração do Packer.
- Scripts de provisionamento ou customizações (se aplicável).

```
vsphere-provisionamento/
    ├── model-template/
    │   ├── data/
    │   │   ├── kickstart.tpl
    │   ├── ansible-variables.pkr.hcl.example
    │   ├── network-variables.pkr.hcl.example
    │   ├── storage-variables.pkr.hcl.example
    │   ├── vsphere-variables.pkr.hcl.example
    │   ├── global-variables.pkr.hcl.example
    │   ├── main.pkr.hcl
    │   ├── README.md
    ├── ol8-template/  # Nova imagem baseada no template
    │   ├── data/
    │   │   ├── kickstart.tpl
    │   ├── ansible-variables.pkr.hcl
    │   ├── network-variables.pkr.hcl
    │   ├── storage-variables.pkr.hcl
    │   ├── vsphere-variables.pkr.hcl
    │   ├── global-variables.pkr.hcl
    │   ├── main.pkr.hcl
    │   ├── README.md
    ├── apache-template/
    │   ├── ...


vsphere-provisionamento/ 
    ├── ol8-template/ │ 
        ├── README.md │ 
        ├── ol8-template.json │ 
        ├── script-library/
        ├── data/
    ├── apache-template/ │
     ├── README.md │
     ├── apache-template.json │
     ├── script-library/
     ├── data/
...
```