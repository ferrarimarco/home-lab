#!/bin/sh

name="dnsmasq"

if [ ! "$(docker ps -q -f name=$name)" ]; then
  echo "Starting $name container"
  docker run \
    -d \
    --hostname=$name \
    --name=$name \
    --net=host \
    --privileged \
    --restart=always \
    -v /etc/dnsmasq-home-lab/dhcp-hosts/host-configuration.conf:/etc/dhcp-hosts/host-configuration.conf
    ferrarimarco/home-lab-dnsmasq:1.2.1
else
  echo "$name container is already running"
fi
