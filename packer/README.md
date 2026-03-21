# Packer Guide

Este diretório concentra os fluxos de build de imagens para laboratório.

## Objetivo

- `vmware-iso`: build local (Workstation/Fusion).
- `vsphere-iso`: build direto no ESXi/vSphere.

## Pré-requisitos

1. `packer` ou `packerio` no PATH.
2. `govc` no PATH para validações de inventário.
3. Acesso de rede ao ESXi/vSphere.
4. Para `common_data_source=disk`, ter `xorriso` instalado no host de build.

Instalar `govc` pelo script do repositório:

```bash
cd /home/vagrant/infra-gitops
./scripts/govc/install.sh
```

## Passo Importante: Preparar Ambiente (source)

Este é o passo obrigatório antes de executar os builds.

1. (Opcional) crie um arquivo local com overrides e segredos:

```bash
cp packer/env.local.example packer/env.local.sh
```

2. Carregue variáveis do overlay atual na sessão:

```bash
OVERLAY_ENV=lab source ./packer/env.sh
```

Isso exporta:
- `GOVC_*` (para `govc`)
- `PKR_VAR_*` (para Packer)

3. Garanta uma chave pública para acesso SSH na imagem:

```bash
export BUILD_KEY="$(cat ~/.ssh/id_ed25519.pub)"
```

Se `BUILD_KEY` não for definido, `packer/vsphere-iso/build.sh` tenta carregar automaticamente `~/.ssh/id_ed25519.pub` e depois `~/.ssh/id_rsa.pub`.

## Validar Conectividade

```bash
govc about
govc ls /
govc datastore.info DATASTORE_02
```

## Fluxo vsphere-iso (recomendado para lab)

Perfis suportados pelo orchestrator:
- `oraclelinux-9`
- `ubuntu-24`

### Oracle Linux 9

```bash
./packer/vsphere-iso/build.sh \
  --profile=oraclelinux-9 \
  --env=lab \
  --vsphere-username=root \
  --vsphere-password='Senha@123' \
  --build-username=vagrant \
  --build-password=vagrant \
  --action=build
```

### Ubuntu 24.04 LTS

```bash
./packer/vsphere-iso/build.sh \
  --profile=ubuntu-24 \
  --env=lab \
  --vsphere-username=root \
  --vsphere-password='Senha@123' \
  --build-username=vagrant \
  --build-password=vagrant \
  --action=build
```

## Importante: ESXi standalone x Template

Em ESXi standalone (sem vCenter), `convert_to_template` pode falhar com:

`The operation is not supported on the object`

Nesse cenário, use a saída do perfil Ubuntu do lab com OVF export habilitado e importe com `govc import.ovf`.
Se você estiver em vCenter, ainda pode usar uma **VM golden** desligada como origem de clone (`govc vm.clone -vm <origem>`), em vez de template nativo.

## Fluxo vmware-iso (build local)

Validar todos os perfis:

```bash
./packer/vmware-iso/build.sh --os=all --action=validate
```

Build Oracle Linux:

```bash
./packer/vmware-iso/build.sh --os=oraclelinux --action=build
```

## Observações de Segurança

- Não comite segredos em `*.pkrvars.hcl`, `.env` ou scripts.
- Use `packer/env.local.sh` apenas localmente (está no `.gitignore`).
- Prefira senha via variável de ambiente/sessão e rotacione após testes.
