#!/bin/sh

name="ddclient"

if [ ! "$(docker ps -q -f name=$name)" ]; then
  echo "Starting $name container"
  docker run \
    -d \
    --hostname=$name \
    --name=$name \
    --net=host \
    --restart=always \
    -v /etc/ddclient:/config \
    linuxserver/ddclient:96
else
  echo "$name container is already running"
fi
