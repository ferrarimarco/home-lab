# home-lab
All the necessary to provision, configure and manage my home lab.

* Development branch: [![Build Status](https://travis-ci.org/ferrarimarco/home-lab.svg?branch=development)](https://travis-ci.org/ferrarimarco/home-lab)
* Master branch: [![Build Status](https://travis-ci.org/ferrarimarco/home-lab.svg?branch=master)](https://travis-ci.org/ferrarimarco/home-lab)

## Components

- A [dockerized Dnsmasq instance (ferrarimarco/home-lab-dnsmasq)](https://github.com/ferrarimarco/home-lab-dnsmasq)
- A [dockerized Ansible instance (ferrarimarco/docker-home-lab-ansible)](https://github.com/ferrarimarco/docker-home-lab-ansible)

## Development Environment

The development environment is currently managed with Vagrant. Run `vagrant up` from the root directory of this repository to start the environment.

### Dependencies

- Vagrant 1.9.3+
- Virtualbox 5.1.16+

## Manual Steps

There are a number of manual steps to follow in order to bootstrap this Lab

### DNS/DHCP Server

1. Install Ubuntu server
1. Configure administrative user
1. Install cURL: `apt install curl`
1. Deploy public SSH key: `mkdir $HOME/.ssh ; curl -l http://github.com/ferrarimarco.keys`
1. Install OpenSSH Server and start the related service: `apt install openssh-server ; service ssh restart`
1. Install git: `apt install git`
1. Install NetworkManager
1. Remove network interfaces (except for `lo`) from `/etc/network/interfaces`
1. Disable the DHCP server running on the network gateway
1. Configure network interface with NetworkManager
1. Install Docker
1. Mount a static host names file considering the real MAC addresses in the DNSMasq container
1. Start (and configure autostart) the DNSMasq container
1. Bootstrap nodes
1. Run infrastructure test
