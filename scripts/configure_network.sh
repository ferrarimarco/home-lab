#!/bin/sh

interface=$1

if [ "$2" = "dhcp" ]; then
  echo "Configuring $interface interface with DHCP IP address"
  gateway_ip_address=$3
  common_network_config="\n\
auto $interface\n\
iface $interface inet dhcp\n"
else
  dns_nameserver=$3
  domain=$6
  gateway_ip_address=$4
  host_ip_address=$2
  subnet_mask=$5
  echo "Configuring $interface interface with static IP address"
  common_network_config="\n\
auto $interface\n\
iface $interface inet static\n\
      address $host_ip_address\n\
      netmask $subnet_mask\n\
      dns-nameservers $dns_nameserver\n\
      dns-search $domain\n"
fi;

if [ ! -z "$host_ip_address" ] && [ ! -z "$gateway_ip_address" ] && [ "$host_ip_address" = "$gateway_ip_address" ]; then
  # We are configuring the gateway network interface
  # so don't add the default route via the gateway itself, otherwise we lose
  # internet connettivity
  echo "Skipped default route configuration (not necessary on the gateway)"
  default_gateway_config="\n"
else
  # We cannot use "gateway $gateway_ip_address" because Vagrant configures
  # a (required) NATed interface via the DHCP server provided by the
  # hypervisor and that interface is brought up before the statically configured
  # one. So we have to explicitely delete the default route and add a new one
  # instead of relying on the builtin way.
  echo "Configuring the default route"
  default_gateway_config="      pre-up sleep 5\n\
      post-up ip route del default && ip route add default via $gateway_ip_address dev $interface\n"
fi;

echo "Network configuration for $interface interface:$common_network_config $default_gateway_config"
grep -q -F "auto $interface" /etc/network/interfaces \
|| printf "$common_network_config\
$default_gateway_config" >> /etc/network/interfaces

echo "/etc/network/interfaces contents:\n$(cat /etc/network/interfaces)"

echo "Restarting the networking service"
/etc/init.d/networking restart
