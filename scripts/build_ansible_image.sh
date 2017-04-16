#!/bin/sh

cd /vagrant/docker-images/home-lab-ansible
docker build -t ferrarimarco/home-lab-ansible:dev-latest .
