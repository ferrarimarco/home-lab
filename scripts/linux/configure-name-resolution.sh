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

resolvconf_path="/etc/resolvconf/resolv.conf.d/head"

echo "resolv.conf path: $resolvconf_path"

if [ -e "$resolvconf_path" ]; then
  echo "$resolvconf_path exists"
else
  echo "$resolvconf_path not found"
  resolvconf_path="/etc/resolv.conf"
  echo "Falling back on $resolvconf_path"
fi

echo "Removing all previous nameservers"
sed -i '/^nameserver/d' $resolvconf_path

echo "Setting $ip_v4_dns_nameserver as the preferred DNS server"
echo "nameserver $ip_v4_dns_nameserver" >> "$resolvconf_path"

if which resolvconf >/dev/null 2>&1; then
  echo "Refreshing $resolvconf_path"
  resolvconf -u
fi
