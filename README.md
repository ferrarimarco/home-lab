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

- Vagrant 2.0.2+
- Virtualbox 5.2.6+

## Manual Steps

There are a number of manual steps to follow in order to bootstrap this Lab

### DNS/DHCP/PXE Server (Ubuntu Server x86)

1. Install Ubuntu server
1. Configure administrative user
1. Install cURL: `apt install curl`
1. Deploy public SSH key: `mkdir $HOME/.ssh ; curl -l http://github.com/ferrarimarco.keys`
1. Install OpenSSH Server and start the related service: `apt install openssh-server ; service ssh restart`
1. Install git: `apt install git`
1. Install NetworkManager: `scripts/ubuntu/install-network-manager.sh`
1. Install Docker: `scripts/ubuntu/install-docker.sh --user username`
1. Remove network interfaces (except for `lo`) from `/etc/network/interfaces`: `scripts/ubuntu/cleanup-network-interfaces.sh`
1. Configure network interface with NetworkManager: `scripts/ubuntu/configure-network-manager.sh --domain lab.ferrarimarco.info --ip-v4-dns-nameserver 192.168.0.5 --ip-v4-gateway-ip-address 192.168.0.1 --ip-v4-host-cidr 16 --ip-v4-host-address 192.168.0.5 --network-type static_ip`
1. Disable other DHCP servers, if any
1. Start DNSMASQ mounting a static host names file considering the real MAC addresses in the DNSMasq container: `scripts/ubuntu/start-dnsmasq.sh`

### DNS/DHCP/PXE Server (Debian ARM)

1. Download Raspbian Lite: `wget --content-disposition https://downloads.raspberrypi.org/raspbian_lite_latest`
