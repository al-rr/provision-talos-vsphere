# Prometheus Stack Guide (PT-BR)

## Finalidade

Documentar como kube-prometheus-stack e instalado, validado e acessado neste
projeto.

## Fonte De Manifest

- Metadados de release Helm:
  - `talos-vsphere-gitops/environments/lab/helm/prometheus-stack/release.yaml`
- Values Helm:
  - `talos-vsphere-gitops/environments/lab/helm/prometheus-stack/values.yaml`

## Instalar Ou Atualizar

Instalar somente prometheus-stack:

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-addon \
  --addon=prometheus-stack \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab
```

Instalar como parte de um run de plataforma:

```bash
./overlays/base/scripts/talos/talos-gitops.sh install-platform-helm \
  --kube-context=admin@talos-dev \
  --manifest-root-dir=/home/vagrant/talos-vsphere-gitops/environments/lab \
  --addons='["prometheus-stack"]'
```

## Comandos De Validacao

```bash
KUBECONFIG=/home/vagrant/.kube/config kubectl -n kube-prometheus-stack get pods -o wide
KUBECONFIG=/home/vagrant/.kube/config kubectl -n kube-prometheus-stack get servicemonitors,prometheusrules
KUBECONFIG=/home/vagrant/.kube/config kubectl -n kube-prometheus-stack get alertmanagers,prometheuses
```

## Acesso a UI (Port-Forward)

Prometheus (`http://localhost:9090`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Grafana (`http://localhost:3000`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Alertmanager (`http://localhost:9093`):

```bash
KUBECONFIG=/home/vagrant/.kube/config \
kubectl -n kube-prometheus-stack port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
```

Por padrao, `kubectl port-forward` faz bind em `localhost`. Use
`--address 0.0.0.0` apenas quando quiser exposicao externa de forma
intencional.

## Notas

- A primeira instalacao pode mostrar warnings transitorios se os CRDs ainda nao
  estiverem totalmente estabelecidos; reexecute apos disponibilidade dos CRDs se
  necessario.
- Mantenha customizacoes de dashboard, alerta e scrape no values GitOps.
