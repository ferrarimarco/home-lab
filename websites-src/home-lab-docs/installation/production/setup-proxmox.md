# Configure Proxmox hosts, virtual machines, and containers

Terraform handles:

- The configuration of Proxmox hosts.
- The provisioning of Proxmox virtual machines (VMs) and LXC containers.

## Terraform stages

To configure Proxmox hosts, you use the following Terraform stages:

- `000-initialize`: initial Terraform environment setup
- `200-proxmox`: Proxmox bootstrap, including user identities and API tokens

## Initialize Proxmox hosts (`200-terraform` stage)

After provisioning a Proxmox host, you initialize it with Terraform. The
initialization process creates users, roles, and API tokens for the following
stages, and persists API tokens in Terraform variables files.

You run this stage when you need to:

- Initialize a Proxmox host for the first time
- Create new Proxmox users
- Grant new permissions to existing Proxmox users

From your Linux shell, after setting the working directory to the root of this
repository:

1. Open the `operations` Nix shell, if needed:

    ```bash
    nix develop config/nix#operations
    ```

1. Set the Proxmox host name:

    ```bash
    PROXMOX_HOST_NAME="<HOST_NAME>"
    ```

    Where:
    - `<HOST_NAME>` is the Proxmox Virtual Environment host name. Valid values
      are:
        - `pve1`

1. Apply changes with Terraform:

    ```bash
    read -sp "Enter Password: " TF_VAR_proxmox_virtual_environment_password \
      && echo "" \
      && terraform \
        -chdir=config/terraform/200-proxmox \
        apply \
        -var-file="../environments/proxmox-$PROXMOX_HOST_NAME.tfvars" \
      && unset TF_VAR_proxmox_virtual_environment_password
    ```

    For security reasons, you need to type the root user password at run time.

## Run Terraform

From your Linux shell, after setting the working directory to the root of this
repository:

1. Open the `operations` Nix shell, if needed:

    ```bash
    nix develop config/nix#operations
    ```

1. Set the Proxmox host name:

    ```bash
    PROXMOX_HOST_NAME="<HOST_NAME>"
    ```

    Where:
    - `<HOST_NAME>` is the Proxmox Virtual Environment host name. Valid values
      are:
        - `pve1`

1. Apply changes with Terraform:

    ```bash
    terraform \
      -chdir=config/terraform/201-proxmox-workloads \
      apply \
      -var-file="../environments/proxmox-$PROXMOX_HOST_NAME.tfvars" \
      -var-file="../environments/proxmox-$PROXMOX_HOST_NAME-secrets.tfvars"
    ```
