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
    nix develop ./config/nix#operations
    ```

1. Apply changes with Terraform:

    ```bash
    scripts/run-terraform.sh
    ```

    To enable the configuration of the Proxmox IAM, create the following files:
    - `config/terraform/environments/proxmox-pve1-root-secrets.tfvars` to store
      the root credentials (password or API token) of the `pve1` host root
      password.
