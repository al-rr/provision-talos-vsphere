# Handoff Entre Repositorios

Este documento e o contexto duravel de execucao para um host limpo e para agentes de automacao. Os tres repositorios devem ser clonados como diretorios irmaos em um mesmo workspace; nao dependa de um caminho absoluto fixo.

## Papel dos Repositorios

- `talos-toolchain`: camada reutilizavel de comandos Talos de day-1 e day-2.
- `talos-vsphere-gitops`: fonte GitOps dos manifests da plataforma.
- `provision-talos-vsphere`: integracao de topologia vSphere/ESXi, overlays de ambiente e cenarios de validacao.
- `infra-gitops`: responsavel pela automacao de Packer/imagens. Registre bugs e melhorias desse escopo como issues naquele repositorio; nao restaure o codigo Packer aqui.

## Preparacao em Host Limpo

Escolha um workspace e clone os repositorios como diretorios irmaos:

```bash
export WORKSPACE_ROOT="$HOME/platform-workspace"
mkdir -p "$WORKSPACE_ROOT"
cd "$WORKSPACE_ROOT"
git clone git@github.com:al-rr/talos-toolchain.git
git clone git@github.com:ednillibanio/talos-vsphere-gitops.git
git clone git@github.com:al-rr/provision-talos-vsphere.git
export TALOS_TOOLCHAIN_DIR="$WORKSPACE_ROOT/talos-toolchain"
```

Instale as ferramentas do fluxo escolhido (`bash`, `git`, `talosctl`, `kubectl`, `govc`, Terraform e dependencias do controlador de laboratorio). Use Git Bash no host operador Windows conforme a politica do laboratorio.

Antes de iniciar o wrapper day-1, confirme que o checkout irmao e o toolchain
esperado e que o wrapper consegue acessa-lo. Execute estas verificacoes somente
de leitura a partir do checkout `provision-talos-vsphere`:

```bash
test -x "$TALOS_TOOLCHAIN_DIR/scripts/talos/cluster.sh"
./overlays/base/scripts/talos/cluster-toolchain.sh --help
```

`cluster-toolchain.sh` e um wrapper de encaminhamento: ele nao torna este
repositorio responsavel pelo codigo generico do ciclo de vida Talos. Use
`--project-dir` para selecionar o projeto de cluster pretendido; nao passe
credenciais na linha de comando. A configuracao do projeto e do ambiente XDG
determina a intencao nao secreta e as credenciais locais consumidas pelo
toolchain subjacente.

## Configuracao e Ordem de Execucao

1. No checkout do laboratorio, copie `vars.local.example.sh` para `vars.local.sh` no projeto escolhido (`talos-dev` ou `talos-smoke`) e informe credenciais, topologia e endpoints locais. Nunca versione esse arquivo.
2. Revise `vars.sh`, patches e schematics rastreados; os caminhos relativos ao projeto/workspace sao derivados da localizacao do checkout.
3. Execute o ciclo day-1 com `cluster-toolchain.sh`, o entrypoint canonico que encaminha para o `cluster.sh` do `talos-toolchain`: `generate`, `provision`, `prepare-bootstrap`, `apply-config`, `bootstrap` e `sync-access`. O `cluster.sh` local deste repositorio e um shim de encaminhamento descontinuado, mantido apenas para chamadores ainda nao migrados. O comportamento generico do ciclo de vida Talos e responsabilidade do `talos-toolchain`.
4. Aplique o baseline pos-bootstrap somente depois de validar o acesso ao cluster. Ele le os manifests de plataforma do checkout GitOps irmao.
5. Use Argo CD e o repositorio GitOps para mudancas day-2 de aplicacoes.

## Limite do Repositorio

Este repositorio e o adaptador de infraestrutura VMware/vSphere: provisionamento
via `govc`/Terraform, HAProxy e topologia de ambiente. O ciclo de vida Talos
generico e independente de ambiente e responsabilidade do `talos-toolchain`,
que ja disponibiliza um backend local Docker/Colima para Talos
(`scripts/talos/local-cluster.sh`); esse backend e um caminho local separado
e nao substitui o adaptador VMware/vSphere deste repositorio. O provisionamento
real em vSphere/ESXi e a validacao de VIP neste repositorio ficam adiados para
o marco Windows/VMware — nao trate os caminhos Terraform de HAProxy ou Talos
como ativos ate que esse marco os conecte.

## Validacao e Lacunas Conhecidas

- Antes de alterar infraestrutura, execute a validacao de shell (`make lint-sh`) e use o modo dry-run quando houver suporte.
- Configuracao gerada, kubeconfig, talosconfig e secrets ficam locais em `generated/` e nunca devem ser adicionados ao indice Git.
- Configuracoes geradas de maquina Talos e arquivos de acesso gravados
  diretamente no diretorio de um projeto de cluster tambem sao locais. Consulte
  [Contencao de credenciais](credential-containment.md) antes de regenerar ou
  rotacionar o material de acesso.
- O ciclo de vida de VMs do HAProxy e `govc + Ansible` (ativo); Terraform/Packer
  para HAProxy sao caminhos de rascunho/futuros ate que a automacao de VIP
  seja concluida.
- O ciclo de vida de VMs do Talos e `govc` (ativo, via `cluster.sh provision`);
  Terraform e o provisionador alvo e ainda nao esta conectado ao fluxo day-1.
- A role Ansible do Keepalived existe (`overlays/base/ansible/roles/keepalived/`)
  mas ainda nao esta incluida no playbook do HAProxy — o failover de VIP nao
  esta conectado.
- O alvo de HAProxy e formado por dois nos com VIP. Confirme o estado atual da automacao de HA/VIP em `agenda.md` antes de um rollout produtivo.
- O laboratorio local e ambiente de integracao e validacao, nao a fonte de verdade de producao. Mantenha valores por ambiente no overlay e no override local adequados.

## Checklist de Continuidade

- Leia este documento, `agenda.md` e `docs/devops/platform-automation-architecture.md` antes de agir.
- Verifique os tres repositorios com `git status --short --branch` antes do trabalho.
- Crie branches de tarefa focadas a partir de `lab` e direcione toda PR comum
  para `lab`; a promocao para `main` e uma operacao separada, autorizada pelo
  proprietario. Faca merge somente depois dos checks locais e remotos
  aplicaveis.
- Registre trabalho novo de image build como issue em `infra-gitops`.
