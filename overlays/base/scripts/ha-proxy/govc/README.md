# HAProxy VMware Provisioning

## Purpose

This directory contains HAProxy-specific provisioning entrypoints that depend on
`govc` and target VMware platforms such as ESXi and vSphere.

Keep HAProxy provisioning logic here when the lifecycle belongs to the HAProxy
module, even if the implementation uses `govc`.

## Files

- `provision.sh`: VMware provisioning entrypoint for HAProxy VMs

## Notes

- Install and configure `govc` using the GOVC module:
  - [overlays/base/scripts/govc/README.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/govc/README.md)
- Use the higher-level entrypoints in the HAProxy module for normal operations:
  - [overlays/base/scripts/ha-proxy/README.md](/home/vagrant/talos-vsphere-lab/overlays/base/scripts/ha-proxy/README.md)
