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

## Talos Cluster From Scratch (Lab/ESXi)

After VM provisioning is done, run the initial Talos cluster creation flow to generate config,
apply to nodes, and bootstrap:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --cluster-name=talos \
  --endpoint=https://192.168.0.250:6443 \
  --generated-dir=overlays/lab/talos/talos/generated \
  --cp-ips=192.168.0.88,192.168.0.89,192.168.0.90 \
  --worker-ips=192.168.0.91,192.168.0.92,192.168.0.93
```

Dry-run:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --dry-run \
  --cluster-name=talos \
  --endpoint=https://192.168.0.250:6443 \
  --generated-dir=overlays/lab/talos/talos/generated \
  --cp-ips=192.168.0.88,192.168.0.89,192.168.0.90 \
  --worker-ips=192.168.0.91,192.168.0.92,192.168.0.93
```

Patch model:

- Cluster patches: `overlays/lab/talos/<cluster-name>/patches`

Use them only when explicitly requested:

```bash
./overlays/base/scripts/talos/cluster-bootstrap.sh \
  --env=lab \
  --mode=all \
  --cluster-name=talos \
  --endpoint=https://192.168.0.250:6443 \
  --generated-dir=overlays/lab/talos/talos/generated \
  --cp-ips=192.168.0.88,192.168.0.89,192.168.0.90 \
  --worker-ips=192.168.0.91,192.168.0.92,192.168.0.93
```

## Variable Source Of Truth

For this lab overlay, runtime values are centralized in:

- `overlays/lab/scripts/vars.sh`

Model:

- `BUILD_*`: build/bootstrap identity for images and first-boot guest operations
- `ANSIBLE_*`: remote automation identity for post-build configuration
- module/tool vars (`DNS_*`, `TALOS_*`, `HAPROXY_*`, `GOVC_*`) resolve from this overlay file when applicable
