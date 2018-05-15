# home-lab
All the necessary to provision, configure and manage my home lab.

[![Build Status](https://travis-ci.org/ferrarimarco/home-lab.svg?branch=master)](https://travis-ci.org/ferrarimarco/home-lab)

## Components

- A [dockerized ddclient instance (ferrarimarco/docker-ddclient)](https://github.com/ferrarimarco/docker-ddclient)
- A [dockerized Dnsmasq instance (ferrarimarco/docker-home-lab-dnsmasq)](https://github.com/ferrarimarco/docker-home-lab-dnsmasq)
- A [dockerized Ansible instance (ferrarimarco/docker-home-lab-ansible)](https://github.com/ferrarimarco/docker-home-lab-ansible)
- A [dockerized OpenVPN instance (kylemanna/docker-openvpn)](https://github.com/kylemanna/docker-openvpn)

## Development Environment

The development environment is currently managed with Vagrant. Run `vagrant up` from the root directory of this repository to start the environment.

### Dependencies

- Vagrant 2.0.3+
- Virtualbox 5.2.8+

## Manual Steps

There are a number of manual steps to follow in order to bootstrap this Lab. The first machine (likely the DHCP/DNS/PXE server) in this lab
has to be bootstrapped manually.

### OS Installation

#### Ubuntu Server - x86

1. Download Ubuntu from: `https://www.ubuntu.com/download/server`
1. Load Ubuntu Server on a USB flash drive
1. Install Ubuntu server

#### Debian ARM - BeagleBone Black

1. Download latest debian from : `http://beagleboard.org/latest-images`
1. Write the image on a SD card
1. Ensure the board is powered off
1. Insert the microSD
1. Boot the board using the SD card. Note that it may be necessary to press the Boot button (near the microSD slot) until the user LEDs turn on (necessary for old uBoot versions)
1. Edit `uEnv.txt` to allow flashing the internal eMMC: edit the `/boot/uEnv.txt` file on the Linux partition on the microSD card and uncomment the line with `cmdline=init=/opt/scripts/tools/eMMC/init-eMMC-flasher-v3.sh`. Note that the `/uEnv.txt` is there for backward compatibility reasons, don't touch it
1. Reboot the board to flash the internal eMMC
1. Repartition the SD card (if necessary) to be used as an external disk

#### Debian ARM - Raspberry Pi

1. Download Raspbian Lite: `wget --content-disposition https://downloads.raspberrypi.org/raspbian_lite_latest`

### DNS/DHCP/PXE Server Configuration (Debian and derivatives)

1. Configure administrative user
1. Login as the administrative user
1. Remove the predefined user: `userdel -r -f debian`
1. Install cURL: `apt install curl`
1. Deploy public SSH keys: `mkdir -p $HOME/.ssh ; chmod 700 $HOME/.ssh ; curl -l http://github.com/ferrarimarco.keys > $HOME/.ssh/authorized_keys ; chmod 600 $HOME/.ssh/authorized_keys`
1. Install OpenSSH Server and start the related service: `apt install openssh-server ; service ssh restart`
1. Install git: `apt install git`
1. Clone this repository in `/opt`: `cd /opt ; git clone https://github.com/ferrarimarco/home-lab.git`
1. Grant executable permission to scripts: `find scripts/linux -type f -iname "*.sh" -exec chmod a+x {} \;`
1. Install NetworkManager: `scripts/ubuntu/install-network-manager.sh`
1. Install Docker: `scripts/ubuntu/install-docker.sh --user username`
1. Remove network interfaces (except for `lo`) from `/etc/network/interfaces`: `scripts/ubuntu/cleanup-network-interfaces.sh`
1. (only on ARM) Build `ferrarimarco/pxe`
1. (only on ARM) Build `ferrarimarco/home-lab-dnsmasq`
1. (only on ARM) update host configuration file: `etc/dhcp-hosts/host-configuration.conf`
1. (only on ARM) build the DNSMasq image: `docker build -t ferrarimarco/home-lab-dnsmasq:<tag>`
1. Configure network interface with NetworkManager: `scripts/ubuntu/configure-network-manager.sh --domain lab.ferrarimarco.info --ip-v4-dns-nameserver 192.168.0.5 --ip-v4-gateway-ip-address 192.168.0.1 --ip-v4-host-cidr 16 --ip-v4-host-address 192.168.0.5 --network-type static_ip`
1. Disable other DHCP servers for the subnets managed by DNSMASQ, if any
1. Start DNSMASQ: `scripts/ubuntu/start-dnsmasq.sh`

### Docker Swarm Manager

1. Initialize the Swarm Manager: `docker swarm init` OR join the existing swarm as a manager

### DDClient Server

1. Copy credentials file to a local version: `cp swarm/configuration/ddclient/ddclient.conf swarm/configuration/ddclient/ddclient.conf.local`
1. Update the credentials in `swarm/configuration/ddclient/ddclient.conf.local`
1. Deploy ddclient stack: `docker stack deploy --compose-file swarm/ddclient.yml ddclient`

### OpenVPN Server

1. (only on ARMv7) Clone [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn.git): `git clone https://github.com/kylemanna/docker-openvpn.git`
1. (only on ARMv7) Build `kylemanna/docker-openvpn`: `docker build -t kylemanna/openvpn:latest .`
1. Initialize credentials:
  1. `export OVPN_DATA="ovpn-data-vpn-ferrarimarco-info"`
  1. `docker volume create --name $OVPN_DATA`
  1. `docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://vpn.ferrarimarco.info  -e "max-clients 5" -s 10.45.89.0/24 -n 192.168.0.5 -p "dhcp-option DOMAIN lab.ferrarimarco.info" -p "dhcp-option DOMAIN-SEARCH lab.ferrarimarco.info" -p "route 192.168.0.0 255.255.0.0" -e "explicit-exit-notify 1" -e "ifconfig-pool-persist ipp.txt"`
  1. `docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki`
1. Start OpenVPN: `docker run -d --hostname=openvpn --name=openvpn --cap-add=NET_ADMIN --restart=always -p 1194:1194/udp -v $OVPN_DATA:/etc/openvpn kylemanna/openvpn:latest`
