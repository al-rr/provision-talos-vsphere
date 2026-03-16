#!/bin/bash

# Update packages
sudo apt-get update
sudo apt-get upgrade -y

# Install base dependencies
sudo apt-get install -y curl wget git unzip python3-pip jq bash-completion

# Install govc
if [ ! -f /usr/local/bin/govc ]; then
    echo "Installing VMware GOVC"
    curl -L -o - "https://github.com/vmware/govmomi/releases/latest/download/govc_$(uname -s)_$(uname -m).tar.gz" | tar -C /usr/local/bin -xvzf - govc
fi

# Install Packer
echo "Installing HashiCorp Packer..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer

# Install Helm
echo "Installing Helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

# Install talosctl if not already installed
if [ ! -f /usr/local/bin/talosctl ]; then
    echo "Installing talosctl..."
    curl -sL https://talos.dev/install | sh
fi

# Get talosctl version
TALOS_VERSION=$(talosctl version | grep 'Client:' | awk '{print $2}')
echo "Installed talosctl version: $TALOS_VERSION"

echo "Installing kubectl..."
cd /tmp || exit
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
echo "Validating..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Legacy vmware.sh references kept for historical context:
# curl -fsSL "https://raw.githubusercontent.com/siderolabs/talos/master/website/content/release-1.12/talos-guides/install/virtualized-platforms/vmware/vmware.sh" | sed s/latest/v1.12.4/ > vmware.sh
# curl -fsSL "https://raw.githubusercontent.com/siderolabs/talos/master/website/content/release-1.11/talos-guides/install/virtualized-platforms/vmware/vmware.sh" | sed s/latest/v1.11.5/ > vmware.sh
# curl -fsSL "https://raw.githubusercontent.com/siderolabs/talos/master/website/content/v1.11/talos-guides/install/virtualized-platforms/vmware/vmware.sh" | sed s/latest/v1.11.0/ > vmware.sh
