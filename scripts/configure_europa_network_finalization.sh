#!/bin/sh

# The first nameserver is the one that the host queries.
# The others are considered only if the first one times out
echo "Put ferrari.home DNS server on top in /etc/resolv.conf"
nameserver_line="nameserver 192.168.0.5"
sed -i "/nameserver/c\\$nameserver_line" /etc/resolv.conf
