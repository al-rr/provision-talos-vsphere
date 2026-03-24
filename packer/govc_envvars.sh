#!/bin/bash

TEMP_ENV=".env.tmp.govc"

if [ ! -f ".env" ]; then
    echo "[ERRO] Arquivo .env não encontrado no diretório atual."
    exit 1
fi

# Cria um .env temporário:
# 1. Substitui // por #
# 2. Remove espaços ao redor do '='
sed 's|//|#|; s/^[[:space:]]*\([^[:space:]=]\+\)[[:space:]]*=[[:space:]]*/\1=/' .env > "$TEMP_ENV"

# Carrega variáveis do .env temporário
set -a
source "$TEMP_ENV"
set +a


export GOVC_HOST="$vsphere_endpoint"
export GOVC_HOST_PORT=443
export GOVC_USERNAME="$vsphere_username"
export GOVC_PASSWORD="$vsphere_password"
export GOVC_INSECURE="$vsphere_insecure_connection"
export GOVC_URL="https://$GOVC_USERNAME:$GOVC_PASSWORD@$GOVC_HOST:$GOVC_HOST_PORT"
export GOVC_DATACENTER="$vsphere_datacenter"
export GOVC_DATASTORE="$vsphere_datastore"
export GOVC_NETWORK="$vsphere_network"
export GOVC_RESOURCE_POOL="$vsphere_resource_pool"
export GOVC_HOST="$vsphere_host"

# govc datacenter.create "$vsphere_datacenter"
# govc cluster.create "$vsphere_cluster"
# govc cluster.add -hostname "$vsphere_host" -username "$GOVC_USERNAME" -password "$GOVC_PASSWORD" -noverify
# govc datastore.create -type local -name gostore -path /tmp gocluster/*
# govc vm.create -ds gostore -cluster gocluster govm1

rm -rf $TEMP_ENV
