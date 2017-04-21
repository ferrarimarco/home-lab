# home-lab
All the necessary to provision, configure and manage my home lab.

## Components

### DHCP server (with PXE support), DNS server

### Ansible

#### Available Playbooks

1. `bootstrap-control-machine.yml`: bootstraps the Ansible control machine
1. Bootstrap node (common steps valid for every node)
  1. `bootstrap.yml`: node initialization. Use a default user (`ubuntu, pw:insecure` or `vagrant, pw: vagrant` for hosts in the development environment) to access freshly deployed nodes
  1. `bootstrap-remove-default-users.yml`: remove user account created during the provisioning of managed nodes
  1. `bootstrap-docker-engine-hosts.yml`: install Docker engine

## Development Environment
