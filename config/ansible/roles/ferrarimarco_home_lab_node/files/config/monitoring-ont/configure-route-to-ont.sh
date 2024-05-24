#!/bin/sh

set -o errexit
set -o nounset

Say() {
  # shellcheck disable=SC3037 # BusyBox's echo supports -e
  echo -e $$ "$@" | logger -st "($(basename "$0"))"
}

ONT_IP_ADDRESS="${1:-"192.168.1.1"}"
WAN_INTERFACE_LOCAL_IP_ADDRESS_AND_MASK="${2:-"192.168.1.3/24"}"

Say "Configure a route to the ONT (${ONT_IP_ADDRESS})"

WAN_INTERFACE_NAME="$(nvram get wan_ifname)"
Say "WAN interface name: ${WAN_INTERFACE_NAME}"

WAN_INTERFACE_MEDIA_TYPE="$(ethctl "${WAN_INTERFACE_NAME}" media-type)"
Say "WAN interface media type:\n${WAN_INTERFACE_MEDIA_TYPE}"

Say "Check if the ONT is reachable at the datalink layer:\n$(arping -I "${WAN_INTERFACE_NAME}" -c 2 "${ONT_IP_ADDRESS}")"

Say "Check if there's a route to the ONT (${ONT_IP_ADDRESS}) via ${WAN_INTERFACE_NAME}"
if ip route get "${ONT_IP_ADDRESS}" | grep -q "dev ${WAN_INTERFACE_NAME}"; then
  Say "A route to the ONT (${ONT_IP_ADDRESS}) through ${WAN_INTERFACE_NAME} exists"
else
  Say "A route to the ONT (${ONT_IP_ADDRESS}) through ${WAN_INTERFACE_NAME} doesn't exist"
  # Add a route to a single address because we might have a default gateway
  # configured through a VLAN on another interface
  ip route add "${ONT_IP_ADDRESS}/32" dev "${WAN_INTERFACE_NAME}"
fi

Say "IP routes:\n$(ip route)"

Say "Configure NAT because the ONT doesn't have a route back to the gateway, and sends all traffic to the optical interface by default"
if iptables -t nat -L POSTROUTING -n -v | grep "${WAN_INTERFACE_NAME}" | grep -q "MASQUERADE"; then
  Say "MASQUERADE is enabled for POSTROUTING on ${WAN_INTERFACE_NAME}"
else
  Say "MASQUERADE is not enabled for POSTROUTING on ${WAN_INTERFACE_NAME}. Enabling it"
  iptables -t nat -I POSTROUTING -o "${WAN_INTERFACE_NAME}" -j MASQUERADE
fi

Say "View iptables rules:\n$(iptables -t nat -L POSTROUTING -n -v)"

Say "Check if ${WAN_INTERFACE_NAME} has the ${WAN_INTERFACE_LOCAL_IP_ADDRESS_AND_MASK} address assigned"
if ! ip addr show "${WAN_INTERFACE_NAME}" | grep -q "${WAN_INTERFACE_LOCAL_IP_ADDRESS_AND_MASK}"; then
  ip address add "${WAN_INTERFACE_LOCAL_IP_ADDRESS_AND_MASK}" dev "${WAN_INTERFACE_NAME}"
  Say "Assigned ${WAN_INTERFACE_LOCAL_IP_ADDRESS_AND_MASK} to ${WAN_INTERFACE_NAME}"
else
  Say "${WAN_INTERFACE_NAME} alread has ${WAN_INTERFACE_LOCAL_IP_ADDRESS_AND_MASK} assigned"
fi

Say "Check if the ONT is reachable at the network layer:\n$(ping -I "${WAN_INTERFACE_NAME}" -c 2 "${ONT_IP_ADDRESS}")"
Say "If the ONT is reachable, and the admin user interface doesn't load at this point, try rebooting the ONT."
