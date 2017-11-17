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

- Vagrant 1.9.3+
- Virtualbox 5.1.16+
