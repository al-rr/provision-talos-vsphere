# ArgoCD GitOps Guide (PT-BR)

## Finalidade

Explicar como fazer o handoff do ciclo de vida dos addons para o Argo CD apos o
cluster estar pronto.

## Escopo

Este guia gerencia os seguintes addons por recursos `Application` do Argo CD:

- Cilium
- cert-manager
- Longhorn
- kube-prometheus-stack

## Caminhos de Repositorio

- Repositorio de bootstrap (este repositorio) mantem apenas o manifesto de
  handoff:
  - `overlays/lab/talos/talos/gitops/argocd/root-app.yaml`
- Fonte de verdade GitOps (repositorio separado):
  - `talos-vsphere-gitops/environments/lab/argocd/root-app.yaml`
  - `talos-vsphere-gitops/environments/lab/argocd/apps/`
  - `talos-vsphere-gitops/environments/lab/helm/<addon>/values.yaml`

## Bootstrap Unico

Instale primeiro o Argo CD a partir da fonte de manifests GitOps:

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["argocd"]'
```

## Politica de Instalacao no Day-2

`install-platform-helm` suporta selecao inclusiva e exclusiva:

- `--addons='[...]'`: instala apenas os addons listados.
- `--exclude-addons='[...]'`: ignora addons listados no conjunto resolvido
  (merge com exclusoes de sistema; nao sobrescreve).

Comportamento padrao:

- `cilium` e excluido por padrao em runs day-2.
- Motivo: Cilium e dependencia baseline do day-1 neste projeto; reaplicar CNI
  dentro de sync amplo do day-2 pode gerar churn de rede evitavel.
- Exclusoes de sistema sao sempre aplicadas e combinadas com exclusoes do
  usuario.
- Na pratica: `install-platform-helm` e para addons de plataforma/day-2,
  enquanto ciclo de vida do Cilium fica no fluxo day-1.
- `--kube-context` e obrigatorio para reduzir risco de aplicar no cluster
  errado quando houver varios contexts no kubeconfig.

Exemplos:

```bash
# Cenario 1: instalar conjunto amplo de plataforma (exclusoes de sistema continuam aplicadas)
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab

# Cenario 2: instalar apenas o que voce escolher
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["longhorn"]'

# Cenario 2b: seletivo e com exclusao adicional nesta execucao
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["argocd","longhorn","cert-manager"]' \
  --exclude-addons='["longhorn"]'
```

## Modelo de Seguranca para Credenciais do Repositorio

- `repo-secret.example.yaml` e apenas um template.
- A chave SSH privada real deve ser adicionada apenas pelo operador do cluster.
- Nao commite credenciais reais de repositorio no Git.
- Mantenha criacao de secret como passo manual de operador.

Crie credenciais de repositorio apenas se o repositorio GitOps for privado.
Se for publico, pule esta secao.

```bash
cp /home/vagrant/talos-vsphere-gitops/environments/lab/argocd/repo-secret.example.yaml /tmp/repo-secret.yaml
# Edite /tmp/repo-secret.yaml e substitua sshPrivateKey por uma deploy key valida.
KUBECONFIG=/home/vagrant/.kube/config \
kubectl apply -f /tmp/repo-secret.yaml
```

Deploy do manifesto app-of-apps usando o entrypoint day-2:

```bash
./overlays/base/scripts/talos/talos-gitops.sh deploy-argocd-root-app \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

Comando manual equivalente (mesmo efeito da action acima):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl apply -f /home/vagrant/talos-vsphere-gitops/environments/lab/argocd/root-app.yaml
```

Nota de comportamento:

- `deploy-argocd-root-app` aplica `root-app.yaml` e encerra.
- `Application` filhos sao criados depois pela reconciliacao do Argo CD.
- Se o Argo CD nao conseguir comparar/sincronizar (por exemplo problemas de
  cache/conectividade API), pode existir apenas `addons-root` e os filhos nao
  serem criados ainda.

## Como os Applications Leem os Values

Applications usam modo multi-source do Argo CD:

- Source A: repositorio Helm chart (ou chart OCI).
- Source B: este repositorio Git (`ref: values`).
- `helm.valueFiles` aponta para `$values/.../values.yaml` neste repositorio.

Isso permite manter values em:

- `environments/lab/helm/<addon>/values.yaml` (em `talos-vsphere-gitops`)

## Atualizando Configuracao de Addon

1. Edite `environments/lab/helm/<addon>/values.yaml` em
   `talos-vsphere-gitops`.
2. Commit e push na branch rastreada (`main` por padrao).
3. Argo CD sincroniza automaticamente (quando automated sync estiver habilitado).

## Validacao

```bash
KUBECONFIG=/home/vagrant/.kube/config kubectl -n argocd get applications
KUBECONFIG=/home/vagrant/.kube/config kubectl -n argocd get pods
KUBECONFIG=/home/vagrant/.kube/config kubectl -n argocd describe application addons-root
```

Esperado:

- `addons-root` existe.
- Apps filhos (por exemplo `cilium`, `longhorn`, `cert-manager`,
  `prometheus-stack`) aparecem em `kubectl -n argocd get applications` apos
  reconciliacao.

Se os apps filhos nao aparecerem:

```bash
KUBECONFIG=/home/vagrant/.kube/config kubectl -n argocd logs statefulset/argocd-application-controller --tail=200
```

## Acesso a UI (Modelo Port-Forward)

Este projeto usa `kubectl port-forward` como modelo padrao de acesso de
operadores para UIs internas.

Por que:

- Servicos ficam internos (tipicamente `ClusterIP`).
- O acesso e concedido apenas para operadores com kubeconfig/context valido.
- Nao e necessario manter exposicao externa persistente no dia a dia do lab.

Execute o comando na sessao controller/guest que tem acesso ao cluster e abra a
URL `localhost` correspondente no host.

Argo CD UI (`https://localhost:8080`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Longhorn UI (`http://localhost:8081`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8081:80
```

Prometheus UI (`http://localhost:9090`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Grafana UI (`http://localhost:3000`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Alertmanager UI (`http://localhost:9093`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```

Notas:

- Mantenha cada processo de `port-forward` em execucao enquanto a UI estiver em uso.
- Se a porta local estiver ocupada, altere apenas o lado esquerdo (por exemplo
  `18080:443`).
- Por padrao, `kubectl port-forward` faz bind em `localhost`. Use
  `--address 0.0.0.0` apenas quando quiser exposicao externa de forma
  intencional.

## Notas

- Os manifests atualmente apontam para a branch `main`.
- Se URL do repositorio ou branch for diferente, atualize:
  - `repoURL`
  - `targetRevision`
