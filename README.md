# ferrarimarco's Home Lab

All the necessary to provision, configure and manage my home lab.

[![Build Status](https://travis-ci.org/ferrarimarco/home-lab.svg?branch=master)](https://travis-ci.org/ferrarimarco/home-lab)

## Provisioning the environment

### Dependencies

- [Git](https://git-scm.com/) (tested with version `2.25.0`).
- [Terraform](https://www.terraform.io/) (tested with version `v0.12.20`).
- [Google Cloud SDK](https://cloud.google.com/sdk) (tested with version `271.0.0`).

### Set the environment variables

To provision the necessary infrastructure, you need to initialize and export
the following environment variables:

- `GOOGLE_CLOUD_PROJECT`: Google Cloud project ID that will contain the
  resources for the container image building pipeline.
- `GOOGLE_APPLICATION_CREDENTIALS`: path to the default Google Cloud credentials.
- `ORGANIZATION_ID`: Google Cloud organization ID at the root of the hierarchy.

### Provision the resources

1. Change your working directory to the root of this repo.
1. Generate the Terraform backend configuration: `scripts/linux/generate-tf-backend.sh`
1. Change your working directory: `cd provisioning/terraform/environments/prod`
1. Init the Terraform state: `terraform init`
1. Import the resources that the backend configuration script created:

    ```shell
    terraform import google_project.ferrarimarco_iac ferrarimarco-iac
    terraform import google_storage_bucket.terraform_state ferrarimarco-iac/ferrarim-iac-terraform-state
    ```

1. Inspect the changes that Terraform will apply: `terraform plan`
1. Apply the changes: `terraform apply`

#### Terraform variables

For each environment, you can provide an encrypted
[`tfvars` file](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables).

Example:

```terraform
google_billing_account_id             = "1234567-ABCD"
google_cloudbuild_key_rotation_period = "864000s"
google_default_region                 = "us-central1"
google_default_zone                   = "us-central1-a"
google_iac_project_id                 = "ferrarimarco-iac"
google_iot_project_id                 = "ferrarimarco-iot"
google_organization_domain            = "ferrari.how"
google_terraform_state_bucket_id      = "ferrarim-iac-terraform-state"
```

You can then encrypt it with the Google Cloud SDK
(using the keyring and key we created for Cloud Build):

```shell
gcloud kms encrypt \
  --plaintext-file=terraform.tfvars \
  --ciphertext-file=terraform.tfvars.enc \
  --location=global \
  --keyring=cloud-build-keyring \
  --key=cloudbuild-crypto-key
```

## Manual Steps

There are a number of manual steps to follow in order to bootstrap this Lab.
The first machine (likely the DHCP/DNS/PXE server) in this lab has to be
bootstrapped manually.

### OS Installation

#### Ubuntu Server - x86

1. Download Ubuntu from: `https://www.ubuntu.com/download/server`
1. Load Ubuntu Server on a USB flash drive
1. Install Ubuntu server

#### Debian ARM - BeagleBone Black

1. Download latest Debian image from:
[Latest official Debian images](http://beagleboard.org/latest-images)
or
[Weekly Debian builds for the BeagleBone Black](https://elinux.org/Beagleboard:BeagleBoneBlack_Debian#Debian_Releases)
and the relevant `sha256sum` files.
1. Prepare the image (checksum, extract from the archive):
`scripts/linux/prepare-beaglebone-black-os-image.sh path/to/img.xz`
1. Write the image on a SD card. If using `dd`:
`dd bs=1m if=/path/to/image.img of=/dev/XXXX`,
where `XXXX` is the SD card device identifier.
1. Ensure the board is powered off.
1. Insert the microSD.
1. Boot the board using the SD card.
Note that it may be necessary to press the Boot button
(near the microSD slot) until the user LEDs turn on (necessary for old uBoot
versions).
   If you downloaded a flasher version of the image, it will boot and then
   start flashing the eMMC. When flashing is completed, the board will power off.
   Remember to remove the microSD otherwise the board will keep flashing the
   microSD over and over.
1. Unplug the board and plug it back in.
1. Open a new SSH connection. User: `debian`, password: `temppwd`.
1. Run the setup script:
`sudo sh -c "$(curl -sSL https://raw.githubusercontent.com/ferrarimarco/home-lab/master/scripts/linux/setup-beaglebone-black.sh)"`.

##### Updating the kernel and bootloader

If you want to update the BeagleBone Black kernel and bootloader, use the
scripts in `/opt/scripts/`:

First, update the scripts to the latest version:

1. `cd /opt/scripts/`
1. `git pull`

Then, from the `/opt/scripts/` directory, run `tools/update_kernel.sh` to
update the kernel and `tools/developers/update_bootloader.sh` to update the
bootloader.

### OS configuration - Linux

1. Run the OS bootstrap script: `sudo sh -c "$(curl -sSL https://raw.githubusercontent.com/ferrarimarco/home-lab/master/scripts/linux/os-bootstrap.sh)"`
1. Logout the predefined user
1. Login again with the administrative user

### DNS/DHCP/PXE Server Configuration - Debian and derivatives

1. Disable other DHCP servers for the subnets managed by DNSMASQ, if any
1. Create and update host configuration file (see the one bundled with
`ferrarimarco/home-lab-dnsmasq` for an example):
`/etc/dnsmasq-home-lab/dhcp-hosts/host-configuration.conf`
1. Start DNSMASQ: `scripts/linux/docker/start-dnsmasq.sh`

### DDClient Server

1. Copy credentials file to a local version:
`cp swarm/configuration/ddclient/ddclient.conf swarm/configuration/ddclient/ddclient.conf.local`
1. Update the credentials in `swarm/configuration/ddclient/ddclient.conf.local`
1. Deploy ddclient stack:
`docker stack deploy --compose-file swarm/ddclient.yml ddclient`

### OpenVPN Server

1. (only on ARMv7) Clone
[kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn.git):
`git clone https://github.com/kylemanna/docker-openvpn.git`
1. (only on ARMv7) Build `kylemanna/docker-openvpn`:
`docker build -t kylemanna/openvpn:latest .`
1. Initialize credentials:
   1. `export OVPN_DATA="ovpn-data-vpn-ferrarimarco-info"`
   1. `docker volume create --name $OVPN_DATA`
   1. Generate OpenVPN config:

   ```shell
   docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig \
    -u udp://vpn.ferrarimarco.info  -e "max-clients 5" -s 10.45.89.0/24 \
    -n 192.168.0.5 -p "dhcp-option DOMAIN lab.ferrarimarco.info" \
    -p "dhcp-option DOMAIN-SEARCH lab.ferrarimarco.info" \
    -p "route 192.168.0.0 255.255.0.0" -e "explicit-exit-notify 1" \
    -e "ifconfig-pool-persist ipp.txt"
   ```

   1. Initialize the PKI:

   ```shell
   docker run -v $OVPN_DATA:/etc/openvpn --rm -it \
   kylemanna/openvpn ovpn_initpki
   ```

1. Start OpenVPN:

```shell
docker run -d --hostname=openvpn --name=openvpn --cap-add=NET_ADMIN \
  --restart=always -p 1194:1194/udp -v $OVPN_DATA:/etc/openvpn \
  kylemanna/openvpn:latest
```
