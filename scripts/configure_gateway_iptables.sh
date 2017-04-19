#!/bin/sh

echo "Configure iptables rules"
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables --table nat --append POSTROUTING --out-interface enp0s3 -j MASQUERADE
# Add a line like this for each eth* LAN
iptables --append FORWARD --in-interface $1 -j ACCEPT
