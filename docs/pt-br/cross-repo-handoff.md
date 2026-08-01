# Handoff Entre Repositorios

Este documento e o contexto duravel de execucao para um host limpo e para agentes de automacao. Os tres repositorios devem ser clonados como diretorios irmaos em um mesmo workspace; nao dependa de um caminho absoluto fixo.

## Papel dos Repositorios

- `talos-toolchain`: camada reutilizavel de comandos Talos de day-1 e day-2.
- `talos-vsphere-gitops`: fonte GitOps dos manifests da plataforma.
- `talos-vsphere-lab`: integracao de topologia vSphere/ESXi, overlays de ambiente e cenarios de validacao.
- `infra-gitops`: responsavel pela automacao de Packer/imagens. Registre bugs e melhorias desse escopo como issues naquele repositorio; nao restaure o codigo Packer aqui.

## Preparacao em Host Limpo

Escolha um workspace e clone os repositorios como diretorios irmaos:

```bash
export WORKSPACE_ROOT="$HOME/platform-workspace"
mkdir -p "$WORKSPACE_ROOT"
cd "$WORKSPACE_ROOT"
git clone git@github.com:al-rr/talos-toolchain.git
git clone git@github.com:ednillibanio/talos-vsphere-gitops.git
git clone git@github.com:al-rr/provision-talos-vsphere.git talos-vsphere-lab
export TALOS_TOOLCHAIN_DIR="$WORKSPACE_ROOT/talos-toolchain"
```

Instale as ferramentas do fluxo escolhido (`bash`, `git`, `talosctl`, `kubectl`, `govc`, Terraform e dependencias do controlador de laboratorio). Use Git Bash no host operador Windows conforme a politica do laboratorio.

## Configuracao e Ordem de Execucao

1. No checkout do laboratorio, copie `vars.local.example.sh` para `vars.local.sh` no projeto escolhido (`talos-dev` ou `talos-smoke`) e informe credenciais, topologia e endpoints locais. Nunca versione esse arquivo.
2. Revise `vars.sh`, patches e schematics rastreados; os caminhos relativos ao projeto/workspace sao derivados da localizacao do checkout.
3. Execute o ciclo day-1 com `cluster.sh` ou com o wrapper de transicao `cluster-toolchain.sh`: `generate`, `provision`, `prepare-bootstrap`, `apply-config`, `bootstrap` e `sync-access`.
4. Aplique o baseline pos-bootstrap somente depois de validar o acesso ao cluster. Ele le os manifests de plataforma do checkout GitOps irmao.
5. Use Argo CD e o repositorio GitOps para mudancas day-2 de aplicacoes.

## Validacao e Lacunas Conhecidas

- Antes de alterar infraestrutura, execute a validacao de shell (`make lint-sh`) e use o modo dry-run quando houver suporte.
- Configuracao gerada, kubeconfig, talosconfig e secrets ficam locais em `generated/` e nunca devem ser adicionados ao indice Git.
- O alvo de HAProxy e formado por dois nos com VIP. Confirme o estado atual da automacao de HA/VIP em `agenda.md` antes de um rollout produtivo.
- O laboratorio local e ambiente de integracao e validacao, nao a fonte de verdade de producao. Mantenha valores por ambiente no overlay e no override local adequados.

## Checklist de Continuidade

- Leia este documento, `agenda.md` e `docs/devops/platform-automation-architecture.md` antes de agir.
- Verifique os tres repositorios com `git status --short --branch` antes do trabalho.
- Crie PRs focadas para `main` em cada repositorio; faca merge somente depois dos checks locais e remotos aplicaveis.
- Registre trabalho novo de image build como issue em `infra-gitops`.
