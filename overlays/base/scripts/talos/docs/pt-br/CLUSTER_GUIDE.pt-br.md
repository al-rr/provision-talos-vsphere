# Talos Cluster Guide (PT-BR)

## Finalidade

Este e o runbook operacional para criar e evoluir um cluster Talos neste
repositorio.

Este guia e propositalmente explicito sobre ordem de execucao e escopo dos
scripts.

## Escopo E Fonte De Verdade

Use este guia junto com:

- [Talos module README](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/README.md)
- [Lab cluster blueprint](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md)
- `overlays/lab/talos/talos/cluster-spec.yaml`

`cluster-spec.yaml` e a fonte de verdade da intencao do cluster (IPs,
quantidades, endpoint, estrategia de CNI). Este guia e o runbook de execucao.

## Modelo De Geracao De Patches

Durante `cluster-bootstrap.sh`, os arquivos de patch sao renderizados a partir
das variaveis do overlay.

- `bootstrap.patch.yaml` e gerado a partir de `TALOS_NAMESERVERS` e das flags
  de DNS/hostDNS/time de bootstrap.
- `talos-cp-<n>.patch.yaml` e `talos-worker-<n>.patch.yaml` sao gerados a partir de:
  - `TALOS_CONTROL_PLANE_IPS` / `TALOS_WORKER_IPS`
  - `TALOS_NODE_INTERFACE`
  - `TALOS_GATEWAY`
  - `TALOS_NETMASK_PREFIX`

Nao trate esses arquivos gerados como alvo principal de edicao manual de longo
prazo.
Mantenha os valores desejados em vars do overlay e execute o fluxo novamente.

## Ciclo De Vida Talos (Apply Antes E Depois Do Bootstrap)

Sequencia principal do Talos:

1. Gerar configs
2. Aplicar config nos nos
3. Fazer bootstrap de um no control-plane (operacao unica)

Comportamento pre-bootstrap especifico de ISO:

- No modo ISO, os nos iniciam com IP via DHCP.
- O provisionamento grava esses enderecos temporarios em:
  - `generated/bootstrap-ips.txt`
- A fase de apply prefere automaticamente esse inventario para
  `talosctl apply-config`.
- Depois do apply, os nos convergem para os IPs estaticos de
  `TALOS_CONTROL_PLANE_IPS` e `TALOS_WORKER_IPS`.

Nome da action no talosctl antes e depois do bootstrap:

- O comando e o mesmo: `talosctl apply-config`.
- O que muda e a intencao:
  - pre-bootstrap: convergencia inicial de machine configuration
  - post-bootstrap: reconvergencia apos alteracoes de patch

Importante:

- `apply-config` nao e acao de uma unica vez.
- Ele e usado antes do bootstrap e pode ser usado novamente depois do
  bootstrap sempre que houver mudancas de configuracao.
- Em outras palavras, apply e uma acao de convergencia que pode rodar varias
  vezes.

### Matriz De Fases De Patch

Patches de bootstrap (Day-1 apply antes do bootstrap):

- `bootstrap.patch.yaml`
- `cp-bootstrap.patch.yaml` (somente control-plane)
- `worker-bootstrap.patch.yaml` (somente worker)
- `talos-cp-<n>.patch.yaml`
- `talos-worker-<n>.patch.yaml`
- `cni.patch.yaml` (somente quando `TALOS_DISABLE_DEFAULT_CNI=true`)

Patches pos-bootstrap (intencao runtime/estado final):

- `cp.patch.yaml` (configuracoes runtime de control-plane)
- `worker.patch.yaml` (configuracoes runtime de worker)

Nota do comportamento atual:

- A cadeia de patches de bootstrap e aplicada pelos scripts atuais.
- Aplicacao de patches runtime deve ser executada como etapa de apply
  pos-bootstrap quando esses arquivos forem usados como override de estado
  final.

## O Que Cada Script Faz De Fato

### `cluster.sh`

Entrypoint unificado que orquestra scripts existentes do modulo com actions
explicitas:

- `create-project`
- `generate`
- `provision`
- `prepare-bootstrap`
- `apply-config`
- `bootstrap`
- `apply-post-bootstrap`
- `sync-access`

Ordem recomendada de execucao do `cluster.sh`:

0. `create-project`
1. `generate`
2. `provision`
3. `prepare-bootstrap`
4. `bootstrap`
5. `apply-config` (convergencia pos-bootstrap, quando necessario)
6. `sync-access`
7. `apply-post-bootstrap`

`cluster.sh` e project-dir first:

- Use `--project-dir=<path-do-projeto-cluster>` em operacao normal.
- `--vars-file` continua disponivel para fluxos manuais/avancados.
- `--env` foi removido do `cluster.sh`.

