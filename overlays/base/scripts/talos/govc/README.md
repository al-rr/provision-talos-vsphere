# Talos VMware Provisioning

## Purpose

This directory contains Talos-specific provisioning entrypoints that depend on
`govc` and target VMware platforms such as ESXi and vSphere.

Keep Talos provisioning logic here when the lifecycle belongs to the Talos
module, even if the implementation uses `govc`.

## Files

- `provision-cluster.sh`: VMware provisioning entrypoint for Talos clusters
- `provision-single-node.sh`: VMware provisioning entrypoint for non-HA Talos

## Notes

- Install and configure `govc` using the GOVC module:
  - [overlays/base/scripts/govc/README.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/govc/README.md)
- Use the higher-level entrypoints in the Talos module for normal operations:
  - [overlays/base/scripts/talos/README.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/talos/README.md)
