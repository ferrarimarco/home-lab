#!/bin/sh

cd /vagrant/docker-images/home-lab-dnsmasq
docker run -d --privileged --net=host ferrarimarco/home-lab-dnsmasq:dev-latest
