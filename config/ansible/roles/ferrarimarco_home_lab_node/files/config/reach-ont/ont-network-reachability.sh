#!/usr/bin/env sh

set -o errexit
set -o nounset

# Get the WAN network interface name
WAN_INTERFACE_NAME="$(nvram get wan_ifname)"

# The IP addresses and netmasks below work for the ZTE F6005 ONT

# Add another IPv4 address to the WAN network interface on the ONT subnet
ifconfig "${WAN_INTERFACE_NAME}":0 192.168.1.3 netmask 255.255.255.0

# Enable NAT on the WAN network interface so the router can forward packets
# from the ONT to local clients
iptables -t nat -I POSTROUTING -o "${WAN_INTERFACE_NAME}" -j MASQUERADE

# Add a route to the ONT
ip route add 192.168.1.1/32 dev "${WAN_INTERFACE_NAME}"
