# Provision new hosts

This document is about the steps that are necessary to prepare new hosts
for the home lab. We define this process as `provisioning new hosts`.

The provisioning process is as follows:

- Gather information about the host:
    - Unique name to assign to the host.
    - MAC address of each network interface.
    - Name of each network interface.
    - Static IP address to assign to each network interface.
    - Boot disk name.
- Update the BIOS and UEFI firmware to the latest available version.
- Enable network boot.
- Enable [Wake-on-LAN](https://en.wikipedia.org/wiki/Wake-on-LAN).
- Enable hardware-assisted virtualization capabilities.
- Add the machine to the inventory.

For hosts that support it, we automate the setup using an
out-of-band configuration mechanisms, such as
[Intelligent Platform Management Interface (IPMI)](https://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface),
or [Redfish](https://en.wikipedia.org/wiki/Redfish_(specification)).
Off-the-shelf, consumer hardware rarely support these configuration mechanisms,
so you may need to manually complete some configuration steps to prepare a host
to join the home lab.

In this document, we provide information about the manual steps to provision the
following types of hosts:

- Raspberry Pi 4

## Raspberry Pi 4

This section is about the manual configuration steps for Raspberry Pi 4 hosts.

### Update and configure the Raspberry Pi 4 bootloader

To update the bootloader on the [Raspberry Pi 4 EEPROM](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#raspberry-pi-4-boot-eeprom)
and configure the [boot order](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#BOOT_ORDER)
when not using Raspberry Pi OS, do the following:

1. Download the latest release of [rpi-eeprom](https://github.com/raspberrypi/rpi-eeprom/releases).
    There are different boot order configurations available, as configured
    [here](https://github.com/raspberrypi/rpi-eeprom/tree/master/imager).
1. Flash the bootloader disk image on a removable flash drive. For more information about flashing Raspberry Pi OS
    images to a SD card, refer to [Raspberry Pi: Getting started](https://www.raspberrypi.org/documentation/computers/getting-started.html).
1. Insert the SD card in a powered off Raspberry Pi 4.
1. Wait for the activity LED to steadily flash green.
1. Power the Raspberry Pi off.

### Configure Raspberry Pi hosts

To update the configuration of a Raspberry Pis running Raspberry Pi OS, refer to
[Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/computers/configuration.html).

For example, you may need to change the hostname of a newly provisioned node
before adding it to the set of automatically configured nodes.

### Configure hosts with Ansible

For newly provisioned Raspberry Pis, you might have to authenticate a SSH
connection using a password instead of a key. To authenticate with a password,
add the `--ask-pass --connection paramiko` options to the Ansible command you're
running.

By using [Paramiko](https://www.paramiko.org/) to connect to a host using SSH,
you can authenticate using a password without having the `sshpass` program
installed on the host that runs Ansible.
