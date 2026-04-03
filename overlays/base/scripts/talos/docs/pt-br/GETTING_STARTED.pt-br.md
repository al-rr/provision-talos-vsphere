# Talos Module Getting Started (PT-BR)

## Finalidade

Este guia e o ponto de partida para quem esta comecando com a automacao Talos
neste repositorio.

Ele explica:

- pelo que o modulo Talos e responsavel
- quais ferramentas externas sao necessarias
- qual infraestrutura deve existir antes da criacao do cluster
- qual guia seguir na sequencia

## O Que Este Modulo Faz

O modulo Talos cobre quatro areas principais:

- instalacao do `talosctl`
- provisionamento de VMs Talos via wrappers de `govc`
- geracao e aplicacao de machine configuration do Talos
- integracao dos control planes do Talos com o load balancer

O modulo nao tenta ser fonte de verdade de um desenho especifico de cluster.
A intencao do cluster fica no workspace do cluster, por exemplo:

- [overlays/lab/talos/talos/README.md](/home/vagrant/talos-vsphere-lab/overlays/lab/talos/talos/README.md)
- `overlays/lab/talos/talos/cluster-spec.yaml`

## Pre-requisitos Minimos

| Ferramenta | Motivo | Onde Ler Mais |
| --- | --- | --- |
| `talosctl` | Gerar configs, aplicar configs, bootstrap, inspecionar nos | [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md) |
| `govc` | Provisionar VMs em ESXi ou vSphere | [GOVC module](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/govc/README.md) |
| `kubectl` | Validar o cluster apos bootstrap | [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md) |
| `helm` | Instalar componentes pos-bootstrap como Cilium | [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md) |

**Nota importante de compatibilidade:**

- `talosctl` deve ficar na mesma major e minor dos nos Talos.
- Na pratica, usar a mesma versao exata e a opcao mais segura.

## Infraestrutura Que Deve Ser Planejada Primeiro

Antes de executar scripts de cluster, defina o ambiente por escrito.

No minimo, decida:

- nome do cluster
- IPs dos control planes
- IPs dos workers
- endpoint de API do cluster
- se o endpoint ficara atras de VIP de load balancer
- se sera necessaria VM dedicada de DNS
- origem de OVA/template usada para as VMs (ja existente ou gerada separadamente)

Nota de provisionamento:

- O provisionamento day-1 do cluster deve executar com `govc`/Terraform sobre
  uma origem OVA/template ja disponivel.
- Se voce precisar de imagem customizada, execute primeiro o fluxo de Packer
  de forma separada.

Use primeiro este documento de planejamento:

- [INFRASTRUCTURE_PLAN_EXAMPLE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/INFRASTRUCTURE_PLAN_EXAMPLE.md)

## Ordem Recomendada

Para um novo cluster Talos, a ordem recomendada e:

1. Preparar o plano de infraestrutura.
2. Preparar ferramentas do controller (`talosctl`, `kubectl`, `helm`).
3. Provisionar DNS se o lab nao tiver DNS confiavel.
4. Provisionar ou validar load balancer se o cluster usar VIP.
5. Provisionar VMs Talos.
6. Gerar configuracao Talos.
7. Aplicar configuracao Talos.
8. Executar bootstrap do cluster.
9. Configurar kubeconfig e validar cluster.
10. Seguir para componentes pos-bootstrap como Cilium.

Para comandos exatos na ordem canonica, siga:

- [LAB_DAY1_RUNBOOK.pt-br.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/pt-br/LAB_DAY1_RUNBOOK.pt-br.md)

## Para Onde Ir Agora

Escolha o guia conforme o tipo de deploy:

- [CLUSTER_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/CLUSTER_GUIDE.md)
  - Para cluster Talos com multiplos control planes e workers.
- [SINGLE_NODE_GUIDE.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/SINGLE_NODE_GUIDE.md)
  - Para ambiente Talos sem HA.

Modulos de apoio:

- `infra-gitops/scripts/dnsmasq/README.md`
- [HAProxy](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/README.md)
- [Controller guide](/home/vagrant/talos-vsphere-lab/overlays/lab/controller/README.md)

How-tos operacionais:

- [HOWTO_ADD_WORKERS.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/HOWTO_ADD_WORKERS.md)
- [HOWTO_RECREATE_CLUSTER.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/docs/HOWTO_RECREATE_CLUSTER.md)
