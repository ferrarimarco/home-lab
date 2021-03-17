# ferrarimarco's Home Lab

All the necessary to provision, configure and manage my home lab.

The home lab has two main environments:

1. A cloud environment on Google Cloud.
1. An edge environment, on premises.

Before using the home lab, you initialize both environments by executing
two manual processes. After these two initalization processes complete,
automated processes take care of applying provisioning and
configuration changes to both environments.

## Dependencies

To interact with the home lab, you need the following tools:

- [Git](https://git-scm.com/) (tested with version `2.25.0`).
- [Terraform](https://www.terraform.io/) (tested with version `v0.12.20`).
- [Google Cloud SDK](https://cloud.google.com/sdk) (tested with version `271.0.0`).

## Initialize the cloud environment

To initialize the cloud environment, you manually execute the initialization
process:

1. Initialize the default Google Cloud: `gcloud auth application-default login`
1. Initialize and export the following environment variables:
    - `GOOGLE_CLOUD_PROJECT`: Google Cloud project ID that will contain the
    resources for the provisioning pipeline.
    - `GOOGLE_APPLICATION_CREDENTIALS`: path to the default Google Cloud credentials.
    - `ORGANIZATION_ID`: Google Cloud organization ID at the root of the hierarchy.
1. Change your working directory to the root of this repo.
1. Change your working directory: `cd provisioning/terraform/environments/prod`
1. Populate a
    [Terraform variables file](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables)
    named `terraform.tfvars` adapting the following content to your environment:

    ```terraform
    configuration_terraform_environment_name         = "prod"
    development_workstation_region                   = "europe-west6"
    development_workstation_ssh_user                 = "ferrarimarco"
    development_workstation_zone                     = "europe-west6-a"
    google_billing_account_id                        = "1234567-ABCD"
    google_default_region                            = "us-central1"
    google_default_zone                              = "us-central1-a"
    google_iac_project_id                            = "ferrarimarco-iac"
    google_iot_project_id                            = "ferrarimarco-iac"
    google_organization_domain                       = "ferrari.how"
    main_dns_zone_prefix                             = "lab"
    ```

1. Generate the Terraform backend configuration: `../../generate-tf-backend.sh`
1. Init the Terraform state: `terraform init`
1. Import the resources that the backend configuration script created:

    ```shell
    terraform import module.iac-pipeline.google_project.iac_project "${GOOGLE_CLOUD_PROJECT}"
    terraform import module.iac-pipeline.google_storage_bucket.terraform_state "${GOOGLE_CLOUD_PROJECT}"/"${GOOGLE_CLOUD_PROJECT}"-terraform-state
    ```

1. Ensure the configuration is valid: `terraform validate`
1. Apply the changes: `terraform apply`

### Managed DNS zone

This environment requires a DNS zone to manage, and expects it to be a subdomain
of your Google Cloud organization domain. You can customize the subdomain name
of the cloud environment by changing the value of the relevant variable in the
Terraform variables file.

To complete the setup, you must setup a `NS` DNS record in the
authoritative name server of your organization for the
subdomain to point to the managed DNS servers. For example, follow
[these instructions for Google Domains](https://cloud.google.com/dns/docs/tutorials/create-domain-tutorial#update-nameservers).

### Conditional provisioning

Some resources will not be provisioned by Terraform if certain conditions are
not met:

1. IoT Core devices must have at least one key file on the local file system.
1. The development workstation Compute Engine virtual machine needs at least one
    public key to set up SSH access.

All the configuration files that the provisioning pipeline needs are in the
`${GOOGLE_CLOUD_PROJECT}-configuration` Cloud Storage bucket.

### Deleting the development workstation

To turn off and delete the development workstation, run:

```shell
terraform destroy \
    -target module.development-workspace.google_compute_instance.development-workstation \
    -target module.development-workspace.google_compute_image.dev-workstation-image-ubuntu-2004
```

## Initialize the edge environment

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
    Internet.
1. An IP address to statically assign to the main network interface of the seed
    device.

As soon as the seed device detects that the edge environment initialization
process is completed, and there are enough nodes, servers, and service
instances to back the seed device up, the seed device loads and the
configuration that non-seed devices use, and applies that configuration to
itself. This approach has two benefits:

1. Avoid circular dependencies. The on premises environment needs minimal,
    pre-existing infrastructure to complete the initialization process.
1. Avoid special-purpose devices. By applying the general-purpose configuration to
    the seed device after the initialization process, you avoid introducing
    ad-hoc components in the environment.
