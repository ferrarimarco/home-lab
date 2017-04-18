#!/bin/sh

cd /vagrant/docker-images/home-lab-dnsmasq
docker build -t ferrarimarco/home-lab-dnsmasq:dev-latest .
docker run -d --privileged --net=host ferrarimarco/dnsmasq:dev-latest
