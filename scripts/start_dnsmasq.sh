#!/bin/sh

docker run -d --privileged --net=host --restart=always ferrarimarco/home-lab-dnsmasq:dev-latest
