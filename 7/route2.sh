#!/usr/bin/env bash

IP=$(ip -br -4 addr | grep enp0s8 | awk '{print $3}')

cat <<EOT> /etc/netplan/50-vagrant.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      addresses:
      - $IP
      routes:
      - to: 192.168.10.0/24
        via: 192.168.20.254
      - to: 172.20.1.0/24
        via: 192.168.20.254
EOT
netplan apply