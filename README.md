# ferrarimarco's Home Lab

All the necessary to provision, configure and manage my home lab.

Before using the home lab, you initialize the environments by executing
a manual process. After the initalization process completes,
automated processes take care of applying provisioning and
configuration changes to the environments.

## Dependencies

To interact with the home lab, you need the following tools:

- [Git](https://git-scm.com/) (tested with version `2.25.0`).
- An OCI container runtime, such as Docker. Tested with Docker 20.10.
- During the bootstrap phase, the Home Lab also supports hosts where there's no container engine.

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

The current version of the home lab uses a Raspberry Pi 4 as a seed device. To
initialize the seed device:

1. Update and configure the bootloader.
1. Prepare the seed device boot disk and
1. Boot the seed device.

#### Update and configure the Raspberry Pi 4 bootloader

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

#### Prepare the seed device boot disk

To initialize the seed device, do the following:

1. Download the OS installer disk image.
1. Flash the OS installer disk image on a removable flash drive:

    On Linux:

    ```sh
    sudo dd bs=4M if=[PATH_TO_ISO] of=[USB_FLASH_DRIVE] conv=fdatasync status=progress
    ```

    On MacOS:

    ```sh
    diskutil unmountDisk [USB_FLASH_DRIVE]
    sudo dd bs=4m if=[PATH_TO_IMAGE] of=[USB_FLASH_DRIVE]; sync
    sudo diskutil eject [USB_FLASH_DRIVE]
    ```

1. Download the OS installer configuration disk image.
1. Flash the OS installer configuration disk image on a dedicated, removable flash drive adapting the commands described
    in the previous steps. For more information about flashing Raspberry Pi OS images to a SD card, refer to
    [Raspberry Pi: Getting started](https://www.raspberrypi.org/documentation/computers/getting-started.html).

#### Boot the seed device

After preparing the seed device boot disk, insert it into the seed device and boot the seed device
for the first time. The seed device will autoconfigure itself.

### Provision new hosts

When provisioning a new host, do the following:

1. Set a unique hostname for the new host.
1. Add the new host to the Ansible inventory.

#### Configure Raspberry Pi nodes

To update the configuration of a Raspberry Pis running Raspberry Pi OS, refer to
[Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/computers/configuration.html).

For example, you may need to change the hostname of a newly provisioned node
before adding it to the set of automatically configured nodes.

### Configure hosts with Ansible

For newly provisioned hosts, you might have to authenticate a SSH connection using
a passowrd instead of a key. To authenticate with a password, add the
`--ask-pass --connection paramiko` switches to the Ansible command you're running.

Note: Using [Paramiko](https://www.paramiko.org/) lets you use password authentication
without having the `sshpass` program installed on the host that runs Ansible.

To run Ansible, use the `scripts/run-ansible.sh` script. This script provides a
thin wrapper that takes care of setting up either a container (preferred) or a
Python virtual environment to run Ansible.

#### Ansible execution examples

These examples assume that the current working directory is the root of this repository.

To run `ansible-playbook` against the hosts listed in an inventory:

```shell
scripts/run-ansible.sh "ansible-playbook --inventory docker/ansible/etc/ansible/inventory/hosts.yml docker/ansible/etc/ansible/playbooks/main.yaml"
```

To run `ansible-playbook` against the hosts listed in an inventory, with a vault to decrypt (prompt for password):

```shell
scripts/run-ansible.sh "ansible-playbook --inventory docker/ansible/etc/ansible/inventory/hosts.yml --vault-id home_lab_vault@prompt docker/ansible/etc/ansible/playbooks/main.yaml"
```

To run `ansible-playbook` against the hosts listed in an inventory, with a vault to decrypt (read the password from a file):

```shell
scripts/run-ansible.sh "ansible-playbook --inventory docker/ansible/etc/ansible/inventory/hosts.yml --vault-id home_lab_vault@secrets/ansible/home_lab_vault_password docker/ansible/etc/ansible/playbooks/main.yaml"
```

To gather all the facts about a single host:

```shell
scripts/run-ansible.sh "ansible -m ansible.builtin.setup --user pi -i 'hostname.tld,' all"
```

To gather all the facts about all hosts, reusing the inventory:

```shell
scripts/run-ansible.sh "ansible -m ansible.builtin.setup -i docker/ansible/etc/ansible/inventory/hosts.yml all"
```

To list all the available Ansible tags in a play:

```shell
scripts/run-ansible.sh "ansible-playbook --inventory docker/ansible/etc/ansible/inventory/hosts.yml docker/ansible/etc/ansible/playbooks/main.yaml --list-tags"
```

#### Copy Jinja templates as they are

If you need to copy Jinja templates with the Ansible Template Module, you can
configure Ansible to change the variable start and end prefixes inside the template
by adding a special header.

For example:

```yaml
#jinja2:variable_start_string:'[%', variable_end_string:'%]'
```

Changes the default variable start and end prefixes from `{{` and `}}` to `[%` and `%]`.

### Add hosts to the Tailscale network

The automated provisioning and configuration process takes care of setting up
the Tailscale CLI.

To add a device to the Tailscale network, do the following:

1. From a shell on the host to add to the Tailscale network, run:

    ```shell
    sudo tailscale up
    ```

    and follow the instructions to authenticate
2. (optional) Disable [Tailscale key expiration](https://tailscale.com/kb/1028/key-expiry/)

### DNS configuration

In this section, we describe the configuration of DNS servers, zones, and resource records.

#### DNS servers and zones

This environment contains two private DNS servers:

- A CoreDNS instance (`ns1.lab.ferrari.how`) that acts as the authoritative name server for the main DNS zone: `lab.ferrari.how`.
- A dnsmasq instance running on the default gateway and responds to DNS queries for the `edge.lab.ferrari.how` zone and returns
    authoritative answers from DHCP leases ([source](https://lists.thekelleys.org.uk/pipermail/dnsmasq-discuss/2008q4/002670.html)),
    even if it doesn't run as an authoritative name server for the `edge.lab.ferrari.how` zone.
    This dnsmasq instance also handles DHCP for the main subnet.

### Configure network shares

To allow access to Samba network shares, do the following:

1. Create a Linux system user.
1. Add the user to the Samba database:

    ```shell
    sudo smbpasswd -a "${USER}"
    ```

## Monitoring

To monitor the status of the home lab, the automated provisioning and configuration
process deploy a monitoring agent on each home lab node, and a backend to collect
data coming from the monitoring agents.

### Import Grafana dashsboards

In its current state, Grafana doesn't support automatic import of dashboards that
a datasource ships, so you need to import those dashboards manually. To import
Grafana dashboards that ship with a datasource, do the following:

1. Open Grafana.
2. Open the datasource settings
3. Select a datasource.
4. Open the `Dashboards` panel.
5. Import the dashboards.

## Development environment

In this section, you set up a development environment for the home lab.

### Generate the templated files

To avoid duplications, a template generator produces files from templates.
To generate templated files, do the following:

```sh
scripts/generate-templated-files.sh
```

After the generator produces the files, commit any updates to the generated files.

## Container migration playbook

If you need to migrate containers and data between hosts, do the following:

1. Set the `configure_xxxxx` variable for the target host to `true` to prepare the target host.
2. Set the `configure_xxxxx_dns_records` variable for the target host to `false` because we don't (likely)
    want to update the DNS zone yet.
3. Set the `start_xxxxx` variable for the target host to `false` because we don't want to start any services
    before copying data.
4. Run Ansible. With the above configuration, it will prepare the target host without starting any service.
5. Set the `start_xxxxx` variable for the source host to `false` to stop the service we're migrating.
6. Run Ansible.
7. Copy data from the source host to the target host. You can use `scripts/migrate-data.sh` script to transfer data from
    one host to another.
8. Remove the `configure_xxxxx_dns_records` from the target host configuration because it defaults to the `configure_xxxxx` value, which is set to `true`.
9. Remove the `start_xxxxx` from the target host configuration because it defaults to the `configure_xxxxx` value, which is set to `true`.
10. Set the `configure_xxxxx_dns_records` from the source host configuration to `false`.
11. Run Ansible.
12. Remove the `start_xxxxx` variable from the source host configuration.
13. Remove the `configure_xxxxx_dns_records` variable from the source host configuration.
14. Remove the `configure_xxxxx` variable from the source host configuration.
15. Run Ansible.
16. Commit the changes in the repository.

### Data migration examples

These examples assume that the current working directory is the root of this repository.

To migrate one directory from one host to another:

```sh
scripts/migrate-container-data.sh "user@source.host" "/source/directory" "user2@target.host" "/destination"
```
