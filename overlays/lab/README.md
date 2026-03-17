# Lab Overlay: Controller Bootstrap

This overlay contains the Vagrant-based lab controller bootstrap only.

The controller installs Ansible into the `vagrant` account and uses the shared
automation under `overlays/base/ansible`. The active HAProxy workspace is:

- tooling root: `overlays/base/ansible`
- runtime workspace: `overlays/base/ansible/haproxy`
- virtualenv: `/home/vagrant/venv`

## Maintained Scripts

- `scripts/install-ansible.sh`: installs Python, creates the controller
  virtualenv, and ensures SSH key material for `vagrant`
- `scripts/install-collections.sh`: installs Python dependencies from
  `overlays/base/ansible/requirements.txt` and collections from
  `overlays/base/ansible/requirements.yml`
- `scripts/run-playbook.sh`: runs the HAProxy playbook from the shared runtime
  workspace
- `scripts/vars.sh`: resolves controller paths and shared bootstrap variables

## Controller Flow

The `talos-controller` guest in `overlays/lab/Vagrantfile` provisions the
controller in two steps:

1. `install-ansible.sh`
2. `install-collections.sh`

The Vagrantfile passes explicit environment variables so the controller uses:

- `ANSIBLE_USER=vagrant`
- `ANSIBLE_HOME=/home/vagrant`
- `VENV_PATH=/home/vagrant/venv`
- `ANSIBLE_TOOLING_PATH=/home/vagrant/talos-vsphere-lab/overlays/base/ansible`
- `ANSIBLE_WORKSPACE_PATH=/home/vagrant/talos-vsphere-lab/overlays/base/ansible/haproxy`

## Manual Validation

From the controller guest:

```bash
cd /home/vagrant/talos-vsphere-lab/overlays/lab/scripts
./install-ansible.sh
./install-collections.sh
./run-playbook.sh --syntax-check
```

Useful direct checks:

```bash
/home/vagrant/venv/bin/python --version
/home/vagrant/venv/bin/ansible --version
/home/vagrant/venv/bin/ansible-inventory --list -i /home/vagrant/talos-vsphere-lab/overlays/base/ansible/haproxy/inventory
```

## Notes

- This layer is only for controller bootstrap assets.
- Shared HAProxy roles, inventory, playbooks, and requirements stay in
  `overlays/base/ansible`.
- This phase does not yet distribute SSH keys or complete guest provisioning for
  the two HAProxy nodes.
