ignoredisk --only-use=sda,sdb

# System bootloader configuration
# bootloader --append="crashkernel=auto" --location=mbr --boot-drive=$DISK1

# Partition clearing information
clearpart --none --initlabel

# Disk partitioning information
part /boot --fstype="xfs" --ondisk=sda --size=1024       # (~1.024 GB)
part /boot/efi --fstype="efi" --ondisk=sda --size=1024 --fsoptions="umask=0077,shortname=winnt"  # (~1.024 GB)

# Disk partitioning information
part pv.sysvg --grow --fstype="lvmpv" --ondisk=sda --size=22000   # (~22.5 GB)
part pv.datavg --grow --fstype="lvmpv" --ondisk=sdb --size=39000  # (~40 GB)



volgroup vg_ol --pesize=4096 pv.sysvg
volgroup vg_data --pesize=4096 pv.datavg

## Partições do Sistema Operacional
logvol / --name=root --fstype="xfs" --size=10000 --vgname=vg_ol             # (~10 GB)
logvol /var --name=var --fstype="xfs" --size=5000 --vgname=vg_ol            # (~5 GB)
logvol /tmp --name=tmp --fstype="xfs" --size=2000 --vgname=vg_ol            # (~2 GB)
logvol /dev/shm --name=dev_shm --fstype="xfs" --size=1000 --vgname=vg_ol    # (~1 GB)
logvol swap --name=swap --grow --size=2000 --maxsize=4000 --vgname=vg_ol    # (~4 GB)
## Partições de Dados
logvol /var/www --name=var_www --fstype="xfs" --size=2000 --vgname=vg_data             # (~30 GB)
logvol /var/log --name=var_log --fstype="xfs" --size=2000 --vgname=vg_data             # (~2 GB)
logvol /var/log/audit --name=var_log_audit --fstype="xfs" --size=2000 --vgname=vg_data # (~2 GB)
logvol /home --name=home --grow --fstype="xfs" --size=5000 --vgname=vg_data            # (~5 GB) 