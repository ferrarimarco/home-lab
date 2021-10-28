# ferrarimarco's Home Lab

All the necessary to provision, configure and manage my home lab.

Before using the home lab, you initialize the environments by executing
a manual process. After the initalization process completes,
automated processes take care of applying provisioning and
configuration changes to the environments.

## Dependencies

To interact with the home lab, you need the following tools:

- [Git](https://git-scm.com/) (tested with version `2.25.0`).

### Managed DNS zone

This environment requires a DNS zone to manage.

To complete the setup, you must setup a `NS` DNS record in the
authoritative name server of your organization for the
subdomain to point to the managed DNS servers. For example, follow
[these instructions for Google Domains](https://cloud.google.com/dns/docs/tutorials/create-domain-tutorial#update-nameservers).

## Initialize the environment

To initialize the edge environment, you execute the first initialization process
using a seed device. Besides this initialization phase that may require a manual
intervention, devices in the edge envirnment auto-configure themselves when they
start.

### Initialize the edge environment with the seed device

To provision the edge environment, you use a seed device. After this process is
completed, the seed device has no special purpose or status, and you can use
that seed device as any other device in the edge environment.

The seed device has as few external dependencies as possible. The seed
device requires:

1. A connection to an IP network that can route packets to and from the
    internet.
1. An IP address to statically assign to the main network interface of the seed
    device.

As soon as the seed device detects that the edge environment initialization
process is completed, and there are enough nodes, servers, and service
instances to back the seed device up, the seed device loads and the
configuration that non-seed devices use, and applies that configuration to
itself. This approach has two benefits:

1. Avoid circular dependencies. The on premises environment needs minimal,
    pre-existing infrastructure to complete the initialization process.
1. Avoid special-purpose devices. By applying the general-purpose configuration
    to the seed device after the initialization process, you avoid introducing
    ad-hoc components in the environment.

#### Initialize the seed device operating system

To initialize the seed device, you need to install and configure the operating
system (OS). In the current iteration of the home lab, the seed device can be
any computing device that is capable of installing the operating system from an
ISO image. The operating system must have cloud-init pre-installed.

1. Download the OS installer ISO.
1. Write the OS installer ISO on a USB flash drive.
1. Download the cloud-init datasource ISO.
1. Write the cloud-init datasource ISO on a (different) USB flash drive.
1. Plug in both USB flash drives in the seed device.
1. Boot the seed device from the OS installer ISO.

##### Write an ISO image on a flash drive

To write an ISO image on a flash drive, do the following:

On Linux:

```shell
sudo dd bs=4M if=[PATH_TO_OS_INSTALLER_ISO] of=[USB_FLASH_DRIVE] conv=fdatasync status=progress
```

On MacOS:

```shell
diskutil unmountDisk [USB_FLASH_DRIVE]
sudo dd bs=4m if=[PATH_TO_OS_INSTALLER_ISO] of=[USB_FLASH_DRIVE]; sync
sudo diskutil eject [USB_FLASH_DRIVE]
```

### Update and configure the Raspberry Pi 4 bootloader

To update the bootloader on the [Raspberry Pi 4 EEPROM](https://www.raspberrypi.org/documentation/hardware/raspberrypi/booteeprom.md)
and configure the [boot order](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bcm2711_bootloader_config.md):

1. Download the latest release of [rpi-eeprom](https://github.com/raspberrypi/rpi-eeprom/releases).
    There are different boot order configurations available, as configured
    [here](https://github.com/raspberrypi/rpi-eeprom/tree/master/imager).
1. Extract the contents of the downloaded archive to a FAT32 formatted SD card.
1. Insert the SD card in a powered off Raspberry Pi 4.
1. Wait for the activity LED to steadily flash green.
1. Power the Raspberry Pi off.

For more information about flashing Raspberry Pi OS images to a SD card, refer to
[Raspberry Pi: Getting started](https://www.raspberrypi.org/documentation/computers/getting-started.html).

## Development environment

In this section, you set up a development environment for the home lab.

### Remote embedded development

To use a remote workstation as a development environment for embedded devices,
you:

1. Expose the needed serial ports via an RFC 2217 server.
1. Forward the RFC 2217 ports over SSH.
1. Connect to the forwarded ports from the development workstation.

An example of this approach to develop with an ESP32 and the
[esp-idf framework](https://github.com/espressif/esp-idf) is
[here](provisioning/esp32/smart_desk/Makefile).
