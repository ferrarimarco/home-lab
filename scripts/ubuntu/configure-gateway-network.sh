#!/bin/sh

set -e

interface="$(ls --ignore="lo" --ignore="docker*" /sys/class/net/ | sed -n '2p')"

dns_nameserver=$2
domain=$4
gateway_ip_address=$1
subnet_mask=$3
echo "Configuring $interface interface with static IP address"
common_network_config="\n\
auto $interface\n\
iface $interface inet static\n\
      address $gateway_ip_address\n\
      netmask $subnet_mask\n\
      dns-nameservers $dns_nameserver\n\
      search $domain\n"

# We are configuring the gateway network interface
# so don't add the default route via the gateway itself, otherwise we lose
# internet connettivity.

# We need to configure IP forwarding and iptables
echo "Enable IPv4 forwarding"
sed -i '/ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

echo "Configuring iptables"
iptables --table nat --append POSTROUTING --out-interface enp0s3 -j MASQUERADE
# Add a line like this for each eth* LAN
iptables --append FORWARD --in-interface $interface -j ACCEPT

echo "Saving iptables rules"
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

echo "Configuring post-up hook to restore iptables configuration for the gateway"
default_gateway_config="      pre-up sleep 5\n\
      post-up iptables-restore < /etc/iptables/rules.v4\n"

echo "Network configuration for $interface interface:$common_network_config $default_gateway_config"
grep -q -F "auto $interface" /etc/network/interfaces \
|| printf "$common_network_config\
$default_gateway_config" >> /etc/network/interfaces

echo "/etc/network/interfaces contents:\n$(cat /etc/network/interfaces)"

echo "Restarting the networking service"
/etc/init.d/networking restart