Contrato de mapeamento das actions day-1 nas vars do projeto:

- `TALOS_DAY1_GENERATE_CMD`
- `TALOS_DAY1_PROVISION_CMD`
- `TALOS_DAY1_PREPARE_BOOTSTRAP_CMD`
- `TALOS_DAY1_APPLY_CONFIG_CMD`
- `TALOS_DAY1_BOOTSTRAP_CMD`
- `TALOS_DAY1_SYNC_ACCESS_CMD`

O `cluster.sh` executa esses mapeamentos diretamente para as actions do ciclo
de vida Talos (`generate`, `provision`, `prepare-bootstrap`, `apply-config`,
`bootstrap`, `sync-access`). Se algum mapeamento estiver ausente, a execucao
falha de forma explicita.

`apply-post-bootstrap` permanece como action separada e nao faz parte do
conjunto mapeado do ciclo de vida Talos.

Exemplo:

```bash
./overlays/base/scripts/talos/cluster.sh create-project --project-dir=overlays/lab/talos/talos-dev
./overlays/base/scripts/talos/cluster.sh generate --project-dir=overlays/lab/talos/talos-dev
```

### `phase-cluster-ready.sh`

`phase-cluster-ready.sh` e a **orquestracao da Fase 1**. Nao e parcial.
Por padrao, executa:

1. Provisionamento de VMs (control planes + workers a partir das vars do env)
2. Fluxo de bootstrap Talos (`cluster-bootstrap.sh --mode=all`)
3. Geracao de artefato kubeconfig
4. Sync de acesso local (`kubectl` + `talosctl`)
5. Validacao

Comando padrao:

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab
```

Comando somente control-plane:

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab --worker-count=0
```

### `phase-network-bringup.sh`

Orquestracao da Fase 2 para addons via wrappers Helm (`cilium`, `argocd`,
`longhorn`, etc.).

### `cluster-bootstrap.sh`

Script Talos Day-1 de baixo nivel (`generate`, `apply`, `bootstrap`, `all`).
Use para reruns controlados e fluxos de recuperacao.

### `provision-cluster.sh`

Wrapper de provisionamento de VMs de baixo nivel sobre `govc`. Use para acoes
seletivas de VM, como criar somente workers.

## Ordem Recomendada De Execucao (Estrita)

Execute nesta ordem para runs reproduziveis:

1. Fase 1: Cluster Ready
2. Convergencia opcional de configuracao pos-bootstrap (`apply-config`)
3. Fase 1.5: baseline pos-bootstrap (`apply-post-bootstrap`)
4. Fase 2: Network Bring-up (extras opcionais)
5. Fase 3: handoff GitOps (Argo CD como fonte de verdade)

## Fase 1: Cluster Ready

### Execucao padrao

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab
```

### Execucao somente control-plane

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab --worker-count=0
```

### Comportamento importante quando `TALOS_DISABLE_DEFAULT_CNI=true`

Se o CNI padrao do Talos estiver desabilitado (`cni: none`), o esperado e:

- API Kubernetes fica acessivel
- Nos ficam `NotReady` ate instalar Cilium (ou outro CNI)

Isso nao bloqueia o avanco para a Fase 2.

## Fase 1.5: Baseline Pos-Bootstrap

Esta fase instala os componentes minimos obrigatorios apos bootstrap do Talos,
para deixar o cluster operacional para workloads.

Padrao:

- `cilium` (obrigatorio quando `TALOS_DISABLE_DEFAULT_CNI=true`)

Extensao opcional de baseline:

- `longhorn` (se storage precisar fazer parte do baseline do projeto)

Comando:

```bash
./overlays/base/scripts/talos/cluster.sh apply-post-bootstrap --project-dir=overlays/lab/talos/talos
```

Com lista explicita:

```bash
./overlays/base/scripts/talos/cluster.sh apply-post-bootstrap --project-dir=overlays/lab/talos/talos --addons='["cilium","longhorn"]'
```

Importante:

- `prepare-bootstrap`, `apply-config` e `apply-post-bootstrap` sao etapas
  diferentes:
  - `prepare-bootstrap`: apply pre-bootstrap (`--apply-stage=pre`), usado para
    preparar os nos antes do bootstrap etcd. Esta fase pode usar
    `talosctl apply-config --insecure` no primeiro contato e depois fallback
    para talosconfig se TLS ja estiver forcado.
  - reconciliacao de backend do HAProxy para endpoints de control-plane Talos
    roda somente em `prepare-bootstrap`.
  - `apply-config`: convergencia da machine config Talos apos prep
    (`talosctl apply-config` com talosconfig/TLS apenas, sem fallback insecure).
  - `apply-post-bootstrap`: addons baseline Kubernetes pos-bootstrap.
  - o primeiro snapshot de pod/no apos install Helm e imediato e pode mostrar
    `Pending`/`NotReady` por um periodo curto.

