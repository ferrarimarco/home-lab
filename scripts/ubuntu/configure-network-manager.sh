#!/bin/sh

set -e

if ! TEMP="$(getopt -o vdm: --long domain:,ip-v4-dns-nameserver:,ip-v4-gateway-ip-address:,ip-v4-host-address:,ip-v4-host-cidr:,network-type: -n 'configure-network-manager' -- "$@")" ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

domain=
interface="$(find /sys/class/net \( -not -name lo -and -not -name 'docker*' -and -not -type d \) -printf "%f\\n" | sort | sed -n '2p')"
ip_v4_dns_nameserver=
ip_v4_gateway_ip_address=
ip_v4_host_address=
ip_v4_host_cidr=
network_type=

while true; do
  case "$1" in
    -d | --ip-v4-dns-nameserver ) ip_v4_dns_nameserver="$2"; shift 2 ;;
    -g | --ip-v4-gateway-ip-address ) ip_v4_gateway_ip_address="$2"; shift 2 ;;
    -h | --ip-v4-host-address ) ip_v4_host_address="$2"; shift 2 ;;
    -j | --ip-v4-host-cidr ) ip_v4_host_cidr="$2"; shift 2 ;;
    -s | --domain ) domain="$2"; shift 2 ;;
    -t | --network-type ) network_type="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

echo "Configuring $interface interface with a $network_type configuration"

if [ "$network_type" = "dhcp" ]; then
  echo "No additional configuration for $network_type is needed, let NetworkManager do the work"
elif [ "$network_type" = "static_ip" ]; then
  echo "Configuring $network_type on $interface interface with $ip_v4_host_address/$ip_v4_host_cidr IPv4 address, $ip_v4_dns_nameserver IPv4 DNS, $domain IPv4 Domain, $ip_v4_gateway_ip_address IPv4 Gateway"
  nmcli connection add \
    con-name "$interface" \
    ifname "$interface" \
    type ethernet \
    ip4 "$ip_v4_host_address/$ip_v4_host_cidr" \
    gw4 "$ip_v4_gateway_ip_address"

  nmcli connection modify "$interface" ipv4.dns "$ip_v4_dns_nameserver"
  nmcli connection modify "$interface" ipv4.dns-search "$domain"
  nmcli connection up "$interface"
else
  (>&2 echo "No compatible network configuration found")
  exit 1
fi;
