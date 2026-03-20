# DNS Script Module

## Purpose
Provides a reusable DNS module for lab and pre-production simulations where Talos nodes
need a stable resolver.

This module includes:
- `provision.sh`: provisions DNS VM(s) on ESXi/vSphere using GOVC
- `install.sh`: installs DNS package (`dnsmasq` by default)
- `setup.sh`: renders and applies `dnsmasq` config
- `vars.sh`: DNS provisioning + service defaults

## Why This Matters

When Talos nodes depend on a non-working DNS in the lab network, bootstrap and runtime
operations can fail intermittently. A dedicated DNS VM in the same subnet gives:
- stable name resolution for node bootstrapping,
- deterministic behavior between test runs,
- closer behavior to production-like environments.

## Default Flow

1. Provision DNS VM:

```bash
./overlays/base/scripts/dns/provision.sh \
  --env=lab \
  --vars-file=overlays/base/scripts/govc/vars-esxi-prod.sh \
  create
```

2. Install dnsmasq in DNS VM:

```bash
./overlays/base/scripts/dns/install.sh \
  --env=lab \
  --vars-file=overlays/base/scripts/govc/vars-esxi-prod.sh \
  --host=192.168.0.53 \
  --user=vagrant \
  --ssh-key=/path/to/private_key
```

3. Configure dnsmasq in DNS VM:

```bash
./overlays/base/scripts/dns/setup.sh \
  --env=lab \
  --vars-file=overlays/base/scripts/govc/vars-esxi-prod.sh \
  --host=192.168.0.53 \
  --user=vagrant \
  --ssh-key=/path/to/private_key
```

## Key Variables

- VM provisioning:
  - `DNS_VM_NAME_PREFIX`, `DNS_VM_COUNT`, `DNS_VM_START_INDEX`
  - `DNS_VM_STATIC_IP`, `DNS_VM_GATEWAY`, `DNS_VM_NETMASK_PREFIX`
  - `DNS_VM_BOOTSTRAP_NAMESERVERS`, `DNS_VM_STATIC_INTERFACE`
- dnsmasq service:
  - `DNS_CONFIG_PATH`, `DNS_SERVICE_NAME`, `DNS_LISTEN_ADDRESSES`
  - `DNS_UPSTREAM_SERVERS`, `DNS_DOMAIN`, `DNS_A_RECORDS`

`DNS_A_RECORDS` format:

```text
host1.lab.local=192.168.0.10,host2.lab.local=192.168.0.11
```

## Notes

- `provision.sh` is a thin wrapper on top of `overlays/base/scripts/ha-proxy/govc/provision.sh`.
- You can pass extra GOVC flags to `provision.sh` (for example `--mode=clone`, `--template=...`).
- In standalone ESXi, prefer `--mode=ovf`/`--mode=ova` for deterministic provisioning.
