# ferrarimarco's Home Lab

All the necessary to provision, configure and manage my home lab.

Before using the home lab, you initialize the environments by executing
a manual process. After the initalization process completes,
automated processes take care of applying provisioning and
configuration changes to the environments.

## Dependencies

To interact with the home lab, you need the following tools:

- [Git](https://git-scm.com/) (tested with version `2.25.0`).

## Initialize the environment

To initialize the edge environment, you execute the first initialization process
using a seed device. Besides this initialization phase that may require a manual
intervention, devices in the edge envirnment auto-configure themselves when they
start.

### Initialize the edge environment with the seed device

To provision the edge environment, you use a seed device.

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

After the edge environment initialization process is completed, the seed device
has no special purpose or status, and you can use that seed device as any other
device in the edge environment.

The seed device has as few external dependencies as possible. The seed
device requires:

1. A connection to an IP network that can route packets to the
    internet.
1. An IP address to statically assign to the main network interface of the seed
    device.

#### Initialize the seed device

To initialize the seed device, you:

- Download the operating system (OS) installer disk image.
- Prepare the OS installer configuration disk image.
- Flash both disk images on two distinct removable flash disks.
- Boot the seed device from the OS installer disk.

To initialize the seed device, do the following:

1. Download the OS installer disk image.
1. Flash the OS installer disk image on a dedicated, removable flash drive:

    On Linux:

    ```sh
    sudo dd bs=4M if=[PATH_TO_ISO] of=[USB_FLASH_DRIVE] conv=fdatasync status=progress
    ```

    On MacOS:

    ```sh
    diskutil unmountDisk [USB_FLASH_DRIVE]
    sudo dd bs=4m if=[PATH_TO_ISO] of=[USB_FLASH_DRIVE]; sync
    sudo diskutil eject [USB_FLASH_DRIVE]
    ```

1. Download the OS installer configuration disk image.
1. Flash the OS installer configuration disk image on a dedicated, removable flash drive adapting the commands described
    in the previous steps.

#### Update and configure the Raspberry Pi 4 bootloader

To update the bootloader on the [Raspberry Pi 4 EEPROM](https://www.raspberrypi.org/documentation/hardware/raspberrypi/booteeprom.md)
and configure the [boot order](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bcm2711_bootloader_config.md)
when not using Raspberry Pi OS, do the following:

1. Download the latest release of [rpi-eeprom](https://github.com/raspberrypi/rpi-eeprom/releases).
    There are different boot order configurations available, as configured
    [here](https://github.com/raspberrypi/rpi-eeprom/tree/master/imager).
1. Extract the contents of the downloaded archive to a FAT32 formatted SD card.
1. Insert the SD card in a powered off Raspberry Pi 4.
1. Wait for the activity LED to steadily flash green.
1. Power the Raspberry Pi off.

For more information about flashing Raspberry Pi OS images to a SD card, refer to
[Raspberry Pi: Getting started](https://www.raspberrypi.org/documentation/computers/getting-started.html).

### Managed DNS zone

This environment requires a DNS zone to manage.

To complete the setup, you setup a `NS` DNS record in the
authoritative name server of your organization for the
subdomain to point to the managed DNS servers.

For example, follow
[these instructions for Google Domains](https://cloud.google.com/dns/docs/tutorials/create-domain-tutorial#update-nameservers).

## Development environment

In this section, you set up a development environment for the home lab.

### Generate the templated files

To avoid duplications, a template generator produces files from templates.
To generate templated files, do the following:

```sh
scripts/generate-templated-files.sh
```

After the generator produces the files, commit any updates to the generated files.

### Test cloud-init configurations

I use [cloud-init](https://cloudinit.readthedocs.io/) to perform some early provisioning
and configuration tasks. It has a hard dependency on systemd, which may have issues
running in containers. `scripts/test-cloud-init-configuration.sh` offers some support
to run a containerized cloud-init instance, but it's currently too rough to
integrate it in the CI/CD pipeline.
