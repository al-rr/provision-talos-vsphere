# Copyright 2024-2025 Assembleia Legislativa do Estado de Roraima. Todos os direitos reservados.
# Oracle Linux Server 8

# Use text install
text

# repo --name="AppStream" --baseurl=file:///run/install/sources/mount-0000-cdrom/AppStream

### Accepts the End User License Agreement.
eula --agreed

# Use CDROM installation media
cdrom

# Keyboard layouts
keyboard ${vm_guest_os_keyboard}

# System language
lang ${vm_guest_os_language}

# System timezone
timezone ${vm_guest_os_timezone}

# Run the Setup Agent on first boot
firstboot --enable

# Network information
network --bootproto=dhcp --onboot=on --activate 
# network --bootproto=dhcp --device=ens192 --onboot=on --activate 
# network --bootproto=dhcp --onboot=on --nameserver=192.168.0.139 --activate
# network --hostname=teste.al.rr.leg.br --bootproto=dhcp --onboot=on --nameserver=192.168.0.139
## network --hostname=teste.al.rr.leg.br --bootproto=static --ip=192.168.0.15 --netmask=255.255.255.0 --gateway=192.168.0.2 --nameserver=192.168.0.139

# Partitioning
${storage}

### Modifies the default set of services that will run under the default runlevel.
services --enabled=NetworkManager,sshd

### Do not configure X on the installed system.
skipx

# kexec-tools
# @^minimal-environment
%packages --ignoremissing --excludedocs
@core
sudo
open-vm-tools
perl
net-tools
vim-minimal
yum-utils
dnf-utils
rsync
aide
audit
wget
curl
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
dnf clean all
dnf makecache
dnf -y update
dnf install -y oracle-epel-release-el8
%{ if additional_packages != "" ~}
dnf install -y ${additional_packages}
%{ endif ~}

echo "${build_username} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${build_username}
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
# %include http://192.168.0.113/post_install_zabbix_agent2
%end

#%anaconda
#pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
#pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
#pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
#%end

### Reboot after the installation is complete.
### --eject attempt to eject the media before rebooting.
reboot --eject