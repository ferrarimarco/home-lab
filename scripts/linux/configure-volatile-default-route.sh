#!/bin/sh

set -e

if ! TEMP="$(getopt -o vdm: --long ip-v4-gateway-ip-address: -n 'configure-volatile-default-route' -- "$@")" ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

interface="$(find /sys/class/net \( -not -name lo -and -not -name 'docker*' -and -not -type d \) -printf "%f\\n" | sort | sed -n '2p')"
ip_v4_gateway_ip_address=

while true; do
  case "$1" in
    -g | --ip-v4-gateway-ip-address ) ip_v4_gateway_ip_address="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

current_default_gateway="$(ip route | awk '/default/ { print $3 }')"
echo "Current default gateway for $interface interface: $current_default_gateway. Desired default gateway: $ip_v4_gateway_ip_address"
if [ "$current_default_gateway" != "$ip_v4_gateway_ip_address" ]; then
  if [ -n "$current_default_gateway" ]; then
    echo "Removing default routes from $interface interface"
    while default_route="$(ip route | grep "default")"; do
      echo "Removing $default_route"
      ip route del default
    done
  fi
  echo "Configuring the default route for $interface interface via $ip_v4_gateway_ip_address gateway"
  ip route add "$ip_v4_gateway_ip_address" dev "$interface"
  ip route add default via "$ip_v4_gateway_ip_address" dev "$interface"
fi

current_default_gateway="$(ip route | awk '/default/ { print $3 }')"
echo "Current default gateway for $interface interface: $current_default_gateway"
