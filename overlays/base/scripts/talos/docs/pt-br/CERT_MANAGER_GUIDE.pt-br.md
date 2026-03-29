# cert-manager Guide (PT-BR)

## Finalidade

Documentar como o cert-manager e instalado e operado neste projeto.

## Comportamento Importante

- cert-manager nao oferece UI web nativa.
- Operacoes sao feitas com `kubectl` (e opcionalmente `cmctl`).
- O ownership de day-2 e esperado via `talos-gitops.sh`.

## Fonte De Manifest

- Metadados de release Helm:
  - `talos-vsphere-gitops/environments/lab/helm/cert-manager/release.yaml`
- Values Helm:
  - `talos-vsphere-gitops/environments/lab/helm/cert-manager/values.yaml`

## Instalar Ou Atualizar

Instalar somente cert-manager:

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-addon \
  --addon=cert-manager \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

Instalar como parte de um run de plataforma:

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["cert-manager"]'
```

## Comandos De Validacao

```bash
KUBECONFIG=/home/vagrant/.kube/config kubectl -n cert-manager get pods -o wide
KUBECONFIG=/home/vagrant/.kube/config kubectl get crd | grep cert-manager.io
KUBECONFIG=/home/vagrant/.kube/config kubectl get clusterissuers,issuers -A
```

## CLI Opcional (cmctl)

Se `cmctl` estiver instalado:

```bash
cmctl check api
```

## Notas

- CRDs do cert-manager devem existir antes da reconciliacao de recursos
  Certificate.
- Mantenha manifests de issuer e certificate na fonte GitOps e deixe o Argo CD
  sincronizar apos o cert-manager estar saudavel.