Follow-up recomendado logo apos `apply-post-bootstrap`:

```bash
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n kube-system get pods -l k8s-app=cilium -w
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl get nodes -w
```

## Fase 2: Network Bring-up (Extras Opcionais)

Para extras opcionais neste repositorio, use `talos-gitops.sh` no fluxo day-2
em vez de wrappers ad-hoc do day-1.

## Fase 3: Handoff GitOps

Depois que a rede estiver estavel:

1. Instalar/validar Argo CD
2. Aplicar root app / app-of-apps
3. Mover mudancas day-2 de addons para fluxo Git-only (PR/merge)

Dica:

- Se voce configurou symlink global, use `talos-gitops` diretamente (mesmo
  padrao do `talos-cluster`).
- Em instalacoes day-2 de plataforma, exclusoes de sistema (por exemplo
  `cilium`) sao sempre aplicadas.
  Use `--addons` e `--exclude-addons` para definir o escopo de execucao para
  addons nao-sistema.

## OVA vs ISO: Como Escolher

O provisionamento suporta os dois modos.

Regra de selecao usada por `talos/govc/provision-cluster.sh`:

- Se `TALOS_OVA_PATH` (ou `--ova-path`) estiver definido: **usa modo OVA**
- Caso contrario: **usa modo ISO** (`TALOS_ISO_DATASTORE_PATH` / `--iso-path`)

Recomendacao pratica:

- Use OVA para o fluxo atual de lab (mais rapido/consistente com este repo)
- Use ISO quando voce precisar explicitamente do ciclo de vida ISO

## Imagens De Control-Plane E Worker

Este projeto suporta de forma intencional imagens Talos installer diferentes
por papel:

- `TALOS_CONTROL_PLANE_INSTALLER_IMAGE`
- `TALOS_WORKER_INSTALLER_IMAGE`

Por que:

- Nos control-plane priorizam estabilidade de control-plane/etcd.
- Workers podem precisar de evolucao especifica de storage/workload (por
  exemplo Longhorn agora e vSphere CSI depois).
- Manter selecao de imagem por papel evita acoplar necessidades de storage dos
  workers aos nos control-plane.

Compatibilidade:

- Se valores especificos por papel nao estiverem definidos, a automacao usa
  fallback para `TALOS_INSTALLER_IMAGE`.

## Como Criar Somente Workers

`phase-cluster-ready.sh` e para orquestracao completa da Fase 1. Para somente
workers, use provisionamento de baixo nivel.

### Criar VMs somente worker (cluster existente)

```bash
./overlays/base/scripts/talos/provision-cluster.sh \
  --env=lab \
  --cp-count=0 \
  --worker-count=<n> \
  create
```

Notas:

- Isso e destinado a cluster ja bootstrapado.
- Machine config dos workers ja deve corresponder ao cluster/secrets alvo
  (normalmente de `overlays/<env>/talos/<cluster>/generated/worker.yaml`).
- Nao execute bootstrap do cluster novamente para scale-out de worker.

## Recuperacao / Reruns Controlados

### Recreate limpo (destroy + reset generated + recreate)

```bash
./overlays/base/scripts/talos/phase-cluster-ready.sh --env=lab --clean-recreate
```

### Split generate/apply/bootstrap (avancado)

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=generate
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=apply
./overlays/base/scripts/talos/cluster-bootstrap.sh --env=lab --mode=bootstrap
```

## Checklist De Validacao

Apos Fase 1:

- `kubectl get nodes -o wide`
- `talosctl get members`
- `talosctl get machineconfig -o yaml` (verificar rede/CNI conforme esperado)

Apos Fase 2 (Cilium):

- `kubectl -n kube-system get pods -l k8s-app=cilium`
- `kubectl get nodes`

## Documentos Relacionados

- [GETTING_STARTED.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/GETTING_STARTED.md)
- [LONGHORN_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/LONGHORN_GUIDE.md)
- [ARGOCD_GITOPS_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/ARGOCD_GITOPS_GUIDE.md)
- [HOWTO_ADD_WORKERS.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/HOWTO_ADD_WORKERS.md)
- [HOWTO_RECREATE_CLUSTER.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/HOWTO_RECREATE_CLUSTER.md)
- [INFRASTRUCTURE_PLAN_EXAMPLE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md)
