#!/bin/sh

set -e

if ! TEMP="$(getopt -o vdm: --long ip-v4-host-address:,ip-v4-host-cidr:,network-type: -n 'configure-volatile-network-interface' -- "$@")" ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

interface="$(find /sys/class/net \( -not -name lo -and -not -name 'docker*' -and -not -type d \) -printf "%f\\n" | sort | sed -n '2p')"
ip_v4_host_address=
ip_v4_host_cidr=
network_type=

while true; do
  case "$1" in
    -h | --ip-v4-host-address ) ip_v4_host_address="$2"; shift 2 ;;
    -j | --ip-v4-host-cidr ) ip_v4_host_cidr="$2"; shift 2 ;;
    -t | --network-type ) network_type="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

echo "Setting $interface up"
ip link set "$interface" up

if [ "$network_type" = "dhcp" ]; then
  echo "Configuring $interface interface with $network_type"

  echo "Stopping dhclient"
  dhclient -r

  echo "Restarting dhclient for all interfaces"
  dhclient
elif [ "$network_type" = "static_ip" ]; then
  echo "Configuring $ip_v4_host_address/$ip_v4_host_cidr IP address for $interface interface"

  current_ip="$(ip -o -4 addr list "$interface" | awk '{print $4}')"
  if [ "$current_ip" != "$ip_v4_host_address/$ip_v4_host_cidr" ]; then
    if [ -n "$current_ip" ]; then
      echo "Removing $current_ip IP address from $interface interface"
      ip addr del "$current_ip" dev "$interface"
    fi
    echo "Adding $ip_v4_host_address/$ip_v4_host_cidr IP address to $interface interface"
    ip addr add "$ip_v4_host_address/$ip_v4_host_cidr" dev "$interface"
  fi
else
  (>&2 echo "No compatible network configuration found")
  exit 1
fi;

echo "Completed volatile $interface network interface configuration"
