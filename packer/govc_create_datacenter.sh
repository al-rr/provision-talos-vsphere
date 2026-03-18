#!/bin/bash

govc datacenter.create "$vsphere_datacenter"
govc cluster.create "$vsphere_cluster"
govc cluster.add -hostname "$vsphere_host" -username "$GOVC_USERNAME" -password "$GOVC_PASSWORD" -noverify
# govc datastore.create -type local -name gostore -path /tmp gocluster/*
# govc vm.create -ds gostore -cluster gocluster govm1