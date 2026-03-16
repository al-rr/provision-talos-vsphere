# Production Overlay - Talos

This overlay contains production-specific overrides for Talos node
provisioning. Shared automation lives under `overlays/base`.

## Status

- `Terraform` is the target VM provisioner for Talos nodes.
- `talosctl` remains the source of truth for secrets and machine configuration
  generation.
- Production patches and generated config paths belong to this overlay.

## Overlay Responsibilities

- Keep production topology overrides in `../scripts/vars.sh`.
- Keep production-only Talos patches in this directory.
- Keep production-only Terraform override files in `terraform/`.

## Canonical Commands

```bash
./overlays/base/scripts/talos-terraform.sh --env=prod
./overlays/base/scripts/talos-terraform.sh --env=prod --apply
```

Compatibility wrappers remain under `terraform/`, but they are not the primary
entrypoints.

## Notes

- The canonical Kubernetes endpoint should be the HAProxy VIP or DNS name on
  `:6443`.
- Talos API administrative access may still require reachability on `:50000`.
- Static addressing must be represented in the generated Talos machine configs.