%{ if ip != null ~}
network --device=${device} --bootproto=static --ip=${ip} --netmask=${cidrnetmask("${ip}/${netmask}")} --gateway=${gateway} --nameserver=${join(",", dns)} --ipv6=auto --activate
%{ else ~}
network --device=${device} --bootproto=dhcp --ipv6=auto --activate
%{ endif ~}