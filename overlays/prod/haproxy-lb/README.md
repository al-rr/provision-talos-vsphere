# Production Overlay - HAProxy Load Balancer

This overlay contains production-specific overrides for the HAProxy load
balancer workflow. Shared automation lives under `overlays/base`.

## Status

- Target topology: `2x HAProxy + VIP`
- Immediate VM lifecycle: `govc`
- In-guest service configuration: `Ansible`
- Packer and Terraform assets remain draft or future-facing paths for HAProxy

## Overlay Responsibilities

- Keep production topology overrides in `../scripts/vars.sh`.
- Keep production-only Packer overrides in `packer/`.
- Keep production-only Terraform override files in `terraform/`.

## Canonical Commands

```bash
./overlays/base/scripts/haproxy-packer-build.sh --env=prod --validate-only
./overlays/base/scripts/haproxy-terraform.sh --env=prod
./overlays/base/scripts/haproxy-ansible.sh --env=prod --syntax-check
./overlays/base/scripts/haproxy-ansible.sh --env=prod
```

Compatibility wrappers remain in this overlay, but they are not the primary
entrypoints.

## Operational Notes

- Kubernetes endpoint traffic should land on the VIP or DNS endpoint on `:6443`.
- Talos API administrative reachability on `:50000` must be planned
  separately.
- Do not label this overlay production-ready until the VIP layer exists and is
  validated.