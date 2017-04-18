#!/bin/sh

interface=enp0s8

echo "Configuring $interface interface"


grep -q -F "auto $interface" /etc/network/interfaces \
|| printf "\n\
auto $interface\n\
iface $interface inet static\n\
      address 192.168.0.5\n\
      netmask 255.255.0.0\n\
      dns-nameservers 8.8.8.8 8.8.4.4\n\
      dns-search ferrari.home\n\
      gateway 192.168.0.1\n" >> /etc/network/interfaces

echo "Bringing down $interface"
ifdown $interface

echo "Bringing $interface back up"
ifup $interface

# The first nameserver is the one that the host queries.
# The others are considered only if the first one times out
echo "Put Google DNS server on top in /etc/resolv.conf"
nameserver_line="nameserver 8.8.8.8"
sed -i "/$nameserver_line/d" /etc/resolv.conf
sed -i "/nameserver/c\\$nameserver_line" /etc/resolv.conf

echo "Configure local domain"
sed -i "/search/c\search ferrari.home" /etc/resolv.conf

echo "Add default route via sun.ferrari.home"
ip route del default
ip route add default via 192.168.0.1 dev $interface
