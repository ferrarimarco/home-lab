# ferrarimarco's Home Lab

All the necessary to provision, configure and manage my home lab.

## Provisioning the environment

To bootstrap the home lab, follow the instructions in this section.

### Dependencies

- [Git](https://git-scm.com/) (tested with version `2.25.0`).
- [Terraform](https://www.terraform.io/) (tested with version `v0.12.20`).
- [Google Cloud SDK](https://cloud.google.com/sdk) (tested with version `271.0.0`).

### Set the environment variables

To provision the necessary infrastructure, you need to initialize and export
the following environment variables:

- `GOOGLE_CLOUD_PROJECT`: Google Cloud project ID that will contain the
    resources for the provisioning pipeline.
- `GOOGLE_APPLICATION_CREDENTIALS`: path to the default Google Cloud credentials.
- `ORGANIZATION_ID`: Google Cloud organization ID at the root of the hierarchy.

Note: Initialize the default Google Cloud with `gcloud auth application-default login`

### Provision the cloud infrastructure

You now provision and configure the cloud infrastructure:

1. Change your working directory to the root of this repo.
1. Change your working directory: `cd provisioning/terraform/environments/prod`
1. Populate a
    [Terraform variables file](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables)
    named `terraform.tfvars` adapting the following content to your environment:

    ```terraform
    development_workstation_ssh_user                 = "ferrarimarco"
    google_billing_account_id                        = "1234567-ABCD"
    google_default_region                            = "us-central1"
    google_default_zone                              = "us-central1-a"
    google_iac_project_id                            = "ferrarimarco-iac"
    google_iot_project_id                            = "ferrarimarco-iac"
    google_organization_domain                       = "ferrari.how"
    ```

1. Generate the Terraform backend configuration: `../../generate-tf-backend.sh`
1. Init the Terraform state: `terraform init`
1. Import the resources that the backend configuration script created:

    ```shell
    terraform import google_project.ferrarimarco_iac "${GOOGLE_CLOUD_PROJECT}"
    terraform import google_storage_bucket.terraform_state "${GOOGLE_CLOUD_PROJECT}"/"${GOOGLE_CLOUD_PROJECT}"-terraform-state
    ```

1. Ensure the configuration is valid: `terraform validate`
1. Inspect the changes that Terraform will apply: `terraform plan`
1. Apply the changes: `terraform apply`

An automated, CI/CD pipeline will then be responsible to apply future changes to
the infrastructure and to run the rest of the build tasks. The pipeline applies
changes to the infrastructure only for commits pushed to the `master` branch.

During the first run from your local environment, Terraform uploads the
following configuration files from your file system to a Cloud Storage bucket
named `${GOOGLE_CLOUD_PROJECT}-configuration`:

- `terraform.tfvars` variables file
- `backend.tf` backend configuration file
- Public keys for IoT Core, Compute Engine, and other Google Cloud services if
    available in your environment.

The pipeline downloads these files for unattended executions.

#### Conditional provisioning

Some resources will not be provisioned by Terraform if certain conditions are
not met:

1. IoT Core devices must have at least one key file on the local file system.
1. The development workstation Compute Engine virtual machine needs at least one
    public key to set up SSH access.

All the configuration files that the provisioning pipeline needs are in the
`${GOOGLE_CLOUD_PROJECT}-configuration` Cloud Storage bucket.

### Provision edge devices

There are edge devices, such as sensors, microcontrollers and microcomputers to provision.

Edge devices auto-configure themselves during their first start.

#### BeagleBone Black

In this section, you provision BeagleBone Black microcomputers.

1. Download latest OS image and checksum from the Storage bucket.
1. Prepare the image (checksum, extract from the archive):
`scripts/check-image-and-flash.sh path/to/img.xz /dev/XXXX`
where `XXXX` is the SD card device identifier.
1. Ensure the board is powered off.
1. Insert the microSD.
1. Boot the board using the SD card. Note that it may be necessary to press the
    Boot button (near the microSD slot) until the user LEDs turn on (necessary
    for old uBoot versions). If you downloaded a flasher version of the image,
    it will boot and then start flashing the eMMC. When flashing is completed,
    the board will power off. Remember to remove the microSD otherwise the board
    will keep flashing the microSD over and over.
1. Unplug the board and plug it back in.
