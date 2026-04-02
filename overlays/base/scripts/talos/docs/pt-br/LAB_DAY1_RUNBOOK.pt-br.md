# Runbook Canonico Day-1 (Lab)

## Finalidade

Este e o runbook canonico de execucao para criar um novo cluster no lab deste
repositorio.

Ele responde:

- quais componentes de infraestrutura devem existir antes
- quais scripts executar e em qual ordem
- onde DNS e load balancer entram no bootstrap do Talos

## Escopo

Este runbook vale para o fluxo de lab do `talos-vsphere-lab` em VMware/ESXi.

- o modulo DNS aqui e orientado ao lab
- HAProxy/Keepalived aqui sao camada de integracao (wrapper)
- o ciclo de vida Talos day-1 roda via `cluster-toolchain.sh`

## Pre-requisitos

1. O controller possui os CLIs necessarios: `govc`, `talosctl`, `kubectl`, `helm`.
2. As variaveis de vSphere estao definidas no projeto (`vars.sh` + `vars.local.sh`).
3. Voce ja definiu:

- nome do cluster
- IPs de control-plane
- IPs de worker
- endpoint da API
- VIP do LB (quando usar LB)

## Infra Necessaria Antes Do Talos

### 1. DNS (lab)

Use o modulo DNS quando o lab nao tiver DNS confiavel ja pronto.

```bash
./overlays/base/scripts/dns/run-full.sh --env=lab
```

Se o DNS do seu lab ja estiver operacional, pule esta etapa.

### 2. Load Balancer + VIP (HAProxy + Keepalived)

Use a action de orquestracao completa do wrapper de LB:

```bash
./overlays/base/scripts/ha-proxy/haproxy-lb.sh configure-vip --env=lab --overwrite
```

Esse comando executa o fluxo completo de LB (provision/configure/hardening/keepalived)
via `run-full.sh` na camada de integracao do lab.

Voce pode validar o estado do modulo de LB:

```bash
./overlays/base/scripts/ha-proxy/haproxy-lb.sh validate --env=lab
./overlays/base/scripts/ha-proxy/haproxy-lb.sh status --env=lab
```

## Talos Day-1 (Ciclo De Vida Do Projeto)

Use um diretorio de projeto, por exemplo `overlays/lab/talos/talos-dev`.

### 1. Criar projeto

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh create-project --project-dir=overlays/lab/talos/talos-dev
```

### 2. Preencher overrides locais

Editar:

- `overlays/lab/talos/talos-dev/vars.local.sh`

Definir valores especificos do ambiente (credenciais, IPs, endpoint, VIP).

### 3. Gerar configuracoes

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh generate --project-dir=overlays/lab/talos/talos-dev
```

### 4. Provisionar VMs

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh provision --project-dir=overlays/lab/talos/talos-dev
```

### 5. Preparar bootstrap

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh prepare-bootstrap --project-dir=overlays/lab/talos/talos-dev
```

Notas:

- Em cenarios ISO, esta fase trata descoberta de IP DHCP.
- A reconciliacao de backend do HAProxy para endpoints de control-plane roda aqui.

### 6. Bootstrap do cluster

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh bootstrap --project-dir=overlays/lab/talos/talos-dev
```

### 7. Apply-config (convergencia pos-bootstrap quando necessario)

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh apply-config --project-dir=overlays/lab/talos/talos-dev
```

### 8. Sincronizar acesso local

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh sync-access --project-dir=overlays/lab/talos/talos-dev
```

### 9. Aplicar baseline pos-bootstrap (day-1.5)

```bash
./overlays/base/scripts/talos/cluster-toolchain.sh apply-post-bootstrap --project-dir=overlays/lab/talos/talos-dev
```

## Checkpoints De Validacao

Apos `bootstrap` e `sync-access`:

```bash
kubectl get nodes -o wide
```

Apos `apply-post-bootstrap`:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -w
kubectl get nodes -w
```

## Handoff Para Day-2

Quando o day-1 estiver estavel, siga com:

- `talos-gitops-toolchain.sh` para helms/apps de plataforma e handoff para Argo CD.

Relacionado:

- [ARGOCD_GITOPS_GUIDE.pt-br.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/pt-br/ARGOCD_GITOPS_GUIDE.pt-br.md)
