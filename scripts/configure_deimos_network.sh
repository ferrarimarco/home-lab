#!/bin/sh

interface=enp0s8

echo "Configuring $interface interface"

grep -q -F "auto $interface" /etc/network/interfaces \
|| printf "\n\
auto $interface\n\
iface $interface inet dhcp\n" >> /etc/network/interfaces

echo "Bringing down $interface"
ifdown $interface

echo "Bringing $interface back up"
ifup $interface

echo "Add default route via sun.ferrari.home"
ip route del default
ip route add default via 192.168.0.1 dev $interface
