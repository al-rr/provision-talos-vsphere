# Contencao de Credenciais

Configuracoes geradas de maquina Talos, `talosconfig`, kubeconfig e arquivos
relacionados de acesso de cliente sao artefatos locais de runtime. Eles nunca
devem ser commitados, copiados para documentacao ou tratados como templates
reutilizaveis.

## Procedimento de Contencao

1. Interrompa o stage ou a distribuicao dos artefatos afetados.
2. Remova os artefatos do rastreamento Git somente apos aprovacao do
   proprietario; mantenha os arquivos locais ate confirmar o acesso substituto.
3. Mantenha as regras de ignore no repositorio antes de regenerar os artefatos.
4. Regenere os artefatos de maquina e acesso pelo fluxo Talos aprovado, fora do
   state do Terraform e de caminhos rastreados.
5. Confirme que o Git nao rastreia mais os nomes dos artefatos e que o status
   local nao os oferece para stage.

## Checklist de Rotacao

Trate qualquer artefato com credencial que ja foi rastreado como exposto ate o
proprietario concluir uma rotacao aprovada. O proprietario deve decidir a janela
de manutencao e a sequencia de substituicao. Registre apenas o status de
conclusao, nunca valores de credenciais, na issue ou nas evidencias de revisao.

- Regenere secrets do cluster Talos e configuracao de maquina quando necessario.
- Substitua o material de acesso Talos e distribua-o somente pelo caminho local
  de configuracao aprovado.
- Substitua o material de acesso Kubernetes e revogue o acesso obsoleto quando
  suportado pelo fluxo do cluster.
- Valide o novo acesso antes de remover a ultima copia local de contingencia.
- Registre a conclusao da rotacao e o material de recuperacao restante sem
  incluir valores no Git, logs ou comentarios da issue.

## Estado Alvo e Responsabilidade

O estado alvo e uma configuracao Talos com escopo por usuario, gerenciada pelo
`talos-toolchain` no diretorio de configuracao do proprio usuario, em vez de
dentro de um checkout de repositorio. Ate que essa migracao ocorra, o
`provision-talos-vsphere` nao deve reintroduzir artefatos gerados com
credenciais no checkout; a contencao aqui e uma medida provisoria, nao o
destino final. A migracao efetiva para configuracao com escopo por usuario e
uma implementacao posterior do `talos-toolchain`, revisada separadamente, e
esta fora do escopo deste repositorio.
