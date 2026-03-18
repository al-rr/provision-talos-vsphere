# Controller Scripts

This directory contains scripts that are specific to the lab controller host.

## Scripts

- `install-controller-deps.sh`: installs controller base dependencies (`make`, `govc`)
- `install-ansible.sh`: creates/updates controller Python virtualenv for Ansible
- `install-collections.sh`: installs Python and Galaxy dependencies for Ansible
- `run-playbook.sh`: runs the HAProxy playbook from the controller virtualenv
- `install-kubectl.sh`: installs/updates `kubectl` on the controller (idempotent)
- `vars.sh`: controller environment variables and helper functions

## Notes

- These scripts are controller-only and belong to `overlays/lab/controller`.
- Legacy wrappers still exist in `overlays/lab/scripts` for backward compatibility.
