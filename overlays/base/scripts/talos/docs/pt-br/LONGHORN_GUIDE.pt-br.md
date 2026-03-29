# Longhorn Guide (PT-BR)

## Finalidade

Documentar como o Longhorn e preparado e instalado neste cluster Talos de lab,
e como atualizar values com seguranca apos a implantacao inicial.

## Pre-requisitos

- O cluster Talos esta em execucao e acessivel com `kubectl`.
- Os nos worker incluem extensoes de sistema do Longhorn via:
  - `overlays/lab/talos/talos/schematic.yaml`
- A machine config de worker inclui patch de Longhorn:
  - `overlays/lab/talos/talos/patches/longhorn.patch.yaml`
- As VMs worker possuem disco de dados extra configurado (fluxo atual usa
  `sdb`):
  - `overlays/base/scripts/talos/govc/provision-cluster.sh`

## Arquivos Usados Pelo Addon

- Metadados de release Helm:
  - `overlays/lab/talos/talos/helm/longhorn/release.yaml`
- Overrides Helm:
  - `overlays/lab/talos/talos/helm/longhorn/values.yaml`
- Orquestracao baseline day-1:
  - `overlays/base/scripts/talos/cluster.sh apply-post-bootstrap`
- Orquestracao GitOps day-2:
  - `overlays/base/scripts/talos/talos-gitops.sh install-platform-helm`

## Instalar Ou Atualizar Longhorn

Modo baseline day-1 (a partir do projeto de cluster):

```bash
./overlays/base/scripts/talos/cluster.sh apply-post-bootstrap \
  --project-dir=overlays/lab/talos/talos \
  --addons='["longhorn"]'
```

Modo GitOps day-2 (a partir da fonte de manifests):

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["longhorn"]'
```

## Como Funciona Atualizacao De Values

- Edite apenas o que precisa diferir dos defaults do chart em:
  - `overlays/lab/talos/talos/helm/longhorn/values.yaml`
- Reexecute um dos comandos:
  - `cluster.sh apply-post-bootstrap --addons='["longhorn"]'`
  - `talos-gitops.sh install-platform-helm --kube-context=<context> --addons='["longhorn"]'`
- O Helm faz upgrade in-place da release.

## Comandos De Validacao

```bash
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n longhorn-system get pods -o wide
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl -n longhorn-system get all
KUBECONFIG=overlays/lab/talos/talos/generated/kubeconfig kubectl get sc
```

## Acesso a UI (Port-Forward)

Use `kubectl port-forward` para acesso de operador a UI do Longhorn:

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8081:80
```

Abrir: `http://localhost:8081`

Por padrao, `kubectl port-forward` faz bind em `localhost`. Use
`--address 0.0.0.0` apenas quando quiser exposicao externa de forma
intencional.

## Notas

- Os managers do Longhorn devem rodar em nos worker nesta topologia.
- Labels de Pod Security no namespace sao aplicados automaticamente pela
  orquestracao de addon usando campos de:
  `overlays/lab/talos/talos/helm/longhorn/release.yaml`.
