#!/bin/bash

# Remove conflicting packages before installing Docker.
# These packages may conflict with the Docker installation.

echo "Removing conflicting packages..."
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

sudo systemctl enable docker
sudo systemctl start docker
