#!/bin/bash
set -e

useradd -m -s /bin/bash vagrant
mkdir -p /home/vagrant/.ssh
cp /tmp/authorized_keys /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
chmod 600 /home/vagrant/.ssh/authorized_keys
echo "vagrant ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
