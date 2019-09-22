# ferrarimarco's Home Lab

All the necessary to provision, configure and manage my home lab.

[![Build Status](https://travis-ci.org/ferrarimarco/home-lab.svg?branch=master)](https://travis-ci.org/ferrarimarco/home-lab)

## Manual Steps

There are a number of manual steps to follow in order to bootstrap this Lab.
The first machine (likely the DHCP/DNS/PXE server) in this lab has to be bootstrapped manually.

### OS Installation

#### Ubuntu Server - x86

1. Download Ubuntu from: `https://www.ubuntu.com/download/server`
1. Load Ubuntu Server on a USB flash drive
1. Install Ubuntu server

#### Debian ARM - BeagleBone Black

1. Download latest Debian image from : `http://beagleboard.org/latest-images`
1. Write the image on a SD card
1. Ensure the board is powered off
1. Insert the microSD
1. Boot the board using the SD card. Note that it may be necessary to press the Boot button (near the microSD slot) until the user LEDs turn on (necessary for old uBoot versions)
1. Open a new SSH connection. User: `debian`, password: `temppwd`
1. Run the setup script: `sudo sh -c "$(curl -sSL https://raw.githubusercontent.com/ferrarimarco/home-lab/master/scripts/linux/setup-beaglebone-black.sh)"`. If you enabled eMMC flashing, this will also reboot the board to flash the internal eMMC (takes up to 45 mins). While flashing the image, the leds will blink in sequence. The leds will turn off when flashing is complete.
1. Remove the microSD, otherwise it'll just keep on re-flashing the eMMC.
1. Unplug the board and plug it back in.

### OS configuration - Linux

1. Run the OS bootstrap script: `sudo sh -c "$(curl -sSL https://raw.githubusercontent.com/ferrarimarco/home-lab/master/scripts/linux/os-bootstrap.sh)"`
1. Logout the predefined user
1. Login again with the administrative user
1. Remove the predefined user: `userdel -r -f debian`

### DNS/DHCP/PXE Server Configuration - Debian and derivatives

1. Disable other DHCP servers for the subnets managed by DNSMASQ, if any
1. Create and update host configuration file (see the one bundled with `ferrarimarco/home-lab-dnsmasq` for an example): `/etc/dnsmasq-home-lab/dhcp-hosts/host-configuration.conf`
1. Start DNSMASQ: `scripts/linux/docker/start-dnsmasq.sh`

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
