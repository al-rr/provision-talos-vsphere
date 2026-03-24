# Copyright 2024-2025 Assembleia Legislativa do Estado de Roraima. Todos os direitos reservados.
# Oracle Linux Server 8

# Use CDROM installation media
cdrom

# Use text install
text

### Accepts the End User License Agreement.
eula --agreed

# Keyboard layouts
keyboard ${vm_guest_os_keyboard}

# System language
lang ${vm_guest_os_language}

# System timezone
timezone ${vm_guest_os_timezone}

# Run the Setup Agent on first boot
## funcionava
# firstboot --enable

# Network information
${network}
### Configure network information for target system and activate network devices in the installer environment (optional)
# network examples:
# network --bootproto=dhcp --device=link --activate

# Partitioning
#########################################
zerombr
clearpart --all --initlabel
autopart
#########################################

### Modifies the default set of services that will run under the default runlevel.
services --enabled=NetworkManager,sshd

### Do not configure X on the installed system.
skipx

# kexec-tools
# @^minimal-environment
%packages --ignoremissing --excludedocs
@core
sudo
openssh-server
open-vm-tools
-iwl*firmware
-ftp
-net-snmp
-telnet
-telnet-server
-tftp
-tftp-server
-xinetd
-ypbind
-ypserv
%end



# Credentials
### Lock the root account.
# rootpw --lock
### The selected profile will restrict root login.
### Add a user that can login and escalate privileges.
user --name=${build_username} --iscrypted --password=${build_password_encrypted} --groups=wheel

### Sets up the authentication options for the system.
### The SSDD profile sets sha512 to hash passwords. Passwords are shadowed by default
### See the manual page for authselect-profile for a complete list of possible options.
authselect select sssd

### Sets the state of SELinux on the installed system.
### Defaults to enforcing.
selinux --enforcing

### Configure firewall settings for the system.
### --enabled	reject incoming connections that are not in response to outbound requests
### --ssh		allow sshd service through the firewall
firewall --enabled --ssh


%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

### Post-installation
%post
dnf install -y oracle-epel-release-el9
dnf makecache
dnf install -y sudo open-vm-tools perl
%{ if additional_packages != "" ~}
dnf install -y ${additional_packages}
%{ endif ~}

echo "${build_username} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${build_username}
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
%{ if build_key != "" ~}
install -d -m 0700 /home/${build_username}/.ssh
cat <<'EOF_AUTHKEY' > /home/${build_username}/.ssh/authorized_keys
${build_key}
EOF_AUTHKEY
chown -R ${build_username}:${build_username} /home/${build_username}/.ssh
chmod 0600 /home/${build_username}/.ssh/authorized_keys
%{ endif ~}
%end

#%anaconda
#pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
#pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
#pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
#%end

### Reboot after the installation is complete.
### --eject attempt to eject the media before rebooting.
reboot --eject
