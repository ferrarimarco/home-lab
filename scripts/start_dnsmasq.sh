#!/bin/sh

docker run -d --privileged --net=host --restart=always ferrarimarco/home-lab-dnsmasq:1.0.0
