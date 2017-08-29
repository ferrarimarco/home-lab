# home-lab
All the necessary to provision, configure and manage my home lab.

## Components

### DHCP server (with PXE support), DNS server

A dockerized Dnsmasq instance:  [ferrarimarco/home-lab-dnsmasq](https://github.com/ferrarimarco/home-lab-dnsmasq).

### Ansible

A dockerized Ansible instance based on [ferrarimarco/open-development-environment-ansible](https://github.com/ferrarimarco/open-development-environment-ansible).

#### Inventory

The inventory is saved in the default path: `/etc/ansible/hosts`

#### Available Playbooks

1. `bootstrap-control-machine.yml`: bootstraps the Ansible control machine
1. `bootstrap-managed-nodes.yml`: node initialization. Use a default user (`ubuntu, pw:insecure` or `vagrant, pw: vagrant` for hosts in the development environment) to access freshly deployed nodes
1. `bootstrap-docker-engine-hosts.yml`: install Docker engine

## Development Environment

The development environment is currently managed with Vagrant. Run `vagrant up` from the root directory of this repository to start the environment.

### Dependencies

- Vagrant 1.9.3+
- Virtualbox 5.1.16+
