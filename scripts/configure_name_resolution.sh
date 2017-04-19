#!/bin/sh

dns_nameserver=$1
domain=$2

# The first nameserver is the one that the host queries.
# The others are considered only if the first one times out
echo "Put $dns_nameserver DNS server on top in /etc/resolv.conf"
nameserver_line="nameserver $dns_nameserver"
sed -i "/$nameserver_line/d" /etc/resolv.conf
sed -i "0,/nameserver/c\\$nameserver_line" /etc/resolv.conf

echo "Configure local domain: $domain"
sed -i "/search/c\search $domain" /etc/resolv.conf
