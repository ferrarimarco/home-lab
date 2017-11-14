#!/bin/sh

set -e

if ! TEMP="$(getopt -o vdm: --long ip-v4-dns-nameserver: -n 'configure-name-resolution' -- "$@")" ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

ip_v4_dns_nameserver=

while true; do
  case "$1" in
    -d | --ip-v4-dns-nameserver ) ip_v4_dns_nameserver="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

echo "Removing all previous nameservers"
sed -i '/^nameserver/d' /etc/resolvconf/resolv.conf.d/head

echo "Setting $ip_v4_dns_nameserver as the preferred DNS server"
echo "nameserver $ip_v4_dns_nameserver" >> /etc/resolvconf/resolv.conf.d/head

echo "Refreshing /etc/resolv.conf"
resolvconf -u
