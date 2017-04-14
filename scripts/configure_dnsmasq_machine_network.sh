#!/bin/sh

interface=enp0s8

echo "Configuring $interface interface"


grep -q -F "auto $interface" /etc/network/interfaces \
|| printf "\n\
auto $interface\n\
iface $interface inet static\n\
      address 192.168.0.5\n\
      netmask 255.255.0.0\n\
      dns-nameservers 192.168.0.5\n\
      dns-search ferrari.home\n\
      gateway 192.168.0.1\n" >> /etc/network/interfaces

echo "Bringing down $interface"
ifdown $interface

echo "Bringing $interface back up"
ifup $interface
