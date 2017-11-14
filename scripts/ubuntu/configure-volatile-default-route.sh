#!/bin/sh

set -e

TEMP=`getopt -o vdm: --long ip-v4-gateway-ip-address: -n 'configure-volatile-default-route' -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

interface="$(ls --ignore="lo" --ignore="docker*" /sys/class/net/ | sed -n '2p')"
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
    echo "Removing default route from $interface interface"
    ip route del default
  fi
  echo "Configuring the default route for $interface interface via $ip_v4_gateway_ip_address gateway"
  ip route add default via $ip_v4_gateway_ip_address dev $interface
fi

current_default_gateway="$(ip route | awk '/default/ { print $3 }')"
echo "Current default gateway for $interface interface: $current_default_gateway"
