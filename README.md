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
1. Install cURL: `apt install curl`
1. Deploy public SSH keys: `mkdir -p $HOME/.ssh ; chmod 700 $HOME/.ssh ; curl -l http://github.com/ferrarimarco.keys > $HOME/.ssh/authorized_keys ; chmod 600 $HOME/.ssh/authorized_keys`
1. Install OpenSSH Server and start the related service: `apt install openssh-server ; service ssh restart`
1. Install git: `apt install git`
1. Clone this repository in `/opt`: `cd /opt ; git clone https://github.com/ferrarimarco/home-lab.git`
1. Grant executable permission to scripts: `find scripts/linux -type f -iname "*.sh" -exec chmod a+x {} \;`
1. Install NetworkManager: `scripts/linux/debian/install-network-manager.sh`
1. Install Docker: `scripts/linux/install-docker.sh --user username`
1. Remove network interfaces (except for `lo`) from `/etc/network/interfaces`: `scripts/linux/cleanup-network-interfaces.sh`
1. Configure network interface with NetworkManager: `scripts/linux/configure-network-manager.sh --domain lab.ferrarimarco.info --ip-v4-dns-nameserver 192.168.0.5 --ip-v4-gateway-ip-address 192.168.0.1 --ip-v4-host-cidr 16 --ip-v4-host-address 192.168.0.5 --network-type static_ip`
1. Copy the credentials file to `/etc/ddclient/ddclient.conf`
1. Update the credentials in `scripts/linux/docker/ddclient/config/ddclient.conf`
1. Start ddclient: `scripts/linux/docker/ddclient/start-ddclient.sh`
1. Disable other DHCP servers for the subnets managed by DNSMASQ, if any
1. Start DNSMASQ mounting a static host names file considering the real MAC addresses in the DNSMasq container: `scripts/linux/start-dnsmasq.sh`
